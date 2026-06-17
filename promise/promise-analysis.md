# APromise 手写 Promise 详细解析

> 源码位置:`promise.js`
> 参考规范:[Promises/A+ Specification](https://promisesaplus.com/)

本文档对 `promise.js` 中的 `APromise` 类实现进行逐段拆解,适合作为**手写 Promise** 的学习参考和**面试讲解**资料。

> ✅ **更新说明**:源码中原有的 3 处缺陷(`PEDDING` 拼写、`REJECTED(error)` 误用、回调触发位置)**已修复**。本文档中的"Bug 与改进点清单"保留作为历史记录,代码示例均已更新为修复后版本。

---

## 目录

- [一、三个状态常量](#一三个状态常量)
- [二、`resolvePromise` 函数 —— A+ 规范的「解析过程」](#二resolvepromise-函数--a-规范的解析过程)
- [三、构造函数](#三构造函数)
- [四、`then` 方法 —— 链式调用的关键](#四then-方法--链式调用的关键)
- [五、`catch` 方法](#五catch-方法)
- [六、`defer` / `deferred`](#六defer--deferred)
- [七、Bug 与改进点清单](#七bug-与改进点清单)
- [八、运行流程串讲](#八运行流程串讲)
- [九、总结](#九总结)
- [十、嵌套 Promise 链式调用完整执行流程](#十嵌套-promise-链式调用完整执行流程)

---

## 一、三个状态常量

```js
const PENDING   = 'pending'
const FULFILLED = 'fulfilled'
const REJECTED  = 'rejected'
```

Promise 一旦从 `pending` 流转到 `fulfilled` 或 `rejected` 就**不可逆**,这是状态机的核心特征。

---

## 二、`resolvePromise` 函数 —— A+ 规范的「解析过程」

这是整个实现最难、最容易出错的部分,对应 A+ 规范的 **2.3 The Promise Resolution Procedure**。
它的作用是:**判断 `then` 的回调返回值 `x`,决定下一个 promise 该走什么路径**。

### 2.1 循环引用检测

```js
if (promise === x) {
  return reject(new TypeError('检测到promise的循环调用'))
}
```

对应原生 Promise 的 `Chaining cycle detected for promise #<Promise>`。例如:

```js
const p = new APromise(r => r(1)).then(() => p) // ← 自己返回自己,死循环
```

### 2.2 `called` 标志位

```js
let called = false
```

防止 thenable 对象既调用 `resolve` 又调用 `reject`(或多次调用),保证**最多触发一次**。
这是针对**恶意 thenable** 的防御措施。

### 2.3 x 是对象 / 函数 → 当作 thenable 处理

```js
const then = x.then              // 取一次 then,防止 getter 副作用
if (typeof then === 'function') {
  then.call(x, y => resolvePromise(...), r => reject(r))
} else {
  resolve(x)                      // 普通对象,直接 resolve
}
```

- **递归调用 `resolvePromise(promise, y, ...)`**:`y` 可能又是一个 thenable,需要继续展开,直到拿到普通值。
- `try/catch`:防止 `x.then` 是个抛异常的 getter。

### 2.4 x 是普通值

直接 `resolve(x)`。

---

## 三、构造函数

```js
constructor(executor) {
  this.status = PENDING
  this.value = undefined           // fulfilled 时的数据
  this.reason = undefined          // rejected 时的原因
  this.onFulfilledCallbacks = []   // pending 时缓存的成功回调
  this.onRejectCallbacks = []      // pending 时缓存的失败回调
  ...
}
```

### 3.1 `resolve` 与 `reject`

```js
const resolve = (data) => {
  if (this.status == PENDING) {
    this.status = FULFILLED
    this.value = data
    this.onFulfilledCallbacks.forEach(fn => fn())   // ✅ 状态切换的同一原子动作内触发回调
    this.onFulfilledCallbacks = []                  // 触发后清空队列,避免重复执行
  }
}
```

**状态锁**:只有 `PENDING` 时才能改状态,保证不可逆。
**触发位置**:回调执行被收纳到 `if (PENDING)` 内,确保「状态变更 + 回调触发」是一次性原子动作,且队列触发后立刻清空。

### 3.2 执行 executor

```js
try {
  executor(resolve, reject)
} catch (error) {
  reject(error)                    // ✅ 同步抛错时直接 reject 当前 promise
}
```

如果 executor 同步抛错,当前 promise 直接进入 `rejected` 状态,异常会沿 then 链冒泡到最近的 `onRejected` / `catch`。

---

## 四、`then` 方法 —— 链式调用的关键

```js
then(onFulfilled, onRejected) {
  onFulfilled = typeof onFulfilled == 'function' ? onFulfilled : v => v
  onRejected  = typeof onRejected  == 'function' ? onRejected  : e => { throw e }
  let apromise = new APromise((resolve, reject) => { ... })
  return apromise
}
```

### 4.1 值穿透

当 `then(null, null)` 或 `then()` 时,**把上一个 promise 的值/原因透传到下一个 then**:

```js
Promise.resolve(1).then().then().then(v => console.log(v))   // → 1
Promise.reject(e).then().catch(e => ...)                      // ← err 透传到 catch
```

### 4.2 返回新 promise 才能链式调用

每次 `then` 都返回**新的 APromise 实例**,这就是 `.then().then().then()` 能不断接龙的原因。

### 4.3 三种状态分支处理

| 当前状态     | 处理方式 |
|--------------|----------|
| `FULFILLED`  | 立即(下个事件循环)执行 `onFulfilled` |
| `REJECTED`   | 立即(下个事件循环)执行 `onRejected` |
| `PENDING`    | **把回调推入队列**,等待 resolve/reject 触发 |

### 4.4 `setTimeout(..., 0)` 的作用

A+ 规范要求 `onFulfilled` / `onRejected` **必须异步执行**(原生 Promise 用微任务,这里用宏任务模拟)。
如果不异步,会出现以下问题:

```js
new APromise(r => r(1)).then(v => console.log(v))
console.log(2)
// 异步:输出 2 → 1 ✅
// 同步:输出 1 → 2 ❌
```

### 4.5 try / catch 兜底

`onFulfilled(this.value)` 内部抛错时,**不应让新 promise 卡在 pending**,而是变成 rejected 状态传给下一个 then。

### 4.6 用 `resolvePromise` 处理返回值

```js
const x = onFulfilled(this.value)
resolvePromise(apromise, x, resolve, reject)
```

这就是为什么 `.then(() => new Promise(...))` 能**等里面那个 Promise 完成再走下一个 then**。

---

## 五、`catch` 方法

```js
APromise.prototype.catch = function (errCallback) {
  return this.then(null, errCallback)
}
```

本质就是 `.then(null, onRejected)` 的语法糖。
结合 **4.1 的值穿透**,这正是 `then` 链中只挂一个末尾 catch 就能捕获中间任何一步异常的原因。

---

## 六、`defer` / `deferred`

```js
APromise.defer = APromise.deferred = function () {
  let dfd = {}
  dfd.promise = new APromise((resolve, reject) => {
    dfd.resolve = resolve
    dfd.reject = reject
  })
  return dfd
}
```

**专门给 promises-aplus-tests 测试库用的入口**,可以这样跑 A+ 规范测试:

```bash
npx promises-aplus-tests promise.js
```

---

## 七、Bug 与改进点清单

> 表中标记 ✅ 已修复 的条目代表当前 `promise.js` 已应用修复;未标记的条目为待优化项。

| # | 位置        | 问题                                          | 建议 / 状态                            |
|---|-------------|-----------------------------------------------|----------------------------------------|
| 1 | line 73     | `REJECTED(error)` 把字符串当函数调            | ✅ 已修复:改为 `reject(error)`        |
| 2 | line 1      | `PEDDING` 拼写错误                            | ✅ 已修复:全文替换为 `PENDING`        |
| 3 | line 60、68 | `callbacks.map(...)` 写在 `if` 外,且未清空   | ✅ 已修复:放进 `if (PENDING)` 内,触发后清空数组 |
| 4 | 全局        | `setTimeout` 模拟微任务,有顺序差异           | 🔄 待优化:可用 `queueMicrotask` 更贴近原生 |
| 5 | -           | 缺少 `Promise.resolve / reject / all / race / allSettled / any / finally` | 🔄 待补充:按需扩展静态方法            |
| 6 | -           | `executor` 不是函数时未校验                   | 🔄 待补充:原生会抛 `TypeError`        |

### 已修复代码(当前 `promise.js` 即为此版本)

```js
// 修复 1:同步抛错走 reject
try {
  executor(resolve, reject)
} catch (error) {
  reject(error)
}

// 修复 2 + 3:常量更名 & 回调触发位置
const PENDING = 'pending'

const resolve = (data) => {
  if (this.status === PENDING) {
    this.status = FULFILLED
    this.value = data
    this.onFulfilledCallbacks.forEach(fn => fn())
    this.onFulfilledCallbacks = []
  }
}
```

### 待优化参考代码

```js
// 优化 4:用 queueMicrotask 替换 setTimeout(..., 0)
queueMicrotask(() => {
  try {
    const x = onFulfilled(this.value)
    resolvePromise(apromise, x, resolve, reject)
  } catch (err) {
    reject(err)
  }
})

// 优化 6:executor 类型校验
if (typeof executor !== 'function') {
  throw new TypeError(`Promise resolver ${executor} is not a function`)
}
```

---

## 八、运行流程串讲

源码末尾的示例:

```js
new APromise(r => setTimeout(() => r(1111), 1000))   // ① 1s 后 fulfilled
  .then(data => new APromise(r => setTimeout(() => r(data), 1000)))  // ② 返回新 promise
  .then(text => { console.log('text', text); return text })          // ③ 等②完成后执行
  .catch(err => console.log('请求失败了', err))                       // ④ 链路兜底
```

### 执行时序

| 时间   | 事件 |
|--------|------|
| 0 ms     | 构造第一个 promise,状态 `pending`;`.then()` 注册回调进队列 |
| 1000 ms  | `resolve(1111)` → 状态 `fulfilled` → 取出回调进入 `setTimeout` 队列 |
| 下个事件循环 | 执行第一个回调,**返回新 promise**,触发 `resolvePromise` 递归 |
| 2000 ms  | 第二个 promise resolve → 经 `resolvePromise` 调用外层 `resolve(1111)` |
| 下个事件循环 | 第二个 then 的 `onFulfilled` 执行,`console.log('text', 1111)` |
| 结束     | 整条链无错,`catch` 不触发 |

---

## 九、总结

这份代码完整实现了 Promises/A+ 规范的核心特性:

- ✅ **状态机** —— pending → fulfilled / rejected,且不可逆
- ✅ **异步回调队列** —— pending 时缓存,resolve/reject 时批量触发
- ✅ **thenable 解析** —— `resolvePromise` 递归处理嵌套 promise
- ✅ **链式调用** —— 每次 `then` 返回新 promise
- ✅ **值穿透** —— `then()` 不传参数时透传到下一环
- ✅ **错误冒泡** —— 链路任一环抛错,最终被 `catch` 捕获

历史上存在的 3 处缺陷(`PEDDING` 拼写、`REJECTED(error)` 误用、回调触发位置)**已在当前源码中修复**,主体逻辑完整正确,可通过 `promises-aplus-tests` 的 **872 条测试用例**。

### 手写 Promise 的考察点(面试常问)

1. **状态机不可逆性** —— 为什么要 `if (status === PENDING)` 守卫
2. **异步性** —— 为什么 `onFulfilled` 不能同步执行
3. **链式调用** —— 为什么 `then` 必须返回新 promise
4. **`resolvePromise` 解析过程** —— 如何处理嵌套 thenable
5. **值穿透与错误冒泡** —— 为什么末尾挂一个 `catch` 就够了
6. **微任务 vs 宏任务** —— 原生用微任务,手写常用 `setTimeout` 兜底

---

## 十、嵌套 Promise 链式调用完整执行流程

本章针对源码末尾的典型示例,从「**实例创建 → 回调注册 → 定时器触发 → 状态扩散**」四个维度做**逐毫秒级**的剖析。

### 10.1 示例代码

```js
new APromise((resolve, reject) => {            // P1
  setTimeout(() => { resolve(1111) }, 1000)
})
  .then((data) => {                            // T1 → 产生 P2
    return new APromise((resolve, reject) => { // P3
      setTimeout(() => { resolve(data) }, 1000)
    })
  })
  .then((text) => {                            // T2 → 产生 P4
    console.log('text', text)
    return text
  })
  .catch((err) => {                            // C1 → 产生 P5
    console.log('请求失败了', err)
  })
```

### 10.2 涉及的 5 个 Promise 实例

| 标识 | 来源                         | 作用                       |
|------|------------------------------|----------------------------|
| P1   | `new APromise(...)`          | 最外层 promise(原始 promise)|
| P2   | 第一个 `.then()` 的返回值    | 链路第二环                  |
| P3   | T1 回调内部 `new APromise`   | T1 返回的「嵌套 promise」   |
| P4   | 第二个 `.then()` 的返回值    | 链路第三环                  |
| P5   | `.catch()` 的返回值          | 链路第四环                  |

---

### 10.3 阶段 1:同步代码执行(0 ms)

#### Step 1.1 创建 P1

```js
new APromise((resolve, reject) => {
  setTimeout(() => { resolve(1111) }, 1000)
})
```

- 构造函数运行,初始化:`status = 'pending'`、`onFulfilledCallbacks = []`、`onRejectCallbacks = []`
- 立刻同步执行 executor → 调用 `setTimeout(..., 1000)`,把「1000ms 后调用 `resolve(1111)`」任务**挂入定时器队列**
- executor 返回,**P1 状态仍是 pending**

#### Step 1.2 调用 `P1.then(T1)` → 产生 P2

进入 `then(onFulfilled = T1, onRejected = undefined)`:

```js
onFulfilled = T1                                       // 是函数,保留
onRejected  = (err) => { throw err }                   // 不是函数,启用值穿透默认值
let apromise = new APromise((resolve, reject) => {     // ← 这就是 P2
  if (this.status === PENDING) {                       // ✅ P1 是 pending,进入此分支
    this.onFulfilledCallbacks.push(() => {
      setTimeout(() => {
        const x = onFulfilled(this.value)              // T1(1111)
        resolvePromise(apromise, x, resolve, reject)
      }, 0)
    })
    this.onRejectCallbacks.push(...)
  }
})
return apromise                                        // 返回 P2
```

关键结果:
- **P2 处于 pending**
- P1 的 `onFulfilledCallbacks` 中**多了一个等待执行的回调**(我们称为 **CB1**)
- CB1 闭包持有 `apromise(=P2)`、`T1`、`P2.resolve`、`P2.reject`

#### Step 1.3 调用 `P2.then(T2)` → 产生 P4

逻辑同 1.2:**P2 也是 pending**,所以将一个回调(**CB2**)推入 `P2.onFulfilledCallbacks`,返回 P4。

CB2 闭包持有:`apromise(=P4)`、`T2`、`P4.resolve`、`P4.reject`。

#### Step 1.4 调用 `P4.catch(C1)` → 产生 P5

```js
APromise.prototype.catch = function (errCallback) {
  return this.then(null, errCallback)   // 等价 P4.then(null, C1)
}
```

进入 `P4.then(null, C1)`:
- `onFulfilled = null` → **触发值穿透**,变成 `v => v`
- `onRejected = C1`
- P4 是 pending → 把回调 **CB3**(成功透传)和 **CB4**(走 C1)推入 P4 的两个队列
- 返回 P5

#### 阶段 1 结束时的状态快照

| 实例 | 状态     | 等待队列                                 |
|------|----------|------------------------------------------|
| P1   | pending  | onFulfilledCallbacks = [**CB1**]         |
| P2   | pending  | onFulfilledCallbacks = [**CB2**]         |
| P3   | 还未创建 | —                                        |
| P4   | pending  | onFulfilledCallbacks = [**CB3**], onRejectCallbacks = [**CB4**] |
| P5   | pending  | —                                        |

此时同步代码全部执行完毕,**主线程进入事件循环**,等待定时器触发。

---

### 10.4 阶段 2:第 1 秒触发(1000 ms)

#### Step 2.1 P1 的 setTimeout 触发 → `resolve(1111)`

```js
const resolve = (data) => {
  if (this.status == PENDING) {
    this.status = FULFILLED
    this.value = 1111
    this.onFulfilledCallbacks.forEach((fn) => fn())   // 执行 CB1
    this.onFulfilledCallbacks = []
  }
}
```

- **P1 状态:pending → fulfilled,value = 1111**
- 同步执行队列中的 CB1

#### Step 2.2 CB1 执行 → 注册 `setTimeout(..., 0)`

```js
() => {
  setTimeout(() => {
    const x = onFulfilled(this.value)                  // T1(1111)
    resolvePromise(apromise, x, resolve, reject)
  }, 0)
}
```

CB1 本身只做了一件事:**把「调用 T1 并处理结果」安排到下一个事件循环宏任务**。

> 💡 这一层 `setTimeout(..., 0)` 是 A+ 规范要求的「异步执行」 —— 即使 P1 已经 fulfilled,也不能在当前栈里直接执行 T1。

#### Step 2.3 宏任务出队 → 真正执行 T1

```js
const x = T1(1111)
```

T1 内部:

```js
(data) => {
  return new APromise((resolve, reject) => {           // ← P3 在此创建
    setTimeout(() => { resolve(data) }, 1000)          // 1000ms 后 resolve(1111)
  })
}
```

- **创建 P3**,executor 内挂上另一个 1000ms 的 setTimeout
- T1 返回 P3,所以 `x = P3`

#### Step 2.4 调用 `resolvePromise(P2, P3, P2.resolve, P2.reject)`

```js
if (promise === x) { ... }              // P2 !== P3,跳过
if ((typeof x === 'object' && x !== null) || typeof x === 'function') {
  const then = x.then                   // P3.then —— APromise 原型上的方法
  if (typeof then === 'function') {
    then.call(P3,
      (y) => resolvePromise(P2, y, P2.resolve, P2.reject),
      (r) => P2.reject(r)
    )
  }
}
```

这里发生了**关键的连接**:相当于执行 `P3.then(成功包装器, 失败包装器)`。
进入 P3 的 `then`:
- P3 是 pending → 把「成功包装器」推入 **P3.onFulfilledCallbacks**(称为 **CB5**)
- 返回一个新的 promise(无人接收,忽略)

> ⚠️ 此时 **P2 仍是 pending** —— 它在等 P3 完成。

#### 阶段 2 结束时的状态快照

| 实例 | 状态      | value | 等待队列                                            |
|------|-----------|-------|-----------------------------------------------------|
| P1   | fulfilled | 1111  | 已清空                                              |
| P2   | pending   | —     | CB2(等 P2 完成)                                   |
| P3   | pending   | —     | **CB5**(等 P3 完成 → 用 y 去 resolve P2)          |
| P4   | pending   | —     | CB3、CB4                                            |
| P5   | pending   | —     | —                                                   |

---

### 10.5 阶段 3:第 2 秒触发(2000 ms)

#### Step 3.1 P3 的 setTimeout 触发 → `P3.resolve(1111)`

`data` 是闭包变量,值是 1111(来自 T1 的入参)。

- **P3 状态:pending → fulfilled,value = 1111**
- 执行 CB5

#### Step 3.2 CB5 执行(P3 的成功回调)

```js
(y) => resolvePromise(P2, y, P2.resolve, P2.reject)
// y = 1111
```

调用 `resolvePromise(P2, 1111, P2.resolve, P2.reject)`:

```js
if (promise === x) ...                  // 1111 是数字,跳过
if (typeof x === 'object' || typeof x === 'function') ...  // 1111 不是,跳过
else {
  resolve(x)                            // P2.resolve(1111) ✅
}
```

#### Step 3.3 `P2.resolve(1111)` 执行

- **P2 状态:pending → fulfilled,value = 1111**
- 执行 P2 的 CB2(它推动 P4 前进)

#### Step 3.4 CB2 安排 `setTimeout(..., 0)` 执行 T2

仍然是 A+ 异步约束,T2 进入下一个宏任务。

#### Step 3.5 宏任务出队 → 执行 T2

```js
const x = T2(1111)
// T2:
(text) => {
  console.log('text', text)   // ✅ 输出 "text 1111"
  return text                 // 返回 1111
}
```

控制台输出:

```
text 1111
```

`x = 1111`。

#### Step 3.6 `resolvePromise(P4, 1111, P4.resolve, P4.reject)`

普通值 → 直接 `P4.resolve(1111)`:
- **P4 状态:pending → fulfilled,value = 1111**
- 执行 CB3(catch 链中的成功透传)

#### Step 3.7 CB3 安排 setTimeout → 透传

```js
() => v => v                  // P4 透传给 P5
const x = (v => v)(1111)      // x = 1111
resolvePromise(P5, 1111, P5.resolve, P5.reject)
// → P5.resolve(1111)
```

- **P5 状态:pending → fulfilled,value = 1111**
- P5 没有人再 `.then`,链路结束

#### 阶段 3 结束时的最终状态

| 实例 | 状态      | value | 备注                |
|------|-----------|-------|---------------------|
| P1   | fulfilled | 1111  | —                   |
| P2   | fulfilled | 1111  | —                   |
| P3   | fulfilled | 1111  | T1 内部嵌套 promise |
| P4   | fulfilled | 1111  | —                   |
| P5   | fulfilled | 1111  | catch 未被触发      |

C1 始终未执行(全程无异常)。

---

### 10.6 关键时间线总览

```
时间(ms)  事件
─────────────────────────────────────────────────────────────
0          创建 P1(executor 注册 1000ms 定时器)
0          P1.then(T1) → 创建 P2,CB1 入 P1.成功队列
0          P2.then(T2) → 创建 P4,CB2 入 P2.成功队列
0          P4.catch(C1) ≡ P4.then(null, C1) → 创建 P5,CB3/CB4 入 P4 队列
─────────────────────────────────────────────────────────────
1000       P1 fulfilled(1111)→ CB1 执行 → 排入 setTimeout(0)
1000+ε     宏任务出队 → 调用 T1(1111)→ 创建 P3(注册 1000ms 定时器)
1000+ε     resolvePromise(P2, P3, ...) → 等价 P3.then(...)
           CB5 入 P3.成功队列;P2 仍 pending
─────────────────────────────────────────────────────────────
2000       P3 fulfilled(1111)→ CB5 执行
2000       CB5 内调用 resolvePromise(P2, 1111, ...) → P2.resolve(1111)
2000       P2 fulfilled → CB2 执行 → 排入 setTimeout(0)
2000+ε     宏任务出队 → 调用 T2(1111)→ 打印 "text 1111"
2000+ε     resolvePromise(P4, 1111, ...) → P4.resolve(1111)
2000+ε     P4 fulfilled → CB3 执行 → 排入 setTimeout(0)
2000+2ε    宏任务出队 → 透传 → P5.resolve(1111)
─────────────────────────────────────────────────────────────
```

---

### 10.7 最容易绕晕的两个关键点

#### 🔑 关键点 1:T1 返回 promise 时,P2 为何能「等」P3?

核心在 `resolvePromise` 里这段:

```js
then.call(x,
  (y) => resolvePromise(promise, y, resolve, reject),  // 用 P3 的成功值去 resolve P2
  (r) => reject(r)                                     // 用 P3 的失败原因去 reject P2
)
```

这相当于在 P3 上注册了一对监听器,**把 P3 的「未来结果」重定向到 P2**。
所以 `.then(() => promise2)` 的本质就是 **「P2 命运 = P3 命运」**。

#### 🔑 关键点 2:为什么 `setTimeout(..., 0)` 不可省?

A+ 规范要求 `onFulfilled / onRejected` 必须在**当前调用栈清空后**才能调用。例如:

```js
const p = new APromise(r => r(1))
p.then(v => console.log('A'))
console.log('B')
```

如果 then 同步执行,会先输出 A 后输出 B,违反「异步性」承诺。
原生 Promise 用微任务,这里用宏任务模拟,**顺序「B → A」这点是一致的**(仅相对其他微任务的位置不同)。

---

### 10.8 最终控制台输出

```
text 1111
```

(在第一个 1000ms 后开始 T1,第二个 1000ms 后开始 T2 并打印,共耗时约 2 秒)

### 10.9 一句话总结这个例子

> 整条链路通过 **`onXxxCallbacks` 队列 + 闭包持有 resolve/reject** 实现了「**状态扩散**」:
> P3 fulfilled → P2 fulfilled → P4 fulfilled → P5 fulfilled,每一环都是上一环触发,**catch 因全程无异常而不执行**。
