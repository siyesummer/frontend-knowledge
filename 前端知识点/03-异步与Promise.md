# 异步与 Promise

> 从根级《前端知识点.md》按主题拆分而来。

## JavaScript 事件循环（Event Loop）

> JS 是**单线程**语言，但通过 Event Loop 实现了**非阻塞的异步执行**。理解 Event Loop 是搞懂 `setTimeout` / Promise / `async-await` / `requestAnimationFrame` / `nextTick` 等所有异步行为的钥匙。

### 一、为什么需要 Event Loop

JavaScript 的设计是**单线程**的（一次只能做一件事）。如果用同步阻塞的方式：

```javascript
ajax('/api')      // 等服务器返回 → 几秒
renderUI()        // 再渲染
```

页面会卡死。因此需要一种机制把"耗时任务"挂起，先做其它事，等结果回来时再处理——这就是**异步**。Event Loop 就是 JS 协调"同步代码 / 异步回调 / 渲染"的调度核心。

---

### 二、宏观角色

```
┌──────────────────────────────────────────────────────────┐
│                  JS 引擎 (V8 / SpiderMonkey)              │
│  ┌────────────┐   ┌────────────┐   ┌──────────────────┐  │
│  │ 调用栈     │   │ 堆 Heap    │   │ 字节码 / JIT      │  │
│  │ Call Stack │   │ (对象)     │   │                  │  │
│  └────────────┘   └────────────┘   └──────────────────┘  │
└──────────────────────────────────────────────────────────┘
            │                                              ▲
            │ 把异步任务派发出去                            │ 回调入队
            ▼                                              │
┌──────────────────────────────────────────────────────────┐
│                宿主环境 (浏览器 / Node.js)                 │
│                                                          │
│   Web APIs：DOM / setTimeout / fetch / XHR / IO ...      │
│                                                          │
│   ┌──────────────┐         ┌──────────────────────┐      │
│   │ 宏任务队列   │         │ 微任务队列            │      │
│   │ MacroTask    │         │ MicroTask            │      │
│   │ (Task queue) │         │ (Microtask queue)    │      │
│   └──────────────┘         └──────────────────────┘      │
│           ▲                          ▲                   │
│           │                          │                   │
│   setTimeout/setInterval         Promise.then            │
│   I/O / UI 事件 / postMessage    queueMicrotask           │
│   MessageChannel                  MutationObserver        │
└──────────────────────────────────────────────────────────┘
```

**关键术语**：

- **调用栈（Call Stack）**：JS 引擎执行函数的地方，LIFO
- **任务队列（Task Queue）**：又叫宏任务队列、callback queue
- **微任务队列（Microtask Queue）**：优先级高于宏任务
- **Web APIs**：宿主环境提供的异步能力（浏览器或 Node）

---

### 三、宏任务 vs 微任务

#### 1. 宏任务（Macrotask / Task）

| 来源 | 触发时机 |
|------|---------|
| `setTimeout` / `setInterval` | 定时到点 |
| `setImmediate`（Node） | I/O 完成后 |
| I/O 完成回调 | 比如 fs.readFile |
| UI 事件回调 | click / scroll 等 |
| `postMessage` / `MessageChannel` | 跨上下文通信 |
| `<script>` 整体执行 | 每加载一个 script 都是一个宏任务 |

#### 2. 微任务（Microtask）

| 来源 | 说明 |
|------|------|
| `Promise.then / catch / finally` | Promise 状态转换后的回调 |
| `queueMicrotask(fn)` | 显式入队微任务 |
| `MutationObserver` | DOM 变动观察（浏览器） |
| `process.nextTick`（Node） | Node 中比微任务还高优先级 |
| `async/await` 的恢复点 | await 后的代码本质是 Promise.then 回调 |

#### 3. 一句话区分

> **微任务的优先级高于宏任务**——每个宏任务执行完后，**会清空整个微任务队列**才进入下一个宏任务。

#### 4. 为什么需要两种队列？只设计一种可以吗？

**结论：不可以。两种队列解决的是不同层级的问题——宏任务负责"粗粒度的时间分片与公平调度"，微任务负责"同一轮 tick 内的高优收尾"。只保留一种会破坏异步语义、阻塞渲染、或导致回调饿死。**

##### 4.1 如果只有宏任务队列（没有微任务）

想象 Event Loop 只保留一个队列，所有异步回调一律排队：

```
队列: [宏A, 宏B, Promise回调1, Promise回调2, 宏C, ...]
```

**问题一：Promise 回调无法"插队"到下一个宏任务之前**

Promise 规范要求 `.then()` 回调必须**在当前宏任务结束后立即执行**，即"紧贴当前宏任务、在下个宏任务之前"：

```javascript
// 队列中已有两个未到期的宏任务
setTimeout(() => console.log('A'), 0)
setTimeout(() => {
  console.log('B-start')
  // ★ 在宏任务 B 内部，一个 Promise 被 resolve
  Promise.resolve().then(() => console.log('promise'))
  console.log('B-end')
}, 0)
setTimeout(() => console.log('C'), 0)   // 队列中排在后面的宏任务
```

**真实行为（有微任务队列）:**
```
A → B-start → B-end → promise → C
```
关键：`promise` 在 B 执行完后立即作为微任务"插队"到 C 之前。

**假设只有宏任务队列:**
```
A → B-start → B-end → C → promise
```
关键：`promise` 只能在队列尾排队，被 **已经排在队列中的 C** 抢在前面——因为 A、B、C 在 B 执行之前就已经入队了，B 内部产生的回调只能排到最后。

> **一句话**：`Promise.resolve().then(fn)` 注册回调是**同步入队**的（发生在调用 `.then()` 的那一刻），如果此时 Promise 已 resolved，回调直接入队。但由于入队的目标不同——微任务队列允许"超车"到下一个宏任务之前，单个宏任务队列只能乖乖排 FIFO——同一段代码的输出顺序就会不同。

ECMAScript 规范规定 Promise reactions（then/catch/finally 回调）必须作为 **microtask** 入队，目的就是让它**在当前宏任务完成、但浏览器渲染之前执行**，不被其它已排队的宏任务抢先。取消微任务队列等于违反 JS 语言规范。

**问题二：异步链式调用无法"内联"完成**

```javascript
Promise.resolve(1)
  .then(v => v * 2)
  .then(v => v * 3)
  .then(v => console.log(v))  // 期望 6
```

如果每个 `.then` 都作为宏任务排队，这个链式调用会被**穿插的其它宏任务打断**（比如一个到点的 setTimeout、一个 UI 事件），中间状态被外部任务"窥探"到——破坏了 Promise 链的原子性。

**问题三：框架无法保证"一个 tick 内批处理"**

Vue 的 `nextTick`、React 的批量 setState 都依赖**微任务在同一轮 tick 内完成所有变更再渲染**。如果只有宏任务，每一处数据变更都被分到不同 tick，渲染中间态就会被用户看到，UI 出现"闪烁"。

##### 4.2 如果只有微任务队列（没有宏任务）

反过来，把一切异步回调都塞进唯一一个微任务队列：

**问题一：失去"不冻结算法的逃生口"**

微任务是"本轮必须清空"的——在当前真实系统中，用 `Promise.then` 做递归循环就会卡死：

```javascript
// ★ 这段代码在真实 JS 中也会卡死，无论有没有宏任务
function recursive() {
  Promise.resolve().then(() => {
    recursive()    // 新回调塞入微任务队列尾，永远清不完
  })
}
recursive()
// 事件循环永生永世停在"清空微任务"这一环
// 渲染永不执行，页面白板
```

但当前系统的关键不是"微任务不会卡死"，而是**我们有一种"不会卡死"的替代方案——宏任务**：

```javascript
// ★ 这段代码不会卡死：每个回调是一个独立的宏任务，之间能穿插渲染
function safe() {
  setTimeout(() => {
    safe()        // 新回调放到宏任务队列——下一轮 tick 才执行
  }, 0)
}
safe()
// 每执行完一个 setTimeout → 清空微任务 → 渲染一帧 → 取下一个
// 页面不卡，用户正常交互
```

> **关键点**：`recursive()`（微任务递归）和 `safe()`（宏任务递归）**在当前系统中都能写**，只是前者卡死、后者不卡。两者的存在本身就证明了两个队列的分工——**微任务是"本轮收尾"，宏任务是"下轮再干"。**

如果只有微任务队列，**`setTimeout` 回调也成了微任务**——那么 `safe()` 就变成了 `recursive()`，也会卡死。你就**没有任何办法**写一个"不卡死页面的递归异步操作"。UI 事件、I/O 回调也同样没有逃生口——页面要么不响应，要么一响应就陷入微任务死循环。

**问题二：渲染永远不会发生**

事件循环在"清空微任务"之后才判断是否渲染。如果微任务始终清不完（任何稍微耗时一点的页面都有持续的 Promise 回调），浏览器一帧都排不进：

```
时间 →
宏任务A → 微1 → 微2 → 微3 ... → 微N → 渲染？没机会 → 下一个宏任务？
                                                      ↑
                                      永远到不了这里，因为微任务队列永不为空
```

这就解释了为什么 `setTimeout` 是宏任务——**layout/paint 必须每隔一段时间能插进去**，而宏任务之间的"微任务→渲染"缝隙就是渲染的唯一机会。

**问题三：事件处理优先级失控**

用户点击一个按钮，`click` 事件如果作为微任务，它的处理优先级会**高于一个正在排队的 `setTimeout` 回调**——这本身没错，User Action 优先级确实应该高。但问题在于：

```javascript
button.addEventListener('click', () => {
  // 如果是微任务: 插入微任务队列 → 必须等本轮结束 → 其他宏任务都被跳过
  // 如果是宏任务: 进入宏任务队列 → 等当前宏任务完 → 清空微任务 → 执行 click → 渲染
})
```

UI 事件本身是外部行为，用宏任务队列承载意味着"本轮工作不被打断，新事件在下轮处理"——这是一种自然的临界区保护。如果所有 I/O、事件都挤进微任务，等同于"任何异步源都能打断当前宏任务的后续代码"，执行顺序完全失控。

##### 4.3 两层队列的精妙分工

```
宏任务 (MacroTask)                      微任务 (MicroTask)
─────────────────                      ──────────────────
一个 tick 只消费 1 个                   一个 tick 清空整个队列
来源: 外部环境（网络/计时/用户）         来源: JS 代码内部（Promise/async）
语义: "下一轮再处理的粗粒度工作"         语义: "本轮必须收尾的细粒度工作"
相当于"多线程里的时间片调度"             相当于"当前时间片内的尾调用"
允许在任务之间穿插渲染                   紧贴宏任务之后、渲染之前执行
保证公平性：每个源都有机会执行            保证响应性：Promise 链立即完成
```

**一句话类比**：

> 宏任务是 **"大任务"**——定时器、I/O 结果、用户输入，这些是按时间片逐一切换的，每做完一个大任务可以休息（渲染）。
> 微任务是 **"大任务的收尾"**——每做完一件大任务后马上打扫干净（Promise 链、数据变更通知），打扫完了再进入下一件大任务。
>
> **如果只有宏任务**："打扫"也成了"一件大任务"——Promise 链被延迟到下一 tick，链式调用被穿插打断，规范语义破灭。
> **如果只有微任务**："打扫"和"干活"不分——外部事件和内部回调混在一个队列，渲染永远排不上，一个递归就死锁页面。
>
> **两层队列 = 时间分片（宏） + 批处理收尾（微）= 既能公平调度、又能原子执行、还能正常渲染。**

---

### 四、Event Loop 的核心循环（浏览器规范版）

HTML 规范定义的循环步骤（简化）：

```
loop {
  1. 从【宏任务队列】取一个任务，放到调用栈执行（直到栈空）
  2. 执行【微任务队列】里的所有任务（包括过程中新产生的微任务）
  3. （必要时）执行渲染：style / layout / paint / requestAnimationFrame
  4. 回到 1
}
```

通俗记忆：**一个宏任务 → 清空所有微任务 → 渲染 → 下一个宏任务**。

#### “必要时执行渲染：style / layout / paint / requestAnimationFrame” 到底是什么意思

这句话很容易被误解成：

> “每轮 Event Loop 一定会完整执行一次渲染流水线”

其实不是。  
更准确地说是：

> **浏览器会在宏任务和微任务都处理完之后，检查这一帧是否需要渲染；如果需要，才会插入渲染阶段。**

也就是说，“渲染”不是无条件发生的，而是**有条件、按帧节奏**发生的。

---

#### 1. 一帧里的大致顺序

浏览器在一帧内可以粗略理解为：

```text
宏任务
→ 清空微任务
→ 如果到达渲染时机：
    requestAnimationFrame
    → style
    → layout
    → paint
    → composite
→ 下一个宏任务
```

这里最关键的是：

- `requestAnimationFrame` 在真正绘制前执行
- `style / layout / paint` 也都属于“渲染管线”
- 不是每一轮都会全部执行

---

#### 2. `requestAnimationFrame` 在哪一层

`requestAnimationFrame` 不是普通宏任务，也不是微任务。  
它是浏览器专门提供的**渲染前回调时机**。

```javascript
requestAnimationFrame(() => {
  box.style.transform = 'translateX(100px)'
})
```

它的特点是：

1. 通常在下一帧渲染前执行
2. 适合做动画更新
3. 浏览器会尽量让它和屏幕刷新节奏对齐

所以它常被称为：

> “这一帧最后一次改 DOM / 样式、并赶上本帧绘制的机会”

#### 为什么它在 paint 前很重要

如果你在 `rAF` 里改样式：

- 浏览器可以把这些修改并入当前这一帧后续的 `style/layout/paint`
- 动画更平滑
- 不容易错过当前帧

而如果你用 `setTimeout(fn, 16)` 模拟动画：

- 不和真正屏幕刷新同步
- 帧率不稳定
- 容易掉帧

---

#### 3. style：样式计算

style 阶段做的事可以理解为：

> “每个元素最终应该长什么样”

浏览器会综合这些信息：

- HTML 结构
- CSS 规则
- 继承规则
- 优先级和层叠
- 行内样式
- 媒体查询

最终算出每个节点的**computed style**。

例如：

```javascript
el.style.color = 'red'
el.className = 'active'
```

这类操作通常会让浏览器认为：

- 这个元素的样式结果变了
- 后续可能需要重新做 style 计算

#### style 不一定导致 layout

比如你只改：

```javascript
el.style.color = 'blue'
```

颜色变了，但元素大小和位置没变，这通常只需要：

- style
- paint

不一定要 layout。

---

#### 4. layout：布局 / 回流 / 重排

layout 阶段做的事是：

> “元素最终放在哪里，占多大空间”

它要计算：

- 宽高
- 位置
- 盒模型尺寸
- 文本换行后的实际占位

比如这些操作通常可能触发布局：

```javascript
el.style.width = '200px'
el.style.fontSize = '20px'
parent.appendChild(child)
```

因为它们会影响：

- 元素自身尺寸
- 周围元素排布
- 文档流结构

#### 为什么 layout 成本高

因为 layout 往往不是只算一个元素。  
一个节点变化，可能影响：

- 父元素尺寸
- 兄弟元素位置
- 子元素布局

所以 layout 往往是渲染链路里成本较高的一环。

---

#### 5. paint：绘制 / 重绘

paint 阶段做的事是：

> “把元素画出来”

例如要绘制：

- 文字颜色
- 背景色
- 边框
- 阴影
- 图片内容

如果布局没变，只是外观变了，例如：

```javascript
el.style.background = 'red'
```

通常可能只需要：

- style
- paint

而不需要 layout。

---

#### 6. composite：合成

虽然你那句原文里没写 `composite`，但实际渲染链路里通常还要再补这一层。

可以理解为：

> 浏览器把各个图层最终拼到屏幕上

像下面这些属性：

- `transform`
- `opacity`

通常更容易只影响合成阶段，因此更适合做高性能动画。

这就是为什么前端性能优化里总说：

> 动画优先用 `transform` 和 `opacity`

因为它们更容易绕开高成本的 layout / paint。

---

#### 7. 什么叫“必要时才渲染”

浏览器不会无意义地每轮都重画页面。  
只有在满足“值得渲染”的条件时，才会进入渲染阶段。

常见情况：

1. DOM 或样式发生了变化
2. 到了浏览器这一帧的刷新时机
3. 当前页面不是被长时间 JS 阻塞
4. 页面可见且浏览器没有节流到很低频

如果这一轮什么都没变，浏览器可能：

- 不做 layout
- 不做 paint
- 甚至这帧什么都不画

---

#### 8. 为什么微任务会阻塞渲染

因为浏览器的顺序是：

```text
先清空微任务
再考虑渲染
```

所以如果你一直制造新的微任务：

```javascript
function loop() {
  Promise.resolve().then(loop)
}
loop()
```

浏览器就会一直忙着清空微任务队列，根本到不了渲染阶段。

这就是为什么：

- 微任务优先级很高
- 但滥用微任务会卡死页面

---

#### 9. 为什么“读写交替”会触发强制同步布局

下面这种代码是典型性能陷阱：

```javascript
el.style.width = '100px'
console.log(el.offsetWidth)
el.style.width = '200px'
console.log(el.offsetWidth)
```

原因是：

1. 你先“写”了样式
2. 浏览器本来想稍后统一做 layout
3. 但你立刻又“读”了 `offsetWidth`
4. 为了给你准确值，浏览器只能**立刻强制做一次 layout**

这就叫：

> 强制同步布局（forced synchronous layout）

它会打断浏览器原本的批处理优化，性能很差。

#### 更好的做法

- 先批量读
- 再批量写
- 或把写操作集中到 `requestAnimationFrame`

---

#### 10. 一个完整例子串起来看

```javascript
button.addEventListener('click', () => {
  box.style.width = '200px'

  Promise.resolve().then(() => {
    box.style.background = 'red'
  })

  requestAnimationFrame(() => {
    box.style.transform = 'translateX(100px)'
  })
})
```

可以这样理解：

1. 点击回调属于一个宏任务
2. 先执行同步代码，修改 `width`
3. 再清空微任务，修改 `background`
4. 到了渲染时机，先执行 `requestAnimationFrame`
5. 浏览器统一做后续的 style / layout / paint / composite

这样浏览器就有机会把多次修改合并到同一帧里处理。

---

#### 11. 一句话抓重点

> “必要时执行渲染” 的真正含义不是“每轮都渲染”，而是：**宏任务和微任务都清完之后，浏览器会在合适的帧时机，先跑 `requestAnimationFrame`，再按需要做 style、layout、paint、composite。**

#### 完整流程图

```
    ┌──────────────────────────────────┐
    │  从宏任务队列取 1 个任务执行     │
    └────────────────┬─────────────────┘
                     │ 调用栈空了
                     ▼
    ┌──────────────────────────────────┐
    │  清空微任务队列                  │
    │  （执行过程中新产生的微任务      │
    │   也要继续清空，直到为空）       │
    └────────────────┬─────────────────┘
                     ▼
    ┌──────────────────────────────────┐
    │  是否需要渲染？                  │
    │  执行 rAF → style → layout       │
    │     → paint                      │
    └────────────────┬─────────────────┘
                     ▼
                  下一轮
```

---

### 五、经典代码题解析

#### 题目

```javascript
console.log(1)

setTimeout(() => console.log(2), 0)

Promise.resolve().then(() => console.log(3))

Promise.resolve().then(() => {
  console.log(4)
  setTimeout(() => console.log(5), 0)
})

console.log(6)
```

#### 输出顺序

```
1  6  3  4  2  5
```

#### 逐步推演

| 步骤 | 调用栈 | 微任务队列 | 宏任务队列 | 输出 |
|------|--------|-----------|-----------|------|
| 1 | 执行同步代码 | | | 1 |
| 2 | setTimeout 注册 | | [T1: log(2)] | |
| 3 | Promise.then 注册 | [M1: log(3)] | [T1] | |
| 4 | Promise.then 注册 | [M1, M2] | [T1] | |
| 5 | 同步代码继续 | | | 6 |
| 6 | 栈空，清空微任务 M1 | [M2] | [T1] | 3 |
| 7 | 清空微任务 M2 | [] | [T1] | 4 |
| 8 | M2 中注册了 setTimeout | | [T1, T2: log(5)] | |
| 9 | 取一个宏任务 T1 | | [T2] | 2 |
| 10 | 清空微任务 (空) | | [T2] | |
| 11 | 取 T2 | | [] | 5 |

**关键点**：步骤 7 中 M2 又注册了一个 setTimeout —— 它进入**宏任务**队列，而不是"插队"到当前队列。

---

### 六、`async / await` 的本质

`await` 是 `Promise.then` 的语法糖：

```javascript
async function f() {
  console.log(1)
  await Promise.resolve()
  console.log(2)        // ← 这一行等价于 .then(() => log(2))
  console.log(3)        // ← 也属于同一个 .then 回调
}

f()
console.log(4)

// 输出: 1 4 2 3
```

`await` 之后的所有代码会被打包成一个**微任务**。所以 await 的"等待"本质上是把后续代码挪到微任务队列。

#### 进阶题

```javascript
async function async1() {
  console.log('A1 start')// 2
  await async2()
  console.log('A1 end') // 6
}
async function async2() {
  console.log('A2') // 3
}

console.log('script start')// 1
setTimeout(() => console.log('setTimeout'), 0) // 8
async1()
new Promise(resolve => {
  console.log('promise1') // 4
  resolve()
}).then(() => console.log('promise2')) // 7
console.log('script end') // 5
```

输出顺序：

```
script start
A1 start
A2
promise1
script end
A1 end       ← await 后续作为微任务
promise2     ← Promise.then 微任务
setTimeout   ← 宏任务
```

---

### 七、Node.js 的 Event Loop

Node.js 基于 **libuv**，循环分为 **6 个阶段**：

```
   ┌───────────────────────────┐
┌─►│       timers              │  setTimeout / setInterval 到期回调
│  ├───────────────────────────┤
│  │   pending callbacks       │  上一轮延迟的 I/O 回调
│  ├───────────────────────────┤
│  │   idle, prepare           │  内部使用
│  ├───────────────────────────┤
│  │       poll                │  I/O 回调；如果队列空就阻塞等待
│  ├───────────────────────────┤
│  │       check               │  setImmediate 回调
│  ├───────────────────────────┤
│  │   close callbacks         │  socket.on('close', ...)
│  └───────────────────────────┘
│              │
└──────────────┘
```

**每个阶段之间都会清空 `process.nextTick` 队列和微任务队列**（Node 11+ 与浏览器行为对齐）。

#### Node 中的 nextTick 与微任务

```
优先级:  process.nextTick  >  微任务 (Promise.then)  >  宏任务
```

`process.nextTick` 队列优先级**比微任务还高**——所以滥用 `nextTick` 可能导致 I/O 饿死。

#### `setTimeout(fn, 0)` vs `setImmediate(fn)`

主模块中两者顺序**不固定**（取决于 Node 启动到 timers 阶段的耗时）；在 **I/O 回调内部**，`setImmediate` 总是先执行：

```javascript
const fs = require('fs')
fs.readFile('/x', () => {
  setTimeout(() => console.log('timeout'), 0)
  setImmediate(() => console.log('immediate'))
})
// 输出：immediate → timeout
```

原因：I/O 回调在 poll 阶段执行完后立即进入 check 阶段（setImmediate），而 timers 要等下一轮循环回到 timers 阶段。

---

### 八、浏览器渲染的时机

浏览器在一帧内（约 16.7ms / 60fps）大致流程：

```
  宏任务 → 微任务 → 渲染时机判断
                    ├── requestAnimationFrame 回调
                    ├── style 重计算
                    ├── layout 重排
                    └── paint 重绘
```

**关键结论**：

- **微任务在同一帧内**，发生在宏任务之后、渲染之前
- **rAF（requestAnimationFrame）** 在 layout 之前，是"修改样式但还想被这帧渲染"的最佳时机
- **rIC（requestIdleCallback）** 在帧空闲时执行，适合非紧急工作
- **同步循环过久会阻塞渲染**——这是动画卡顿的常见原因

#### 用 setTimeout(fn, 0) ≠ 立即执行

`setTimeout(fn, 0)` 的最低延迟在浏览器中通常是 4ms（嵌套层级 ≥5 时），且要排队等其它宏任务和渲染——所以"立即"是错觉。要真"下一个微任务"用 `queueMicrotask` 或 `Promise.resolve().then`。

---

### 九、典型陷阱

#### 1. 微任务无限自循环阻塞渲染

```javascript
function loop() { Promise.resolve().then(loop) }
loop()          // ❌ 浏览器永远渲染不了，因为微任务清不完
```

宿主在清空微任务之前不会渲染，**死循环的微任务会冻结页面**。

而宏任务循环不会：

```javascript
function loop() { setTimeout(loop, 0) }
loop()          // ✅ 浏览器能正常渲染，每帧能挤进来
```

#### 2. `await` 在循环里的陷阱

```javascript
async function bad() {
  for (const url of urls) {
    await fetch(url)        // 串行：每次等上一个完成
  }
}

async function good() {
  await Promise.all(urls.map(fetch))   // 并行
}
```

#### 3. 错误的"取消"机制

```javascript
let cancelled = false
Promise.resolve().then(() => {
  if (cancelled) return
  doWork()
})
cancelled = true           // ❌ 微任务可能已经在排队，这里赋值后回调里仍读到 false 之前的瞬态
```

用 `AbortController` 或 promise 链外封装专门的取消逻辑。

#### 详细说明：为什么这种“取消”写法不可靠

先看这段代码：

```javascript
let cancelled = false

Promise.resolve().then(() => {
  if (cancelled) return
  doWork()
})

cancelled = true
```

很多人看到后会直觉以为：

> “我已经把 `cancelled = true` 了，所以 `then` 回调就一定不会执行”

但真正的问题没有这么简单。

---

#### 1. 问题的本质不是“变量改不进去”，而是“微任务已经入队了”

当执行到：

```javascript
Promise.resolve().then(callback)
```

时，`callback` 不会立刻执行，但它已经被放进了**微任务队列**。

也就是说：

- 你可以改 `cancelled`
- 但你**不能把这个微任务从队列里撤销**

这才是“伪取消”的核心问题。

所以更准确的说法应该是：

> 你取消不了“这个回调会不会被调度”；你只能在它真正执行时，靠 `if (cancelled) return` 决定“进去以后要不要继续干活”。

---

#### 2. 上面这段代码里，回调最终会读到什么

对这段代码本身来说：

```javascript
let cancelled = false

Promise.resolve().then(() => {
  if (cancelled) return
  doWork()
})

cancelled = true
```

执行顺序是：

1. 同步代码开始执行
2. `Promise.resolve().then(...)` 把回调放进微任务队列
3. 继续执行后面的同步代码：`cancelled = true`
4. 当前同步代码结束
5. Event Loop 开始清空微任务队列
6. 回调执行，读取到**最新的** `cancelled === true`

所以在这段最简单的代码里，回调通常会读到 `true`，于是 `return`，`doWork()` 不执行。

#### 这说明什么

说明这句注释如果机械理解成：

> “赋值后回调还会读到旧的 false”

是不严谨的。

**闭包里读到的不是“排队那一刻的快照值”**，而是回调真正执行那一刻这个变量的当前值。

---

#### 3. 那为什么这种写法仍然危险

危险点在于：**取消是否赶得上，完全取决于时序。**

如果你的“取消”动作发生得足够早，确实能挡住后续逻辑；  
但如果取消发生得太晚，微任务可能已经执行完了。

例如：

```javascript
let cancelled = false

Promise.resolve().then(() => {
  if (cancelled) return
  doWork()
})

setTimeout(() => {
  cancelled = true
}, 0)
```

这里顺序就变成：

1. `then` 回调进入微任务队列
2. `setTimeout` 回调进入宏任务队列
3. 当前同步代码结束
4. 浏览器先清空微任务队列
5. `then` 回调执行，此时 `cancelled` 还是 `false`
6. `doWork()` 已经跑了
7. 下一轮宏任务才轮到 `setTimeout`，这时再 `cancelled = true` 已经晚了

这才是实战里真正常见的问题：

> 你不是“读到了旧值快照”，而是“取消发生在微任务执行之后，所以根本来不及阻止”。

---

#### 4. 再看一个更像真实业务的场景

```javascript
let cancelled = false

function load() {
  Promise.resolve().then(() => {
    if (cancelled) return
    render('old result')
  })
}

load()

// 某个稍后的异步时机才决定取消
setTimeout(() => {
  cancelled = true
}, 0)
```

你以为“已经设置取消了”，但问题是：

- `render('old result')` 所在的微任务早就先执行了
- 取消动作只是**更晚的宏任务**

所以这类布尔标记只是在碰运气：

- 赶上了就生效
- 没赶上就失效

---

#### 5. 为什么说这不是真正的“取消”

真正的取消通常意味着至少要满足一个条件：

1. 阻止未来任务继续执行
2. 阻止正在进行的异步操作继续推进
3. 丢弃过期结果，不让它污染当前状态

而上面的布尔变量方案通常只能做到：

- 回调开始执行后，手动判断一下要不要提前 `return`

它做不到：

- 把已经入队的微任务移出队列
- 真正取消底层请求
- 自动阻止更深层的后续链路

所以它更准确的名字应该是：

> **结果忽略（ignore stale result）**，而不是严格意义上的取消（cancel）。

---

#### 6. Promise 的微任务为什么尤其容易让人误判

因为 Promise 回调有两个特点：

1. **一定异步**
2. **优先级高于后续宏任务**

例如：

```javascript
Promise.resolve().then(() => console.log('then'))
setTimeout(() => console.log('timeout'), 0)
```

输出一定是：

```javascript
then
timeout
```

所以如果你的取消逻辑放在：

- `setTimeout`
- 另一个宏任务回调
- 用户下一次点击触发的异步回调

那它往往根本追不上当前这一批 Promise 微任务。

---

#### 7. 更稳的做法有哪些

#### 1. `AbortController`

适合能被底层 API 真正中断的任务，例如：

```javascript
const controller = new AbortController()

fetch('/api/data', { signal: controller.signal })

controller.abort()
```

这里不是“回调里假装 return”，而是尽量从源头中断任务。

#### 2. 版本号 / 请求序号

这是前端里非常常见也非常稳的方案：

```javascript
let requestId = 0

function load() {
  const id = ++requestId

  Promise.resolve().then(() => {
    if (id !== requestId) return
    render('latest result')
  })
}
```

核心思想：

- 不是试图撤销旧任务
- 而是只允许“最新那次”的结果生效

#### 3. 在 promise 链外维护专门的取消状态机

复杂业务里，通常会把“请求中 / 已取消 / 已过期 / 已完成”做成明确状态，而不是只靠一个裸布尔值。

---

#### 8. 一句话纠偏

这句注释更严谨的表达应该是：

> `cancelled = true` 并不能把已经入队的微任务撤销；回调最终读到什么值，取决于**取消发生时机**。如果取消发生得晚于微任务执行，那么这次“取消”就已经来不及了。

---

### 十、面试速答

**Q1：什么是 Event Loop？**
JS 是单线程的，需要通过 Event Loop 协调同步代码、异步回调、渲染。核心循环：取一个**宏任务**执行 → **清空所有微任务** → 渲染 → 下一轮。

**Q2：宏任务和微任务的区别？**
- 来源不同：宏任务（setTimeout / setInterval / I/O / UI 事件 / script），微任务（Promise.then / queueMicrotask / MutationObserver / process.nextTick）
- **优先级**：每个宏任务执行完后**清空整个微任务队列**才进入下一个宏任务
- 微任务保证在"同一轮 tick"内执行完，宏任务跨 tick

**Q3：`async/await` 在事件循环中是什么？**
`await` 之后的代码相当于 `Promise.then` 的回调，会被加入**微任务**队列。

**Q4：Node 和浏览器的 Event Loop 有何区别？**
- 浏览器规范：一个宏任务 → 清空微任务 → 渲染 → 下一个宏任务
- Node：分 6 个阶段（timers / pending / poll / check / close 等）；多了 `process.nextTick` 队列（优先级**高于**微任务）；Node 11+ 已与浏览器在"宏任务之间清空微任务"上对齐

**Q5：怎么把一个任务尽快放到下一个微任务执行？**
- `queueMicrotask(fn)`（标准 API）
- `Promise.resolve().then(fn)`（兼容性好）

**Q6：为什么不能用 setTimeout(fn, 0) 做"下一微任务"？**
`setTimeout` 是宏任务，被各种排队、渲染、事件挤在后面；最低延迟也不是真正的 0（浏览器 4ms 起，嵌套层级深时）。

### 十一、一句话总结

> JS 单线程通过 Event Loop 实现非阻塞异步。引擎执行**调用栈**里的同步代码；宿主环境（浏览器/Node）维护**宏任务队列**和**微任务队列**。
> 核心规则：**取 1 个宏任务执行 → 清空整个微任务队列 → 渲染（可选） → 下一轮**。
> 微任务（`Promise.then` / `queueMicrotask` / `MutationObserver` / `process.nextTick`）优先级高于宏任务（`setTimeout` / `setInterval` / I/O / UI 事件 / `setImmediate`）。
> `async / await` 本质是 `Promise.then` 语法糖，await 之后的代码就是微任务。

---

---

## Promise 链：`.catch()` 之后还能 `.then()` 吗

### 一、结论：可以

`.catch()` 返回的仍然是一个 Promise，因此可以继续 `.then()`。`.catch()` 本质就是 `.then(undefined, onRejected)` 的语法糖。

### 二、核心规则

**`.then()` 和 `.catch()` 都返回一个新 Promise，上一个回调的返回值决定下一个链的是 `.then` 还是 `.catch`：**

```
上一个回调 return 一个值        → 新 Promise fulfilled  → 走 .then()
上一个回调 return 什么都不写     → 同上（return undefined）
上一个回调 throw / return reject → 新 Promise rejected   → 走 .catch()
```

#### 详细展开：到底是谁决定“下一个 Promise”的状态

很多人看 Promise 链时容易误以为：

> “`.then` 后面就一定走 `.then`，`.catch` 后面就一定走 `.catch`”

其实不是。  
真正决定后续走向的，不是你写的是 `.then()` 还是 `.catch()`，而是：

> **当前这个回调执行完之后，返回给外面的那个“新 Promise”最终变成 fulfilled 还是 rejected。**

也就是说，每次你写：

```javascript
const p2 = p1.then(onFulfilled, onRejected)
```

或者：

```javascript
const p2 = p1.catch(onRejected)
```

本质上都会产生一个**新的 Promise**，我们这里把它叫做 `p2`。  
后面继续 `.then(...)` / `.catch(...)`，接的是 `p2`，不是原来的 `p1`。

---

#### 1. `return 一个普通值`：后续走 fulfilled

```javascript
Promise.resolve(1)
  .then(v => {
    return v + 1
  })
  .then(v => {
    console.log(v) // 2
  })
```

这里第一层 `.then` 回调返回了一个普通值 `2`。  
于是它返回出去的新 Promise 会变成：

```javascript
Promise.resolve(2)
```

所以后续自然走 `.then(...)`。

#### 直观理解

```javascript
return 123
```

约等价于：

```javascript
return Promise.resolve(123)
```

注意这里只是**理解效果等价**，不是字面代码替换。

---

#### 2. `return 什么都不写`：本质是 `return undefined`

```javascript
Promise.resolve('ok')
  .then(v => {
    console.log(v) // ok
    // 没写 return
  })
  .then(v => {
    console.log(v) // undefined
  })
```

因为 JS 函数默认返回 `undefined`，所以这相当于：

```javascript
Promise.resolve('ok')
  .then(v => {
    console.log(v)
    return undefined
  })
```

于是新 Promise 仍然是 fulfilled，只不过值变成了 `undefined`。

这也是为什么：

> `.catch()` 里如果你只是“吞掉错误”但没重新抛出，后面的链通常会恢复成 `.then` 路径。

---

#### 3. `throw`：后续走 rejected

```javascript
Promise.resolve('ok')
  .then(v => {
    throw new Error('boom')
  })
  .then(v => {
    console.log('不会执行')
  })
  .catch(err => {
    console.log(err.message) // boom
  })
```

当回调内部 `throw` 时，当前这次链调用返回的新 Promise 会变成 rejected。

可以把它理解成：

```javascript
throw err
```

约等价于：

```javascript
return Promise.reject(err)
```

同样，这里说的是**效果等价**。

---

#### 4. `return Promise.resolve(...)`：后续等待它 fulfilled

```javascript
Promise.resolve(1)
  .then(v => {
    return Promise.resolve(v + 10)
  })
  .then(v => {
    console.log(v) // 11
  })
```

这时候不是“回调一返回，后面立刻执行”，而是：

1. 当前回调返回了一个 Promise
2. 外层新 Promise 会**跟随这个 Promise 的结果**
3. 它 fulfilled 了，后面才走 `.then`

这就是 Promise 链“自动铺平”的核心。

---

#### 5. `return Promise.reject(...)`：后续走 rejected

```javascript
Promise.resolve(1)
  .then(v => {
    return Promise.reject('fail')
  })
  .then(v => {
    console.log('不会执行')
  })
  .catch(err => {
    console.log(err) // fail
  })
```

因为当前回调返回的是一个 rejected Promise，  
所以外层新 Promise 也会变成 rejected，后续进入 `.catch(...)`。

---

#### 6. `return 另一个 Promise` 时，为什么叫“状态穿透 / 跟随”

例如：

```javascript
const inner = new Promise(resolve => {
  setTimeout(() => resolve(100), 1000)
})

const outer = Promise.resolve().then(() => inner)
```

此时 `outer` 不会立刻 fulfilled，  
它会等待 `inner` 的最终结果：

- `inner fulfilled` → `outer fulfilled`
- `inner rejected` → `outer rejected`

这就是 Promise 规范里的核心语义之一：

> **返回 Promise 时，外层 Promise 会 adopt / follow 内层 Promise 的状态。**

也正因为这个机制，Promise 链才能自然写成：

```javascript
fetch('/api/user')
  .then(res => res.json())
  .then(user => fetch(`/api/order?id=${user.id}`))
  .then(res => res.json())
```

而不是一层一层手动嵌套。

---

#### 7. `.catch()` 为什么后面还能接 `.then()`

因为 `.catch(fn)` 本质就是：

```javascript
.then(undefined, fn)
```

它处理完错误后，也会返回一个**新的 Promise**。

如果 `fn` 内部：

- `return 普通值` → 后续恢复 fulfilled
- `return Promise.resolve(...)` → 后续 fulfilled
- `throw err` → 后续继续 rejected
- `return Promise.reject(...)` → 后续继续 rejected

例如恢复成功路径：

```javascript
Promise.reject('error')
  .catch(err => {
    return 'fallback'
  })
  .then(v => {
    console.log(v) // fallback
  })
```

例如继续维持失败路径：

```javascript
Promise.reject('error')
  .catch(err => {
    throw 'new error'
  })
  .catch(err => {
    console.log(err) // new error
  })
```

---

#### 8. 一个总表记住所有情况

| 当前回调里写了什么 | 新 Promise 状态 | 后续通常走向 |
|---|---|---|
| `return 普通值` | fulfilled | 走 `.then` |
| `return undefined` | fulfilled | 走 `.then` |
| `return Promise.resolve(x)` | fulfilled（等待后） | 走 `.then` |
| `throw err` | rejected | 走 `.catch` |
| `return Promise.reject(err)` | rejected（等待后） | 走 `.catch` |

---

#### 9. 一个最容易错的误区

很多人会写出这样的代码：

```javascript
fetch('/api')
  .then(res => {
    res.json()   // ❌ 忘了 return
  })
  .then(data => {
    console.log(data) // undefined
  })
```

问题就在于第一层回调没有 `return`，  
所以外层新 Promise 拿到的是：

```javascript
undefined
```

而不是 `res.json()` 返回的 Promise。

正确写法应该是：

```javascript
fetch('/api')
  .then(res => {
    return res.json()
  })
  .then(data => {
    console.log(data)
  })
```

或者更简洁：

```javascript
fetch('/api')
  .then(res => res.json())
  .then(data => {
    console.log(data)
  })
```

---

#### 10. 一句话抓核心

> Promise 链里每一步都会产生一个新的 Promise；这个新 Promise 是 fulfilled 还是 rejected，不看你写的是 `.then` 还是 `.catch`，而看**当前回调最后是 return 了什么，还是 throw 了什么**。

### 三、示例

```javascript
// ====== .catch 正常 return → 链恢复为 fulfilled ======
Promise.reject('出错了')
  .catch(e => {
    console.log('捕获:', e)   // 捕获: 出错了
    return '已处理'           // ★ return 正常值 → 返回的 Promise 变成 fulfilled
  })
  .then(v => {
    console.log('继续:', v)   // 继续: 已处理 ✅
  })

// ====== .catch 里 re-throw → 继续走 reject 链路 ======
Promise.reject('出错')
  .catch(e => {
    throw '再次失败'           // ★ 重新抛出 → 返回的 Promise 仍是 rejected
  })
  .then(v => console.log('不会执行'))     // 跳过
  .catch(e => console.log('第二次捕获:', e))  // 第二次捕获: 再次失败 ✅

// ====== .catch 什么都不 return → 走 .then，拿到 undefined ======
Promise.reject('err')
  .catch(e => { /* 吞掉错误，没 return */ })
  .then(v => console.log(v))   // undefined ✅
```

### 四、与 `async/await` 的对应

```javascript
// Promise 链
fetch('/api')
  .then(res => res.json())
  .catch(err => { log(err); return {} })   // 兜底
  .then(data => render(data))              // 继续处理

// 等价的 async/await
async function load() {
  let data
  try {
    const res = await fetch('/api')
    data = await res.json()
  } catch (err) {
    log(err)
    data = {}                // 兜底，等价于 .catch 里 return
  }
  render(data)               // 等价于最后的 .then
}
```

### 五、典型应用场景

**场景 1：请求失败给默认值，后续逻辑不变**

```javascript
fetchUser(id)
  .catch(() => ({ name: '未知用户' }))  // 失败就返回兜底对象
  .then(user => render(user))            // 不管成功还是失败，都会到这里
```

**场景 2：中间清理，错误继续向上抛**

```javascript
fetchData()
  .catch(e => {
    hideLoading()        // 清理 UI
    throw e              // ★ 重新抛出，让上层处理
  })
  .then(data => process(data))
  .catch(e => showError(e))
```

### 六、一张图理解

```
Promise.reject()
      │ fulfilled（不会走这条）
      ▼ rejected ▼
.catch(e => {        ← 捕获 reject
  return 'ok'          ← 返回正常值
})                      │
      ┌─────────────────┘
      ▼ fulfilled
.then(v => {          ← 正常执行！
  console.log(v)        'ok'
})
```

**一句话**：Promise 链里没有 "终止符"——`.catch()` 只是处理了 reject 状态的 `.then()`，返回的仍是 Promise，链条可以无限续接。只有 **`.catch` 内部重新 throw** 才会让后续继续走 reject 路径。

---

---

## 为什么 `.then(onFulfilled, onRejected)` 不如 `.then(...).catch(...)` 推荐

### 一、先看结论

两种写法都能处理错误，但现代代码里通常更推荐：

```javascript
promise
  .then(onFulfilled)
  .catch(onRejected)
```

而不是：

```javascript
promise.then(onFulfilled, onRejected)
```

最核心的原因只有一个：

> `.catch(...)` 的**错误捕获范围更自然、更大**；而 `.then(onFulfilled, onRejected)` 的第二个参数只能处理“前一个 Promise 的 rejected”，接不住 `onFulfilled` 里面新抛出的错误。

---

### 二、两种写法表面上很像

很多人会觉得：

```javascript
promise.then(onFulfilled, onRejected)
```

和：

```javascript
promise.then(onFulfilled).catch(onRejected)
```

只是写法不同，语义差不多。

其实它们最大的区别在于：

- 第一种：`onRejected` 绑定在**当前这个 `.then` 调用上**
- 第二种：`.catch` 绑定在**前面整个链返回出来的新 Promise 上**

这就导致它们能接住的错误范围不同。

---

### 三、`.then(onFulfilled, onRejected)` 能接住什么错误

它的第二个参数 `onRejected` 能处理的是：

> **前一个 Promise 本身就是 rejected**

例如：

```javascript
Promise.reject('fail')
  .then(
    data => {
      console.log('不会执行')
    },
    err => {
      console.log('捕获到:', err) // fail
    }
  )
```

这里没有问题，因为 rejected 是在进入这个 `.then(...)` 之前就已经存在的。

---

### 四、它接不住什么错误

看这个例子：

```javascript
Promise.resolve('ok')
  .then(
    value => {
      console.log(value)
      throw new Error('boom')
    },
    err => {
      console.log('这里不会执行', err)
    }
  )
```

这里很多人误以为第二个参数能处理 `throw new Error('boom')`。  
其实**不能**。

原因是：

1. 这个 Promise 先 fulfilled，所以执行第一个回调 `onFulfilled`
2. `onFulfilled` 执行过程中又抛出了一个新错误
3. 这个新错误会让**当前 `.then(...)` 返回的新 Promise** 变成 rejected
4. 但第二个参数 `onRejected` 是“当前这次 `.then` 的入参”，不是“后续新 Promise 的兜底捕获器”

所以它不会接住这个错误。

正确写法是：

```javascript
Promise.resolve('ok')
  .then(value => {
    console.log(value)
    throw new Error('boom')
  })
  .catch(err => {
    console.log('捕获到:', err.message) // boom
  })
```

---

### 五、为什么 `.catch(...)` 更强

因为：

```javascript
promise.then(onFulfilled).catch(onRejected)
```

本质上是：

1. 先执行 `.then(onFulfilled)`，得到一个**新的 Promise**
2. 再对这个“新的 Promise”统一挂一个 `.catch(onRejected)`

所以 `.catch` 能接住的错误范围包括：

1. 前一个 Promise 本身的 rejected
2. `onFulfilled` 里抛出的错误
3. `onFulfilled` 返回的 Promise 的 rejected

这就更接近我们熟悉的“整段 try 后面接一个 catch”的心智模型。

---

### 六、对比最关键的例子

#### 写法一：不推荐

```javascript
Promise.resolve('ok')
  .then(
    value => {
      throw new Error('boom')
    },
    err => {
      console.log('不会捕获到 boom')
    }
  )
  .catch(err => {
    console.log('真正捕获到:', err.message) // boom
  })
```

这里 `boom` 是被**后面的 `.catch(...)`** 接住的，不是被 `.then` 的第二个参数接住的。

#### 写法二：推荐

```javascript
Promise.resolve('ok')
  .then(value => {
    throw new Error('boom')
  })
  .catch(err => {
    console.log('捕获到:', err.message) // boom
  })
```

这更符合直觉：

- 先写成功逻辑
- 再统一写错误逻辑

---

### 七、和 `try...catch` 的心智模型类比

推荐写法：

```javascript
promise
  .then(step1)
  .then(step2)
  .then(step3)
  .catch(handleError)
```

更像：

```javascript
try {
  step1()
  step2()
  step3()
} catch (err) {
  handleError(err)
}
```

也就是说，它表达的是：

> “前面这整段链路里，只要哪一步出错，都到最后统一处理”

而 `.then(onFulfilled, onRejected)` 更像是：

> “我只在这一小步入口处，单独处理前一个 Promise 的 rejected”

表达力明显弱很多。

---

### 八、什么时候第二个参数不是“错”，只是“不推荐”

`.then(onFulfilled, onRejected)` 不是错误语法，它在规范上完全合法。  
只是从工程实践看，通常不如 `.catch(...)` 清晰。

它偶尔也有使用场景，比如你**明确只想处理前一个 Promise 的 reject**，而不想吞掉后面成功回调内部的异常：

```javascript
promise.then(
  value => transform(value),
  err => recoverOnlySourceError(err)
)
```

但这种需求相对少，绝大多数业务代码更需要的是：

> “统一兜住这整段链路里的错误”

所以 `.catch(...)` 更符合常规预期。

---

### 九、再补一个高频坑

看这段：

```javascript
fetch('/api')
  .then(
    res => res.json(),
    err => {
      console.log('请求失败', err)
    }
  )
```

这里第二个参数只能处理：

- `fetch('/api')` 本身 rejected

但如果：

```javascript
res.json()
```

这一步出错，第二个参数接不住，仍然要靠后面的 `.catch(...)`。

所以更稳的写法是：

```javascript
fetch('/api')
  .then(res => res.json())
  .catch(err => {
    console.log('统一处理错误', err)
  })
```

---

### 十、面试速答

**Q1：`.then(onFulfilled, onRejected)` 和 `.then(...).catch(...)` 的核心区别是什么？**  
核心区别是错误捕获范围不同：`.catch(...)` 能处理前面整段链路里的错误，而 `.then` 第二个参数只处理前一个 Promise 的 rejected。

**Q2：为什么 `.then` 的第二个参数接不住 `onFulfilled` 里 `throw` 的错误？**  
因为那个错误发生时，已经是在 `onFulfilled` 执行过程中，它会让当前 `.then(...)` 返回的新 Promise 变成 rejected，而不是回头交给同一次 `.then` 的第二个参数。

**Q3：那 `.then(onFulfilled, onRejected)` 还有用吗？**  
有，但更多是特殊场景下“只处理上游 reject”的精细控制；日常业务代码一般还是 `.catch(...)` 更清晰。

---

### 十一、一句话总结

`.then(onFulfilled, onRejected)` 只能处理“进入这一层之前”的 rejected；`.then(...).catch(...)` 能统一兜住前面整段链路中的错误，包括成功回调内部抛出的异常，所以工程上更推荐后者。

---
