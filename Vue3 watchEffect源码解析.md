# Vue 3 `watchEffect` 源码解析：跟着一次执行走完整条链路

> 本文以 Vue 3.5 系列实现为主线，并使用本地安装的 Vue 3.5.38 构建源码核对关键调用顺序。源码片段为了突出控制流做了删减，但关键分支、变量和调用关系与 Vue 3.5 保持一致。
>
> Vue 源码会继续演进。实际阅读时，应先确认项目安装的 Vue 版本，再对照同一 Tag 下的 `packages/runtime-core/src/apiWatch.ts`、`packages/reactivity/src/watch.ts`、`effect.ts`、`dep.ts` 和 `packages/runtime-core/src/scheduler.ts`。

---

## 一、不要先背概念，先跟住这个例子

本文只使用一个贯穿始终的例子：根据当前 `userId` 请求用户信息；依赖变化时，先中止旧请求，再发起新请求；功能关闭后，不再关心 `userId`。

```typescript
import { ref, watchEffect } from 'vue'

const enabled = ref(true)
const userId = ref('1')

const handle = watchEffect(onCleanup => {
  if (!enabled.value) return

  const controller = new AbortController()
  onCleanup(() => controller.abort())

  fetch(`/api/users/${userId.value}`, {
    signal: controller.signal,
  })
})
```

这个例子虽然不长，却包含了 `watchEffect` 最重要的源码问题：

- 为什么调用后会立即执行一次？
- Vue 怎么知道函数读取了 `enabled` 和 `userId`？
- 为什么修改 `userId` 不会直接在 setter 内粗暴重跑函数？
- 为什么重跑前要先执行 `controller.abort()`？
- `enabled` 变成 `false` 后，Vue 怎么取消对 `userId` 的订阅？
- 为什么异步函数中第一个 `await` 后读取的 ref 不会被自动跟踪？
- 组件卸载时，为什么同步创建的 watcher 会自动停止？

先看整条路线，后面再逐段进入源码：

```text
watchEffect(userEffect)
  ↓
runtime-core: doWatch(userEffect, null, options)
  ├─ 接入组件实例和错误处理
  └─ 生成 pre / post / sync scheduler
  ↓
reactivity: watch(source=userEffect, cb=null, options)
  ├─ 生成 effect 模式的 getter
  ├─ 生成 cleanup 绑定
  ├─ 生成 watcher job
  └─ new ReactiveEffect(getter)
  ↓
首次 job → ReactiveEffect.run()
  ├─ activeSub = 当前 effect
  ├─ 执行 getter → 执行用户函数
  ├─ enabled.value / userId.value → Dep.track()
  └─ Dep ↔ Link ↔ ReactiveEffect
  ↓
userId.value = '2'
  ↓
Dep.trigger() → batch → effect.scheduler() → queueJob(job)
  ↓
下一轮 job → effect.run()
  ├─ 先执行旧 cleanup
  ├─ 重新执行用户函数
  ├─ 保留本轮仍读取的依赖
  └─ 删除本轮不再读取的依赖
  ↓
handle.stop() 或组件 effect scope 销毁
  └─ 解除全部依赖并执行最后一次 cleanup
```

下面不再把“依赖收集”“调度”“清理”拆成互相独立的知识点，而是按这条时间线一步一步走。

---

## 二、创建阶段：从 `watchEffect()` 走到第一次执行

### 第 1 步：`watchEffect` 用 `cb = null` 表明自己是副作用模式

入口位于 `packages/runtime-core/src/apiWatch.ts`，简化后只有一层转发：

```typescript
export function watchEffect(
  effect: WatchEffect,
  options?: WatchEffectOptions,
): WatchHandle {
  return doWatch(effect, null, options)
}
```

调用我们例子中的 `watchEffect(userEffect)` 后，参数会变成：

```text
source = userEffect
cb = null
options = undefined
```

这里的 `null` 不是无关紧要的占位值。底层 `watch()` 正是通过有没有 `cb` 区分两套语义：

```text
watch(source, callback)
  source 负责读取依赖
  callback 负责在值变化后执行副作用

watchEffect(effect)
  source 本身就是副作用函数
  cb = null
  执行 source 的同时自动收集它读到的依赖
```

因此，`watchEffect` 不是另一套完全独立的响应式系统。它和 `watch` 共用底层 watcher，只是用 `cb = null` 选择“函数 source、没有 callback”的 effect 分支。

### 第 2 步：`doWatch` 先补齐组件层能力，再进入纯响应式层

`doWatch` 仍在 `runtime-core`。它不创建 `Dep`，也不负责真正的依赖收集；它先把组件运行时才有的能力放进 `baseWatchOptions`：

```typescript
function doWatch(source, cb, options = EMPTY_OBJ) {
  const { flush } = options
  const baseWatchOptions = extend({}, options)
  const instance = currentInstance

  baseWatchOptions.call = (fn, type, args) =>
    callWithAsyncErrorHandling(fn, instance, type, args)

  let isPre = false

  if (flush === 'post') {
    baseWatchOptions.scheduler = job => {
      queuePostRenderEffect(job, instance && instance.suspense)
    }
  } else if (flush !== 'sync') {
    isPre = true
    baseWatchOptions.scheduler = (job, isFirstRun) => {
      if (isFirstRun) job()
      else queueJob(job)
    }
  }

  baseWatchOptions.augmentJob = job => {
    if (cb) {
      job.flags |= SchedulerJobFlags.ALLOW_RECURSE
    }

    if (isPre) {
      job.flags |= SchedulerJobFlags.PRE
      if (instance) {
        job.id = instance.uid
        job.i = instance
      }
    }
  }

  return baseWatch(source, cb, baseWatchOptions)
}
```

这一段要按执行顺序理解。

首先，`baseWatchOptions.call` 把用户函数接入 `callWithAsyncErrorHandling`。我们的请求函数如果同步抛错，或返回的 Promise 被拒绝，错误就能进入 Vue 的组件错误处理链，例如 `errorCaptured` 和 `app.config.errorHandler`。纯 `@vue/reactivity` 并不知道组件实例，也不应该依赖组件错误处理，所以这层适配必须放在 `runtime-core`。

然后，`doWatch` 根据 `flush` 决定“将来谁来执行 job”。我们的例子没有传 `flush`，因此进入默认的 `pre` 分支：

```typescript
(job, isFirstRun) => {
  if (isFirstRun) job()
  else queueJob(job)
}
```

这两行直接解释了一个常见现象：

- 第一次执行：`isFirstRun = true`，直接调用 `job()`，所以普通 `watchEffect` 创建后立即运行。
- 后续执行：进入 `queueJob(job)`，与组件更新一起排队、排序和去重，而不是每次 setter 都同步重跑。

最后，`augmentJob` 给默认 watcher job 加上 `PRE` 标记，并在组件内创建时关联组件 `uid`。调度器可据此让同一组件的 pre watcher 在该组件渲染更新前执行，并维持父子组件任务的稳定顺序。

#### 为什么要分成 `runtime-core` 和 `reactivity` 两层

如果把组件实例、Suspense、DOM 更新队列全部塞进响应式包，那么脱离组件使用 `@vue/reactivity` 也会被迫携带运行时依赖。Vue 选择让两层各管一类问题：

| 层 | 在本次调用中负责什么 |
| --- | --- |
| `runtime-core` | 当前组件、错误处理、`pre/post/sync`、SSR/Suspense 调度边界 |
| `reactivity` | watcher 语义、`ReactiveEffect`、依赖关系、触发、清理、暂停和停止 |

这也是为什么只看 `watchEffect` 的三行入口，看不到它真正的实现。

#### `flush` 的三个分支就在这里产生

`flush` 不是 effect 收集依赖的方式，而是 effect 已经被触发后，job 何时执行：

| 配置 | 首次执行 | 后续执行 | 适用场景 |
| --- | --- | --- | --- |
| 默认 `pre` | 立即执行 | 所属组件 DOM 更新前进入队列 | 请求、订阅、同步外部状态 |
| `post` | 进入 post-render 队列 | 所属组件 DOM 更新后 | 读取更新后的 DOM 尺寸或状态 |
| `sync` | 立即执行 | setter 触发时同步执行 | 极少数必须同步的状态桥接 |

`flush: 'sync'` 看起来最“实时”，但它绕开普通任务队列的批处理。连续修改数组或多个字段时，副作用可能同步执行很多次，因此不应把它当成更高级的默认选项。

### 第 3 步：底层 `watch()` 组装 getter、cleanup、job 和 effect

接下来进入 `packages/reactivity/src/watch.ts`。此时 `source` 是用户函数，`cb` 是 `null`，所以命中 effect 模式：

```typescript
let effect: ReactiveEffect
let getter: () => unknown
let cleanup: (() => void) | undefined
let boundCleanup: (fn: () => void) => void

if (isFunction(source)) {
  if (cb) {
    // watch(() => state.value, callback) 的分支
    getter = () => source()
  } else {
    // watchEffect(effectFn) 的分支
    getter = () => {
      if (cleanup) {
        pauseTracking()
        try {
          cleanup()
        } finally {
          resetTracking()
        }
      }

      const previousWatcher = activeWatcher
      activeWatcher = effect

      try {
        return source(boundCleanup)
      } finally {
        activeWatcher = previousWatcher
      }
    }
  }
}
```

注意，这里没有立刻执行用户函数，而是先生成一个 `getter`。这个 getter 是每次 watcher 真正运行时的固定入口，它把一次重跑组织成三个动作：

```text
1. 有旧 cleanup → 先执行旧 cleanup
2. activeWatcher = 当前 effect
3. 执行 source(boundCleanup)，也就是用户传入的函数
```

这里同时出现了两个名字很像、职责却不同的全局上下文：

| 变量 | 解决的问题 |
| --- | --- |
| `activeWatcher` | `onWatcherCleanup()` 当前应该把清理函数登记给哪个 watcher |
| `activeSub` | ref/Proxy getter 当前应该把依赖登记给哪个响应式订阅者 |

`activeWatcher` 会在 getter 中设置；`activeSub` 要等后面的 `ReactiveEffect.run()` 才设置。二者不能混为一谈。

继续向下，底层创建 job 和 effect，并把 scheduler 与 cleanup 绑定到 effect：

```typescript
const job = (immediateFirstRun?: boolean) => {
  if (
    !(effect.flags & EffectFlags.ACTIVE) ||
    (!effect.dirty && !immediateFirstRun)
  ) {
    return
  }

  if (cb) {
    // watch 的新旧值比较与 callback 分支
  } else {
    effect.run()
  }
}

if (augmentJob) {
  augmentJob(job)
}

effect = new ReactiveEffect(getter)

effect.scheduler = scheduler
  ? () => scheduler(job, false)
  : job

boundCleanup = fn => onWatcherCleanup(fn, false, effect)

cleanup = effect.onStop = () => {
  const cleanups = cleanupMap.get(effect)
  if (!cleanups) return

  for (const cleanupFn of cleanups) {
    cleanupFn()
  }
  cleanupMap.delete(effect)
}
```

这段组装有四个关键点。

第一，job 不等于用户函数。job 是 watcher 的运行守门员：effect 已停止或依赖实际不脏时，它可以直接返回；通过检查后，`watchEffect` 才进入 `effect.run()`。

第二，`new ReactiveEffect(getter)` 包装的是前面生成的 getter，不是裸用户函数。这样每次依赖重跑时，都必然先经过 cleanup 和 `activeWatcher` 管理。

第三，`effect.scheduler` 不直接保存 job，而是保存“把 job 交给 runtime-core scheduler”的函数。响应式层只负责报告“这个 effect 该更新了”，组件层决定现在执行还是排队执行。

第四，传给用户的 `onCleanup` 实际是 `boundCleanup`。它已经闭包绑定当前 effect，因此：

```typescript
onCleanup(() => controller.abort())
```

本质上是在 `cleanupMap` 中把 `controller.abort()` 登记到当前 effect。下一次 getter 执行和 `effect.stop()` 都会调用同一套 cleanup。

虽然变量 `getter` 在 `effect` 赋值前就被创建，但此时只是创建闭包，并没有执行。等首次 job 真正调用 `effect.run()` 时，`effect`、`boundCleanup` 和 `cleanup` 都已经完成赋值，所以不会读到未初始化状态。

### 第 4 步：默认 scheduler 让首次 job 立即运行

底层 watcher 的初始化分支，简化后是：

```typescript
if (cb) {
  // watch 的 immediate / lazy 初始化
} else if (scheduler) {
  scheduler(job.bind(null, true), true)
} else {
  effect.run()
}
```

我们的例子存在 `doWatch` 注入的默认 scheduler，因此调用：

```text
scheduler(firstRunJob, true)
  ↓
isFirstRun 为 true
  ↓
直接执行 firstRunJob()
  ↓
job(immediateFirstRun = true)
  ↓
effect.run()
```

到这里，“`watchEffect` 为什么创建后立即执行”已经完整闭环：不是因为构造 `ReactiveEffect` 自动运行，而是底层初始化主动把首次 job 交给 scheduler，默认 `pre` scheduler 对第一次运行采用了直接调用。

---

## 三、首次执行：Vue 如何发现 `enabled` 和 `userId`

### 第 5 步：`ReactiveEffect.run()` 打开本轮依赖收集上下文

`effect.run()` 进入 `packages/reactivity/src/effect.ts`。简化后的主干如下：

```typescript
class ReactiveEffect<T = any> {
  deps?: Link
  depsTail?: Link
  flags = EffectFlags.ACTIVE | EffectFlags.TRACKING

  run(): T {
    if (!(this.flags & EffectFlags.ACTIVE)) {
      return this.fn()
    }

    this.flags |= EffectFlags.RUNNING
    cleanupEffect(this)
    prepareDeps(this)

    const previousSub = activeSub
    const previousTracking = shouldTrack

    activeSub = this
    shouldTrack = true

    try {
      return this.fn()
    } finally {
      cleanupDeps(this)
      activeSub = previousSub
      shouldTrack = previousTracking
      this.flags &= ~EffectFlags.RUNNING
    }
  }
}
```

此时 `this.fn` 就是上一步生成的 getter。

这里的 `cleanupEffect(this)` 容易和 `watchEffect` 的 `onCleanup` 混淆。它是 `ReactiveEffect` 自身的内部执行清理入口；用户通过 `onCleanup(() => controller.abort())` 注册的 watcher cleanup，不是在这一行执行，而是在下一步进入 watch getter 后执行，并同时绑定到 `effect.onStop`。后面分析第二次运行时会看到这个准确位置。

在继续看 `activeSub = this` 之前，先明确这里同时存在的三个东西：

```typescript
// 1. 用户编写的副作用函数
const userEffect = onCleanup => {
  console.log(userId.value)
}

// 2. Vue 创建的订阅者对象
const effect = new ReactiveEffect(getter)

// 3. 响应式模块内部的全局执行上下文
let activeSub: Subscriber | undefined
```

它们不是三个 effect：

| 名称 | 它是什么 | 负责什么 |
| --- | --- | --- |
| `userEffect` | 用户函数 | 描述要执行的业务副作用 |
| `effect` | `ReactiveEffect` 实例 | 运行 getter、保存依赖、接受触发、调度和停止 |
| `activeSub` | 全局变量 | 临时指向当前正在运行并收集依赖的订阅者 |

因此 `activeSub` 和 `ReactiveEffect` 的关系不是继承、包含或复制，而是最普通的对象引用：

```typescript
activeSub = effect
```

在当前 `effect.run()` 中，`this` 就是这个 `effect` 实例，所以源码写成：

```typescript
activeSub = this
shouldTrack = true
```

执行用户函数期间可以认为：

```typescript
activeSub === effect // true
```

对应关系是：

```text
activeSub
    │
    └── 临时指向 ──→ 当前 ReactiveEffect 实例
```

`ReactiveEffect` 是实际存在、会长期保存依赖的对象；`activeSub` 只是执行期间使用的“当前订阅者指针”。当前函数执行结束后，`activeSub` 会恢复成之前的值，但 `ReactiveEffect` 实例和它已经收集到的依赖仍然存在。

#### 为什么 ref getter 需要这个全局指针

当后面的用户函数读取 `userId.value` 时，ref getter 只知道“我的 value 被读取了”，却不知道：

```text
是谁读取了我？
我应该把哪个 effect 登记为订阅者？
```

`Dep.track()` 会读取 `activeSub` 来得到答案：

```typescript
class Dep {
  track() {
    if (!activeSub || !shouldTrack) return

    // 此刻 activeSub 就是当前 watchEffect 的 ReactiveEffect
    const link = new Link(activeSub, this)
  }
}
```

在这个调用位置：

```text
activeSub          = 当前 watchEffect 的 ReactiveEffect
Dep.track() 的 this = userId 对应的 Dep
```

于是 Vue 可以建立：

```text
userId.dep
    │
    └── Link ──→ activeSub
                    │
                    └── 当前 ReactiveEffect
```

为什么不把 effect 作为参数一路传给每个 ref getter？因为用户代码可能经过任意层普通函数：

```typescript
watchEffect(() => loadUser())

function loadUser() {
  return createUrl()
}

function createUrl() {
  return `/api/users/${userId.value}`
}
```

如果没有 `activeSub`，就只能把 effect 人工传过每一层业务函数，最终再传给 `userId.value`，这显然不可能成为正常的 JavaScript 使用方式。Vue 在 `run()` 开头设置全局执行上下文后，任意调用深度的 ref 或 Proxy getter 都能在真实读取发生时找到当前订阅者。

#### 为什么叫 `activeSub`，而不是 `activeEffect`

`Sub` 是 `Subscriber`，即“订阅者”。`ReactiveEffect` 是一种订阅者，但 Vue 3.5 中能够收集依赖的不只有它：

```text
Subscriber
├── ReactiveEffect
│   ├── watchEffect 的 effect
│   ├── watch 的 effect
│   └── 组件渲染 effect
└── ComputedRefImpl
```

执行普通 effect 时：

```typescript
activeSub = reactiveEffect
```

计算属性重新求值时，当前订阅者也可能是 `ComputedRefImpl`：

```typescript
activeSub = computedRef
```

所以 Vue 3.5 使用更宽泛的名字 `activeSub`。在本文当前这次 `watchEffect` 执行中，它具体指向的就是 `ReactiveEffect`。

最后，源码为什么要先保存 `previousSub`，结束后再恢复？这是为了支持订阅者嵌套：内层 effect 或 computed 临时成为 `activeSub`，内层执行完以后，外层 effect 还要继续收集后续读取的依赖。

### 第 6 步：getter 进入用户函数，并注册本轮 cleanup

`run()` 调用 getter。首次执行还没有旧 cleanup，所以跳过清理，然后：

```typescript
activeWatcher = effect
return source(boundCleanup)
```

现在真正进入我们的用户函数：

```typescript
onCleanup => {
  if (!enabled.value) return

  const controller = new AbortController()
  onCleanup(() => controller.abort())

  fetch(`/api/users/${userId.value}`, {
    signal: controller.signal,
  })
}
```

初始 `enabled.value` 为 `true`，因此会继续执行。创建 `AbortController` 本身与响应式无关；随后调用 `onCleanup()`，把当前 controller 的中止函数保存到这个 effect 的 cleanup 列表。

为什么 cleanup 要归属于“本轮 effect”，而不是写成一个组件卸载回调？因为它首先解决的是两轮副作用之间的失效问题：`userId=1` 的请求还没结束时，`userId` 已变成 `2`，旧请求应该在新请求开始前立即失效，而不是等组件卸载。

### 第 7 步：读取 `ref.value`，通过 `Dep` 和 `Link` 建立双向关系

第一次读 `enabled.value` 时，会进入 ref 的 getter：

```typescript
class RefImpl<T> {
  dep: Dep = new Dep()

  get value() {
    this.dep.track()
    return this._value
  }
}
```

之后构造 URL 时又读取 `userId.value`，会进入另一个 ref 自己的 `dep.track()`。

如果读取的不是 ref，而是 `reactive` 对象属性，入口会换成 Proxy getter：

```typescript
get(target, key, receiver) {
  const result = Reflect.get(target, key, receiver)
  track(target, TrackOpTypes.GET, key)
  return result
}
```

`track(target, key)` 会先从 `targetMap` 找到这个对象和 key 对应的 `Dep`，最后同样调用 `dep.track()`。所以 ref 与 reactive 的入口不同，但最终都会汇合到 `Dep`。

Vue 3.5 的 `Dep.track()` 主干可以理解为：

```typescript
class Link {
  version: number

  constructor(
    public sub: ReactiveEffect,
    public dep: Dep,
  ) {
    this.version = dep.version
  }

  // 还包含 nextDep / prevDep / nextSub / prevSub 等指针
}

class Dep {
  version = 0
  activeLink?: Link
  subs?: Link

  track() {
    if (!activeSub || !shouldTrack) return

    let link = this.activeLink

    if (!link || link.sub !== activeSub) {
      link = this.activeLink = new Link(activeSub, this)
      appendToEffectDeps(activeSub, link)
      addSub(link)
    } else if (link.version === -1) {
      link.version = this.version
      moveToEffectDepsTailIfNeeded(activeSub, link)
    }

    return link
  }
}
```

#### 为什么不用一个 `Set` 保存依赖

先只考虑“数据变化后通知 effect”。可以给每个 Dep 放一个 Set：

```typescript
class Dep {
  subscribers = new Set<ReactiveEffect>()
}
```

首次读取 `userId.value` 时登记 effect：

```typescript
userId.dep.subscribers.add(effect)
```

修改 `userId` 时遍历 Set：

```typescript
for (const effect of userId.dep.subscribers) {
  effect.trigger()
}
```

从这个方向看，一个 Set 已经可以工作：

```text
userId.dep
    ↓ subscribers
ReactiveEffect
```

问题出现在反方向。执行 `handle.stop()` 时，当前 effect 必须从自己订阅过的所有 Dep 中退出：

```typescript
enabled.dep.subscribers.delete(effect)
userId.dep.subscribers.delete(effect)
```

如果只有 `dep.subscribers`，effect 自己并不知道它被放进了哪些 Dep 的 Set。Vue也不可能在停止一个 watcher 时，扫描应用内所有响应式对象和所有 Dep：

```typescript
// 这既低效，也没有一个适合遍历“全部 Dep”的稳定全局列表
for (const dep of 应用中的全部Dep) {
  dep.subscribers.delete(effect)
}
```

所以同一条关系需要支持两个查询方向：

```text
数据变化：Dep → 找到订阅它的 effect
重跑/停止：effect → 找到自己订阅的 Dep
```

使用两个 Set 其实可以实现：

```typescript
class Dep {
  subscribers = new Set<ReactiveEffect>()
}

class ReactiveEffect {
  deps = new Set<Dep>()
}
```

收集时同时写两边：

```typescript
dep.subscribers.add(effect)
effect.deps.add(dep)
```

删除时也同时维护两边：

```typescript
dep.subscribers.delete(effect)
effect.deps.delete(dep)
```

所以准确结论不是“Set 做不到”，而是：

> 一个单向 Set 不够；两个 Set 可以完成双向查询，但同一条依赖关系的两端和本轮状态会分散存放。

Vue 3.5 选择创建一个独立的 `Link` 对象，明确表示“某个 Dep 和某个订阅者之间的这一条关系”：

```typescript
class Link {
  constructor(
    public sub: Subscriber,
    public dep: Dep,
  ) {}

  version: number
  prevSub?: Link
  nextSub?: Link
  prevDep?: Link
  nextDep?: Link
}
```

一条 Link 同时挂入两条链：

```text
从 Dep 方向看：

userId.dep
    ↓ subscribers
userIdLink
    ↓ sub
ReactiveEffect


从 effect 方向看：

ReactiveEffect
    ↓ deps
enabledLink → userIdLink
    ↓             ↓
enabled.dep    userId.dep
```

对应到我们的例子：

```text
enabled.dep                    当前 ReactiveEffect
    │                                  │
    └──── subscribers ── Link ── deps ─┘

userId.dep                     当前 ReactiveEffect
    │                                  │
    └──── subscribers ── Link ── deps ─┘
```

因此两类操作都能从自己已有的链表开始，不需要全局扫描：

```text
userId 变化
  → userId.dep 遍历 subscriber Link
  → link.sub 找到 ReactiveEffect

effect 停止
  → effect 遍历 dependency Link
  → link.dep 找到 enabled.dep 和 userId.dep
  → 分别解除订阅
```

Link 还集中保存 `version`。effect 每次重跑前把旧 Link 标为 `-1`，本轮重新读取的依赖会刷新相应 Link 的版本，执行结束后仍为 `-1` 的 Link 就是条件分支中已经失效的依赖。后面的第 11～14 步会沿实际重跑过程完整展示这部分。

首次运行时，`enabled.dep.track()` 创建 `enabledLink`，`userId.dep.track()` 创建 `userIdLink`。执行到 `fetch()` 时，本轮关系已经是：

```text
effect.deps: enabledLink → userIdLink

enabled.dep.subs: enabledLink
userId.dep.subs: userIdLink
```

Vue 并没有解析用户函数文本，也没有扫描变量名。只有本轮控制流真正执行到的 `ref.value` 或 Proxy 属性读取，才会进入 `track()`。

### 第 8 步：首次执行结束，恢复全局上下文

用户函数同步返回后，getter 先在自己的 `finally` 中恢复 `activeWatcher`；随后 `ReactiveEffect.run()` 进入 `finally`：

```typescript
finally {
  cleanupDeps(this)
  activeSub = previousSub
  shouldTrack = previousTracking
  this.flags &= ~EffectFlags.RUNNING
}
```

首次运行没有历史依赖需要删除，所以两条 Link 都会保留。最终状态是：

```text
已发起 /api/users/1
已登记 cleanup: controller-1.abort
当前 effect 订阅 enabled.dep
当前 effect 订阅 userId.dep
activeWatcher 已恢复
activeSub 已恢复
```

#### `await` 后不再自动收集依赖，边界就发生在这里

把用户函数改成异步版本：

```typescript
watchEffect(async onCleanup => {
  const id = userId.value       // 会被跟踪
  const response = await fetch(`/api/users/${id}`)
  console.log(theme.value)      // 不会被本轮 watchEffect 自动跟踪
})
```

JavaScript 调用 async 函数时，只会同步执行到第一个 `await`，然后立即返回 Promise。于是源码时序是：

```text
effect.run()
  ↓ activeSub = 当前 effect
执行 async 用户函数
  ↓ 读取 userId.value，成功 track
执行到第一个 await
  ↓ async 函数返回 Promise
getter 的 finally 恢复 activeWatcher
run() 的 finally 恢复 activeSub 和 shouldTrack
  ↓
网络请求完成，Promise continuation 继续
  ↓ 读取 theme.value
此时 activeSub 已不是当前 effect，因此不会登记给它
```

这不是 Vue 特意检测了 `await`，而是 `ReactiveEffect.run()` 只能维持当前这段同步调用栈的全局追踪上下文。异步 continuation 发生时，原来的 `run()` 早已结束。

因此异步副作用应在第一个 `await` 前同步读取依赖并保存快照：

```typescript
watchEffect(async onCleanup => {
  const id = userId.value
  const controller = new AbortController()
  onCleanup(() => controller.abort())

  const response = await fetch(`/api/users/${id}`, {
    signal: controller.signal,
  })

  // 后续使用本轮 id 快照
  data.value = await response.json()
})
```

Vue 3.5 还提供 `onWatcherCleanup()`。它依赖同步期间的 `activeWatcher`，必须在 `await` 前调用；参数形式的 `onCleanup` 已经显式绑定 effect，不依赖调用时仍存在 `activeWatcher`，但业务上仍建议尽早注册，避免异步间隙中没有清理函数可用。

---

## 四、更新阶段：`userId` 变化后怎样完成清理和重跑

### 第 9 步：ref setter 只负责报告变化，不直接调用用户函数

现在执行：

```typescript
userId.value = '2'
```

ref setter 比较新旧值，确认真正变化后调用自己的 Dep：

```typescript
set value(newValue) {
  const oldValue = this._rawValue

  if (hasChanged(newValue, oldValue)) {
    this._rawValue = newValue
    this._value = toReactive(newValue)
    this.dep.trigger()
  }
}
```

`Dep.trigger()` 更新版本号并通知订阅者：

```typescript
class Dep {
  version = 0

  trigger() {
    this.version++
    globalVersion++
    this.notify()
  }

  notify() {
    startBatch()
    try {
      for (let link = this.subs; link; link = link.prevSub) {
        link.sub.notify()
      }
    } finally {
      endBatch()
    }
  }
}
```

调用链此时是：

```text
userId setter
  → userId.dep.trigger()
  → userId.dep.notify()
  → 找到 userIdLink
  → userIdLink.sub 就是当前 ReactiveEffect
  → effect.notify()
```

`startBatch/endBatch` 的作用，是在一轮依赖通知尚未完成时先收集 effect，避免遍历订阅者链的过程中立刻重入并破坏当前通知过程。通知结束后，批量 effect 才进入各自的 `trigger()`。

### 第 10 步：effect 把 job 交给默认 scheduler，`queueJob` 再做任务去重

`ReactiveEffect.trigger()` 的核心分支如下：

```typescript
trigger() {
  if (this.flags & EffectFlags.PAUSED) {
    pausedQueueEffects.add(this)
  } else if (this.scheduler) {
    this.scheduler()
  } else {
    this.runIfDirty()
  }
}
```

我们的 watcher 已经有 scheduler，所以不会在这里直接 `run()`：

```text
effect.trigger()
  → effect.scheduler()
  → runtime-core scheduler(job, false)
  → queueJob(job)
```

`queueJob` 会检查 job 是否已经在队列中，再按 job id 和 `PRE` 标记插入合适位置，并安排一次微任务刷新队列。于是：

```typescript
userId.value = '2'
userId.value = '3'
userId.value = '4'
```

虽然发生了三次 setter 和三次通知，但同一个 watcher job 在队列中会被去重，通常只在本轮微任务里执行一次，读取最终的 `'4'`。

这里存在两层不同的“批处理”，不要混在一起：

| 层 | 解决的问题 |
| --- | --- |
| reactivity 的 `startBatch/endBatch` | 安全完成一轮 Dep → subscriber 通知，再触发 effect |
| runtime-core 的 `queueJob` | 多次同步状态修改时，对同一个 watcher job 排队、去重和排序 |

这也是默认 `pre` 比 `sync` 更适合作为业务默认值的原因。`sync` 模式没有普通 `queueJob` 这一层，连续 setter 会更频繁地重跑副作用。

### 第 11 步：第二次 `run()` 先把旧依赖标成待确认

微任务开始刷新队列后，job 再次调用 `effect.run()`。在进入 getter 前，`prepareDeps(this)` 会处理上一轮留下的依赖：

```typescript
function prepareDeps(sub: Subscriber) {
  for (let link = sub.deps; link; link = link.nextDep) {
    link.version = -1
    link.prevActiveLink = link.dep.activeLink
    link.dep.activeLink = link
  }
}
```

上一轮有 `enabledLink` 和 `userIdLink`。它们的版本会先被统一设为 `-1`：

```text
effect.deps
  enabledLink(version = -1)
  userIdLink(version = -1)
```

`-1` 可以理解为“这是旧依赖，本轮还没有重新确认”。Vue没有在重跑前立刻删除全部 Link，因为大多数 effect 重跑后仍会读取相同依赖；保留并复用 Link，能避免每轮都销毁、重建同样的双向关系。

### 第 12 步：getter 先执行上一次 cleanup，并暂停依赖追踪

`run()` 接着调用 getter。现在 `cleanup` 已存在，所以第一件事不是执行新请求，而是清理上一轮：

```typescript
if (cleanup) {
  pauseTracking()
  try {
    cleanup() // controller-1.abort()
  } finally {
    resetTracking()
  }
}
```

完整顺序是：

```text
旧请求 /api/users/1 仍可能进行中
  ↓
第二轮 getter 开始
  ↓
controller-1.abort()
  ↓
再执行用户函数，准备 /api/users/2
```

为什么必须“先 cleanup，后执行新一轮”？如果先发新请求再中止旧请求，旧请求可能在这个间隙完成并覆盖新状态。cleanup 被放在 getter 最前面，就是要让上一轮资源在下一轮副作用建立之前先失效。

为什么 cleanup 外面要 `pauseTracking()`？考虑清理函数读取了一个调试状态：

```typescript
onCleanup(() => {
  console.log(debugState.value)
  controller.abort()
})
```

`debugState` 只是清理过程读取的数据，不是用户副作用的新业务依赖。如果此时仍正常 track，清理代码读了什么，watcher 就会意外订阅什么。暂停追踪后，cleanup 可以运行，但其中的响应式读取不会登记到当前 effect。

`finally` 中的 `resetTracking()` 也很重要：即使 cleanup 抛错，Vue 也必须恢复之前的追踪状态，不能让整个应用后续的依赖收集都保持关闭。

### 第 13 步：重新读取依赖，复用仍有效的 Link

cleanup 完成后，用户函数再次执行：

```typescript
if (!enabled.value) return

const controller = new AbortController()
onCleanup(() => controller.abort())

fetch(`/api/users/${userId.value}`, {
  signal: controller.signal,
})
```

此时 `enabled` 仍为 `true`，所以会再次读取 `enabled.value` 和新的 `userId.value`。

`Dep.track()` 发现 Link 已经存在且 `version === -1`，不会新建重复 Link，而是把它刷新为当前 Dep 版本：

```typescript
if (link.version === -1) {
  link.version = this.version
  moveToEffectDepsTailIfNeeded(activeSub, link)
}
```

于是本轮结束前：

```text
enabledLink: -1 → enabled.dep.version
userIdLink:  -1 → userId.dep.version
```

两个 Link 都被重新确认，`cleanupDeps()` 不会删除它们。新请求 `/api/users/2` 发出，同时登记新的 `controller-2.abort()`。

### 第 14 步：条件分支变化时，`cleanupDeps()` 删除本轮未访问的依赖

接着执行：

```typescript
enabled.value = false
```

这次仍然经过 trigger、batch、scheduler 和 queueJob。新一轮开始时，两条旧 Link 又被标成 `-1`；cleanup 先中止 controller-2；然后用户函数只执行到这里：

```typescript
if (!enabled.value) return
```

本轮读取了 `enabled.value`，所以 `enabledLink` 被刷新。由于条件提前返回，`userId.value` 根本没有被读取，`userIdLink` 仍保持 `-1`。

`run()` 离开前调用 `cleanupDeps(this)`，主干逻辑是：

```typescript
function cleanupDeps(sub: Subscriber) {
  let link = sub.depsTail

  while (link) {
    const prev = link.prevDep

    if (link.version === -1) {
      removeSub(link) // 从 Dep 的订阅者链移除
      removeDep(link) // 从 effect 的依赖链移除
    }

    link.dep.activeLink = link.prevActiveLink
    link.prevActiveLink = undefined
    link = prev
  }
}
```

这一轮的状态变化可以直接列成表：

| Link | 重跑前 | 用户函数本轮是否读取 | 重跑后 |
| --- | --- | --- | --- |
| `enabledLink` | 标记为 `-1` | 是 | 刷新版本，保留 |
| `userIdLink` | 标记为 `-1` | 否 | 仍为 `-1`，从两边链表删除 |

最终关系变成：

```text
effect.deps: enabledLink

enabled.dep.subs: enabledLink
userId.dep.subs: 不再包含当前 effect
```

现在再执行：

```typescript
userId.value = '3'
```

这个 watcher 不会被触发，因为它已经不是 `userId.dep` 的订阅者。只有以后 `enabled` 重新变成 `true`，新一轮执行再次走到 `userId.value`，Vue 才会重新创建相应 Link。

这就是“动态依赖”的完整源码机制：

```text
prepareDeps：旧 Link 全部先标记为待确认
        ↓
执行用户函数：真正读到的 Dep 刷新 Link 版本
        ↓
cleanupDeps：仍未刷新的 Link 就是失效依赖，双向删除
```

`watchEffect` 跟踪的不是“函数历史上读过哪些变量”，而是“最近一次同步执行实际走到哪些响应式读取”。

---

## 五、结束阶段：停止、暂停、恢复和组件卸载

### 第 15 步：`stop()` 同时解除订阅并做最后一次清理

`watchEffect` 返回的 handle 可以直接调用，也可以显式调用 `stop()`：

```typescript
handle()
// 或
handle.stop()
```

底层都进入 `ReactiveEffect.stop()`：

```typescript
stop() {
  if (this.flags & EffectFlags.ACTIVE) {
    for (let link = this.deps; link; link = link.nextDep) {
      removeSub(link)
    }

    this.deps = this.depsTail = undefined
    cleanupEffect(this)
    this.onStop?.()
    this.flags &= ~EffectFlags.ACTIVE
  }
}
```

在我们的例子中，`effect.onStop` 就是底层 watcher 前面绑定的 cleanup。因此停止不是简单设置一个布尔值，而是完成三件事：

```text
1. 从仍订阅的所有 Dep 中移除 Link
2. 执行最后一轮登记的 cleanup
3. 清除 ACTIVE，后续 trigger 不再运行这个 watcher
```

cleanup 因而有两个执行时机，而且目的不同：

| 时机 | 目的 |
| --- | --- |
| 下一次 effect 执行前 | 让上一轮请求、订阅、定时器等先失效 |
| watcher 停止时 | 释放最后一轮仍存活的资源 |

### 第 16 步：`pause()` 暂存触发，`resume()` 恢复后再处理

Vue 3.5 的 handle 还提供暂停和恢复：

```typescript
handle.pause()
userId.value = '4'
handle.resume()
```

暂停后，effect 仍保留与 Dep 的 Link，只是 `trigger()` 不立即交给 scheduler：

```typescript
if (this.flags & EffectFlags.PAUSED) {
  pausedQueueEffects.add(this)
}
```

恢复时，如果暂停期间被触发过，effect 会重新进入正常触发链。它与 `stop()` 的区别是：

- `pause()` 保留依赖关系，之后可以继续；
- `stop()` 删除依赖关系并完成最终清理，不能再作为原 watcher 恢复。

### 第 17 步：组件卸载通过 effect scope 自动停止同步创建的 watcher

如果 `watchEffect` 在组件 `setup()` 的同步执行阶段创建，`new ReactiveEffect(getter)` 时存在当前组件的 active effect scope，effect 会被记录进这个 scope：

```text
组件 setup() 开始
  ↓ 当前组件 effect scope 激活
watchEffect()
  ↓ new ReactiveEffect(getter)
effect 被记录到组件 scope
  ↓
组件卸载
  ↓ scope.stop()
  ↓ effect.stop()
  ↓ 删除依赖 + 执行最后 cleanup
```

这就是“组件内创建的 watcher 会随组件卸载自动停止”的真正前提：创建时必须仍处于组件同步 scope。

下面这种异步延迟创建已经离开原来的同步调用栈，不能理所当然地认为它仍属于组件 scope：

```typescript
setTimeout(() => {
  const lateHandle = watchEffect(() => {
    // 这个 watcher 可能需要手动 lateHandle.stop()
  })
}, 1000)
```

实际业务更适合同步创建 watcher，再用条件控制其是否工作：

```typescript
const ready = ref(false)

watchEffect(() => {
  if (!ready.value) return
  // ready 后执行，但 watcher 从一开始就属于组件 scope
})
```

---

## 六、把整条链路压缩成一次完整时间线

回到文章开头的例子，所有源码环节可以合并成下面这条时间线。

### 1. 创建

```text
watchEffect(userEffect)
  → doWatch(userEffect, null)
  → 注入错误处理和默认 pre scheduler
  → baseWatch(userEffect, null, options)
  → 创建 effect 模式 getter
  → 创建 watcher job
  → new ReactiveEffect(getter)
  → 绑定 scheduler、boundCleanup、onStop
```

### 2. 首次运行

```text
默认 scheduler(job, isFirstRun=true)
  → job() 立即执行
  → effect.run()
  → prepareDeps()：首次没有旧依赖
  → activeSub = 当前 effect
  → getter()
  → activeWatcher = 当前 effect
  → userEffect(boundCleanup)
  → 读取 enabled.value
      → enabled.dep.track()
      → 创建 enabledLink
  → 注册 controller-1.abort cleanup
  → 读取 userId.value
      → userId.dep.track()
      → 创建 userIdLink
  → 发起 /api/users/1
  → 恢复 activeWatcher、activeSub、shouldTrack
```

### 3. `userId` 变更

```text
userId.value = '2'
  → userId.dep.trigger()
  → Dep.notify() 批量通知订阅者
  → effect.trigger()
  → effect.scheduler()
  → queueJob(job)
  → 微任务刷新队列
  → job()
  → effect.run()
  → prepareDeps()：两条旧 Link 标记为 -1
  → getter()
      → pauseTracking()
      → controller-1.abort()
      → resetTracking()
      → 再次执行 userEffect
  → enabledLink 与 userIdLink 都被本轮读取刷新
  → 发起 /api/users/2，登记 controller-2.abort
  → cleanupDeps()：两条 Link 都保留
```

### 4. `enabled` 关闭

```text
enabled.value = false
  → trigger → batch → scheduler → queueJob
  → 下一轮 effect.run()
  → 两条旧 Link 先标记为 -1
  → controller-2.abort()
  → 用户函数只读取 enabled.value，然后 return
  → enabledLink 被刷新
  → userIdLink 保持 -1
  → cleanupDeps() 双向删除 userIdLink
```

### 5. 停止

```text
handle.stop() 或组件 scope.stop()
  → effect.stop()
  → 从 enabled.dep 移除最后一条 Link
  → 执行仍登记的最后 cleanup
  → effect 变为 inactive
```

从这条时间线可以看到，`watchEffect` 的核心并不是某一个神秘函数，而是五个模块共同完成的闭环：

```text
apiWatch.ts       决定组件语义和调度时机
watch.ts          组织每一轮 watcher 的 getter、job 与 cleanup
effect.ts         管理当前订阅者、运行状态、触发与停止
dep.ts            用 Link 维护数据和 effect 的双向依赖
scheduler.ts      对后续 job 排队、去重并维持组件更新顺序
```

---

## 七、理解源码后，怎样选择 `watchEffect`、`watch` 和 `computed`

源码已经说明了三者不同的职责：

| API | 依赖怎样确定 | 执行特点 | 适合场景 |
| --- | --- | --- | --- |
| `watchEffect` | 用户函数同步执行时实际读取 | 默认立即执行，没有新旧值 | 一个副作用自然使用多个响应式依赖 |
| `watch` | 显式 source | 默认懒执行，可获得新旧值 | 依赖需要精确表达、比较前后值 |
| `computed` | getter 执行时自动收集 | 惰性求值并缓存 | 纯派生数据，不做外部副作用 |

如果依赖必须明确，尤其是异步请求只应由某个 id 驱动，`watch` 往往更容易维护：

```typescript
watch(userId, async (id, _oldId, onCleanup) => {
  const controller = new AbortController()
  onCleanup(() => controller.abort())

  const response = await fetch(`/api/users/${id}`, {
    signal: controller.signal,
  })
})
```

如果需求是“根据已有状态计算另一个值”，应使用 `computed`，而不是让 `watchEffect` 回写一个 ref：

```typescript
const doubled = computed(() => count.value * 2)
```

---

## 八、面试时如何完整回答

可以沿着真实控制流回答，而不是只背“自动收集依赖”：

> `watchEffect` 在 `runtime-core` 中调用 `doWatch(effect, null, options)`，`cb=null` 让底层进入副作用模式。`doWatch` 负责接入组件错误处理，并生成 `pre/post/sync` scheduler；底层 `reactivity/watch.ts` 再把用户函数包装成带 cleanup 的 getter，创建 watcher job 和 `ReactiveEffect`。默认 pre scheduler 会让第一次 job 立即运行。`ReactiveEffect.run()` 执行前把自己设为 `activeSub` 并开启 tracking，用户函数同步读取 ref 或 reactive 属性时，getter 进入 `Dep.track()`，通过 `Link` 建立 Dep 与 effect 的双向关系。依赖修改后，`Dep.trigger()` 批量通知 effect，再由 scheduler 把 job 放入组件更新队列。重跑前先执行上一轮 cleanup；旧 Link 会先标为待确认，本轮重新读取的 Link 被刷新，没再读取的 Link 在 `cleanupDeps()` 中双向删除。停止或组件 effect scope 销毁时，effect 会解除全部依赖并执行最后一次 cleanup。异步函数只会自动跟踪第一个 `await` 前的同步读取，因为 `run()` 返回后已经恢复了 `activeSub`。

如果继续追问“为什么不用一个 Set 保存依赖”，可以回答：

> 因为触发时要从 Dep 找到 effect，重跑或停止时又要从 effect 找回全部 Dep，所以 Vue 3.5 用 Link 同时挂入 Dep 的订阅者链和 effect 的依赖链；Link 的版本还用于在每轮执行后识别条件分支中已经失效的依赖。

---

## 九、源码阅读顺序

建议严格沿本文控制流阅读，不要一开始就在多个文件之间跳跃：

1. [`packages/runtime-core/src/apiWatch.ts`](https://github.com/vuejs/core/blob/main/packages/runtime-core/src/apiWatch.ts)
   - `watchEffect`
   - `doWatch`
2. [`packages/reactivity/src/watch.ts`](https://github.com/vuejs/core/blob/main/packages/reactivity/src/watch.ts)
   - `watch`
   - effect 模式 getter
   - `job`
   - cleanup 绑定
3. [`packages/reactivity/src/effect.ts`](https://github.com/vuejs/core/blob/main/packages/reactivity/src/effect.ts)
   - `ReactiveEffect.run()`
   - `trigger()`、`stop()`、`pause()`、`resume()`
   - `prepareDeps()`、`cleanupDeps()`
4. [`packages/reactivity/src/dep.ts`](https://github.com/vuejs/core/blob/main/packages/reactivity/src/dep.ts)
   - `Dep`
   - `Link`
   - `track()`、`trigger()`、`notify()`
5. [`packages/runtime-core/src/scheduler.ts`](https://github.com/vuejs/core/blob/main/packages/runtime-core/src/scheduler.ts)
   - `queueJob()`
   - pre/post 队列
   - job 去重与排序

每读一个函数，都回到贯穿示例中确认三个问题：

```text
此时是谁在调用它？
它修改了哪个运行时状态？
下一个函数为什么必须由它来调用？
```

这样读完得到的不是互相割裂的源码片段，而是一条可以从用户 API 一直追到 Dep、scheduler 和组件销毁的完整执行链。

---

## 十、一句话总结

> `watchEffect` 是一条完整的响应式副作用流水线：`runtime-core` 赋予它组件调度语义，`watch.ts` 组织每轮执行与清理，`ReactiveEffect.run()` 建立同步追踪上下文，`Dep + Link` 记录本轮真实依赖，数据变化后再经过批处理和 scheduler 重跑；每轮未再次读取的依赖会被移除，旧副作用会先失效，最终随手动停止或组件 scope 一起释放。
