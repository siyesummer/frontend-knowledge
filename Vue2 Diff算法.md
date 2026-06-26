# Vue 2 Diff 算法详解

> Vue 2 的虚拟 DOM diff 基于 **Snabbdom** 改造，采用**同层比较 + 双端比较 + key 索引**的策略。
> 整体设计目标：避免 O(n³) 的传统树 diff，在保留**可读性**和**通用性**的前提下做到 O(n)。

---

## 一、设计前提与时间复杂度

### 1. 传统树 diff 为什么是 O(n³)

经典树编辑距离（Tree Edit Distance）算法需要枚举两棵树的所有节点对应关系，时间复杂度是 **O(n³)** —— 在 1000 节点的视图上意味着十亿级操作，不可接受。

### 2. Vue 的两个核心简化假设

| 假设 | 含义 | 价值 |
|------|------|------|
| **同层比较（Same-level）** | 只比较同一层级的节点，不跨层级 | 把 O(n³) 降到 O(n) |
| **同类型才复用** | 标签名变了直接销毁重建，不做内部 diff | 避免无意义的深度比较 |

这两条假设来自前端的实际场景：**框架使用者很少跨层级移动节点**——他们通常是增删/排序兄弟节点。所以放弃跨层级复用换来巨大性能收益是合理的。

---

## 二、整体入口：`patch(oldVnode, newVnode)`

```javascript
// src/core/vdom/patch.js
function patch(oldVnode, vnode, hydrating, removeOnly) {
  if (!vnode) {
    // 新节点不存在 → 卸载旧节点
    if (oldVnode) invokeDestroyHook(oldVnode)
    return
  }

  if (!oldVnode) {
    // 旧节点不存在 → 首次挂载（创建真实 DOM）
    createElm(vnode, ...)
  } else {
    const isRealElement = isDef(oldVnode.nodeType)
    if (!isRealElement && sameVnode(oldVnode, vnode)) {
      // ★ 关键路径：新旧节点是"同一个节点" → 走 patchVnode 做更新
      patchVnode(oldVnode, vnode, ...)
    } else {
      // 完全不同 → 销毁旧的、创建新的
      const parentElm = nodeOps.parentNode(oldVnode.elm)
      createElm(vnode, ..., parentElm, ...)
      if (oldVnode.parent) /* 更新占位 vnode */
      if (parentElm) removeVnodes([oldVnode], 0, 0)
    }
  }
}
```

### `sameVnode` 判定：什么算"同一个节点"

```javascript
function sameVnode(a, b) {
  return (
    a.key === b.key &&                    // ★ key 必须相同
    a.asyncFactory === b.asyncFactory && (
      (
        a.tag === b.tag &&                // 同标签名
        a.isComment === b.isComment &&    // 注释节点状态一致
        isDef(a.data) === isDef(b.data) &&// data 存在性一致
        sameInputType(a, b)               // 输入框 type 一致
      ) || (
        isTrue(a.isAsyncPlaceholder) &&
        a.asyncFactory.error
      )
    )
  )
}
```

**核心**：`key` 和 `tag` 都一样才认为是同一节点，可以走 `patchVnode` 增量更新。任何一个不同 → 视为完全不同的节点，销毁旧的重建新的。

### 关于 VNode 上的 `data` 字段

`sameVnode` 里 `isDef(a.data) === isDef(b.data)` 中的 `data` 指 **Vue 2 VNode 实例上的 `data` 属性**——承载了模板编译后这个节点的所有"附加信息"。你可以理解为**"这个虚拟 DOM 节点除了 tag 和 children 之外的一切配置"**。

#### VNode 完整结构

```javascript
// src/core/vdom/vnode.js
class VNode {
  constructor(tag, data, children, text, elm, context, componentOptions, asyncFactory) {
    this.tag = tag              // 标签名 'div'
    this.data = data            // ★ 节点的属性/事件/指令等
    this.children = children    // 子 vnode 数组
    this.text = text            // 文本节点的内容
    this.elm = elm              // 对应的真实 DOM
    this.key = data && data.key // 复用判定 key
    // ...
  }
}
```

#### `data` 里到底有什么

`data` 是一个对象，包含**这个节点的所有"非内容"配置**：

```javascript
{
  attrs:    { id: 'app', 'data-x': '1' },       // 普通 HTML 属性
  props:    { value: 'hello', checked: true },  // DOM 属性
  domProps: { innerHTML: '...' },               // DOM 直接属性
  class:    'btn primary',                      // 动态 class
  staticClass: 'btn',                           // 静态 class
  style:    { color: 'red' },                   // 动态 style
  staticStyle: { fontSize: '14px' },            // 静态 style
  on:       { click: handler, input: ... },     // v-on 事件
  nativeOn: { click: handler },                 // .native 修饰符事件
  directives: [{ name: 'show', value: true }],  // 自定义指令
  hook:     { insert, update, destroy },        // 生命周期钩子
  key:      'unique-key',                       // diff 用的 key
  ref:      'inputRef',                         // 模板引用
  slot:     'header',                           // 具名插槽
  scopedSlots: { default: fn },                 // 作用域插槽
  model:    { value, callback },                // v-model 配置
  transition: { name: 'fade' },                 // <transition> 配置
}
```

#### 举例对照

```html
<!-- 模板 -->
<div class="container" id="app" @click="handleClick" v-show="visible">
  Hello
</div>
```

编译后的 vnode：

```javascript
{
  tag: 'div',
  data: {                              // ← 这就是 data
    staticClass: 'container',
    attrs: { id: 'app' },
    on: { click: handleClick },
    directives: [{ name: 'show', value: true }]
  },
  children: [{ tag: undefined, text: 'Hello' }],
  text: undefined,
  elm: <div>...</div>,
  key: undefined
}
```

对比一个**没有任何属性**的节点：

```html
<div>Hello</div>
```

```javascript
{
  tag: 'div',
  data: undefined,        // ← 没有任何配置时 data 是 undefined
  children: [...],
}
```

#### 为什么要判断 `isDef(a.data) === isDef(b.data)`

`isDef` 就是 `v !== undefined && v !== null`。这行的语义是：

> **新旧 vnode 的 `data` 是否"同时存在"或"同时不存在"**——即"配置层级的存在性必须一致"。

考虑这种场景：

```html
<!-- 旧 -->
<div>x</div>                   <!-- data: undefined -->

<!-- 新 -->
<div v-show="true">x</div>     <!-- data: { directives: [...] } -->
```

虽然 `tag` 都是 div、`key` 都是 undefined，但**附加配置完全不同**：新节点带了 `v-show` 指令，旧节点啥也没有。

如果直接走 `patchVnode` 复用 DOM，会进入 update 钩子里调用 `cbs.update`（包含 directives.update / events.update 等），但旧 vnode 上**没有任何指令/事件来对比**，可能导致：

- 指令的 `bind` 钩子没被触发（因为 patch 只触发 update，不会触发 bind）
- 事件、ref、class 合并逻辑出错

所以 Vue 用 `isDef(a.data) === isDef(b.data)` 快速排除这种"配置层级差异巨大"的情况，**让它们走"销毁旧节点 + 创建新节点"的路径**，更安全也更简单。

#### 与 Vue 3 的对比

Vue 3 的 vnode 结构里不再有统一的 `data`，而是**拍平**为：

```typescript
interface VNode {
  type: ...
  props: { class, style, onClick, id, ... }    // ← Vue 2 的 attrs/on/class 全揉到 props
  children: ...
  patchFlag: number       // ← 编译期标好"哪些是动态的"
  dynamicProps: string[]
}
```

Vue 3 的 `isSameVNodeType` 也大大简化：

```typescript
export function isSameVNodeType(n1, n2) {
  return n1.type === n2.type && n1.key === n2.key
}
```

不再需要 `isDef(a.data) === isDef(b.data)` 这种存在性比较——因为有 `patchFlag` 兜底，运行时不会盲目复用。

#### 一句话总结

> `data` 是 Vue 2 VNode 上承载所有节点配置（attrs/class/style/on/directives/hook/key/ref...）的对象。
> `isDef(a.data) === isDef(b.data)` 是在判断"两个节点的配置层级存在性是否一致"——如果一个有配置一个完全裸节点，Vue 选择不复用以避免指令/事件等的状态错乱。

---

## 三、`patchVnode`：同节点的差异更新

判定为"同一节点"后调用 `patchVnode`，按以下顺序处理：

```javascript
function patchVnode(oldVnode, vnode, ...) {
  if (oldVnode === vnode) return        // 引用相同直接返回

  const elm = vnode.elm = oldVnode.elm  // ★ 复用真实 DOM

  // 1. 静态节点跳过
  if (isTrue(vnode.isStatic) &&
      isTrue(oldVnode.isStatic) &&
      vnode.key === oldVnode.key) {
    vnode.componentInstance = oldVnode.componentInstance
    return
  }

  // 2. 触发 prepatch 钩子（组件 vnode 用）
  let i
  const data = vnode.data
  if (isDef(data) && isDef(i = data.hook) && isDef(i = i.prepatch)) {
    i(oldVnode, vnode)
  }

  // 3. 更新属性（class / style / event / dom-props / attrs / directives）
  const oldCh = oldVnode.children
  const ch = vnode.children
  if (isDef(data) && isPatchable(vnode)) {
    for (i = 0; i < cbs.update.length; ++i) cbs.update[i](oldVnode, vnode)
    if (isDef(i = data.hook) && isDef(i = i.update)) i(oldVnode, vnode)
  }

  // 4. 处理子节点
  if (isUndef(vnode.text)) {
    if (isDef(oldCh) && isDef(ch)) {
      // ★★ 关键分支：新旧都有子节点 → updateChildren（双端 diff）
      if (oldCh !== ch) updateChildren(elm, oldCh, ch, ...)
    } else if (isDef(ch)) {
      // 只有新子节点 → 全部新增
      if (isDef(oldVnode.text)) nodeOps.setTextContent(elm, '')
      addVnodes(elm, null, ch, 0, ch.length - 1, ...)
    } else if (isDef(oldCh)) {
      // 只有旧子节点 → 全部删除
      removeVnodes(oldCh, 0, oldCh.length - 1)
    } else if (isDef(oldVnode.text)) {
      // 文本节点变空
      nodeOps.setTextContent(elm, '')
    }
  } else if (oldVnode.text !== vnode.text) {
    // 文本节点：直接 setText
    nodeOps.setTextContent(elm, vnode.text)
  }

  // 5. 触发 postpatch 钩子
  if (isDef(data)) {
    if (isDef(i = data.hook) && isDef(i = i.postpatch)) i(oldVnode, vnode)
  }
}
```

---

## 四、核心算法：`updateChildren`（双端比较）

当新旧 vnode 都有子节点时，Vue 2 使用 **双端比较算法** 处理子节点差异。这是整个 diff 的精华。

### 1. 四个指针

```
oldCh:  [ A,  B,  C,  D ]
          ↑          ↑
       oldStart   oldEnd

newCh:  [ A,  B,  C,  D ]
          ↑          ↑
       newStart   newEnd
```

四个指针：
- `oldStartIdx` / `oldStartVnode` —— 旧列表头
- `oldEndIdx`   / `oldEndVnode`   —— 旧列表尾
- `newStartIdx` / `newStartVnode` —— 新列表头
- `newEndIdx`   / `newEndVnode`   —— 新列表尾

### 2. 主循环：四种命中 + 一种兜底

```javascript
function updateChildren(parentElm, oldCh, newCh, ...) {
  let oldStartIdx = 0
  let oldEndIdx = oldCh.length - 1
  let oldStartVnode = oldCh[0]
  let oldEndVnode = oldCh[oldEndIdx]

  let newStartIdx = 0
  let newEndIdx = newCh.length - 1
  let newStartVnode = newCh[0]
  let newEndVnode = newCh[newEndIdx]

  let oldKeyToIdx, idxInOld, vnodeToMove, refElm

  while (oldStartIdx <= oldEndIdx && newStartIdx <= newEndIdx) {
    if (isUndef(oldStartVnode)) {
      oldStartVnode = oldCh[++oldStartIdx]                  // 跳过被置 undefined 的节点
    } else if (isUndef(oldEndVnode)) {
      oldEndVnode = oldCh[--oldEndIdx]
    }
    // ① 旧头 = 新头：直接 patch，双方头指针后移
    else if (sameVnode(oldStartVnode, newStartVnode)) {
      patchVnode(oldStartVnode, newStartVnode, ...)
      oldStartVnode = oldCh[++oldStartIdx]
      newStartVnode = newCh[++newStartIdx]
    }
    // ② 旧尾 = 新尾：直接 patch，双方尾指针前移
    else if (sameVnode(oldEndVnode, newEndVnode)) {
      patchVnode(oldEndVnode, newEndVnode, ...)
      oldEndVnode = oldCh[--oldEndIdx]
      newEndVnode = newCh[--newEndIdx]
    }
    // ③ 旧头 = 新尾：patch + 把旧头 DOM 移到旧尾右边
    else if (sameVnode(oldStartVnode, newEndVnode)) {
      patchVnode(oldStartVnode, newEndVnode, ...)
      canMove && nodeOps.insertBefore(
        parentElm, oldStartVnode.elm,
        nodeOps.nextSibling(oldEndVnode.elm)
      )
      oldStartVnode = oldCh[++oldStartIdx]
      newEndVnode = newCh[--newEndIdx]
    }
    // ④ 旧尾 = 新头：patch + 把旧尾 DOM 移到旧头左边
    else if (sameVnode(oldEndVnode, newStartVnode)) {
      patchVnode(oldEndVnode, newStartVnode, ...)
      canMove && nodeOps.insertBefore(parentElm, oldEndVnode.elm, oldStartVnode.elm)
      oldEndVnode = oldCh[--oldEndIdx]
      newStartVnode = newCh[++newStartIdx]
    }
    // ⑤ 四种都没命中：用 key 在旧列表中找
    else {
      if (isUndef(oldKeyToIdx)) {
        oldKeyToIdx = createKeyToOldIdx(oldCh, oldStartIdx, oldEndIdx)
      }
      idxInOld = isDef(newStartVnode.key)
        ? oldKeyToIdx[newStartVnode.key]
        : findIdxInOld(newStartVnode, oldCh, oldStartIdx, oldEndIdx)

      if (isUndef(idxInOld)) {
        // 新节点完全没出现过 → 新建
        createElm(newStartVnode, ..., parentElm, oldStartVnode.elm, ...)
      } else {
        vnodeToMove = oldCh[idxInOld]
        if (sameVnode(vnodeToMove, newStartVnode)) {
          // 找到了同 key 节点 → patch + 移动到 oldStart 前
          patchVnode(vnodeToMove, newStartVnode, ...)
          oldCh[idxInOld] = undefined            // ★ 在旧列表中占位，下次循环会跳过
          canMove && nodeOps.insertBefore(parentElm, vnodeToMove.elm, oldStartVnode.elm)
        } else {
          // 同 key 但不同 tag → 新建
          createElm(newStartVnode, ..., parentElm, oldStartVnode.elm, ...)
        }
      }
      newStartVnode = newCh[++newStartIdx]
    }
  }

  // 循环结束后的扫尾：
  if (oldStartIdx > oldEndIdx) {
    // 旧列表先耗尽 → 新列表里剩下的全是新增
    refElm = isUndef(newCh[newEndIdx + 1]) ? null : newCh[newEndIdx + 1].elm
    addVnodes(parentElm, refElm, newCh, newStartIdx, newEndIdx, ...)
  } else if (newStartIdx > newEndIdx) {
    // 新列表先耗尽 → 旧列表里剩下的全是删除
    removeVnodes(oldCh, oldStartIdx, oldEndIdx)
  }
}
```

### 3. 五种情况图示

#### ① 旧头 vs 新头（命中：复用，指针后移）
```
旧: [A B C D]    新: [A E F G]
     ↑                ↑
     └─ 都是 A，patch 后双方 start++
```

#### ② 旧尾 vs 新尾（命中：复用，指针前移）
```
旧: [A B C D]    新: [E F G D]
           ↑                ↑
           └─ 都是 D，patch 后双方 end--
```

#### ③ 旧头 vs 新尾（命中：节点从头移到尾）
```
旧: [A B C D]    新: [B C D A]    ← 把旧头 A 移到 D 的右边
     ↑       ↑       ↑       ↑
     旧start          新end
```

#### ④ 旧尾 vs 新头（命中：节点从尾移到头）
```
旧: [A B C D]    新: [D A B C]    ← 把旧尾 D 移到旧头 A 的左边
           ↑          ↑
           旧end       新start
```

#### ⑤ 四种都没命中（用 key 查找）
```
旧: [A B C D]    新: [E ...]
     ↑↑↑↑          ↑
                  E 不在四个端点 → 在旧列表中按 key 查找
                  找到了 → patch+移动；找不到 → 新建
```

### 4. `key` 的作用：构建 `oldKeyToIdx`

```javascript
function createKeyToOldIdx(children, beginIdx, endIdx) {
  const map = {}
  for (let i = beginIdx; i <= endIdx; ++i) {
    const key = children[i].key
    if (isDef(key)) map[key] = i
  }
  return map
}
```

把旧列表里有 key 的节点建一个 `{key: 索引}` 的映射表，O(1) 查找。**没 key 时 fallback 到 `findIdxInOld` 做 O(n) 线性查找**——这就是为什么不写 key 性能差，且容易触发节点错位复用。

### 5. `findIdxInOld`：没有 key 时的 O(n) 兜底查找

当某个新节点**自己没有 key**时，`oldKeyToIdx[newStartVnode.key]` 拿到的是 `undefined`，这时进入 `findIdxInOld` 兜底：

```javascript
// src/core/vdom/patch.js
function findIdxInOld(node, oldCh, start, end) {
  for (let i = start; i < end; i++) {
    const c = oldCh[i]
    if (isDef(c) && sameVnode(node, c)) {   // ★ 线性扫一遍剩余的旧列表
      return i
    }
  }
}
```

#### 1. 它做了什么

- 在旧列表的 **未处理区间** `[oldStartIdx, oldEndIdx)`（注意是开区间，不含 `end`）线性扫描
- 对每个旧节点调 `sameVnode` 判定
- 找到第一个"看起来相同"的旧节点就返回其索引；都找不到返回 `undefined`

#### 2. 调用上下文回顾

```javascript
// updateChildren 中的第 ⑤ 分支
idxInOld = isDef(newStartVnode.key)
  ? oldKeyToIdx[newStartVnode.key]                          // 有 key：O(1)
  : findIdxInOld(newStartVnode, oldCh, oldStartIdx, oldEndIdx)  // 无 key：O(n)

if (isUndef(idxInOld)) {
  createElm(newStartVnode, ...)                  // 找不到 → 新建
} else {
  vnodeToMove = oldCh[idxInOld]
  if (sameVnode(vnodeToMove, newStartVnode)) {
    patchVnode(vnodeToMove, newStartVnode, ...)
    oldCh[idxInOld] = undefined                 // 占位防止重复匹配
    canMove && nodeOps.insertBefore(parentElm, vnodeToMove.elm, oldStartVnode.elm)
  } else {
    createElm(newStartVnode, ...)
  }
}
```

#### 3. 为什么比 `oldKeyToIdx` 慢得多

| 维度 | 有 key | 无 key（findIdxInOld） |
|------|--------|------------------------|
| 数据结构 | 提前构建的 `Object` 哈希表 | 没有预处理，每次重新线性扫 |
| 单次查找复杂度 | **O(1)** | **O(n)**（n 是剩余未处理区间长度） |
| 总体复杂度（最坏） | O(n) | **O(n²)** |
| 命中条件 | 严格按 key 匹配 | 按 `sameVnode` —— **只看 tag/isComment/data 存在性/inputType** |

#### 4. 真正危险的地方：错位复用

`findIdxInOld` 的判定不是按 key，而是按 `sameVnode`。这意味着它会找到"**结构看起来一样的第一个**"旧节点——这对纯展示节点没问题，但**对有内部状态的节点（input / 子组件 / 动画）是灾难**。

##### 经典反例

```html
<ul>
  <li v-for="item in list">                <!-- ❌ 没写 key -->
    <input :placeholder="item.name" />
  </li>
</ul>
```

旧 list：`[A, B, C]`，用户在 B 的 input 里输入了 "hello"。
新 list：`[C, A, B]`（顺序变了）。

进入 `updateChildren` 时，双端比较全部失配，走到第 ⑤ 分支：

- 新头是 "C"（无 key）→ `findIdxInOld` 在旧列表扫一遍 → **找到的不一定是真正的 C 节点，而是第一个 `<li><input></li>` 结构匹配的——即旧 A**
- 把旧 A 的 DOM 复用过来作为新 C
- 旧 A 的 input 里没有任何用户输入 → 没毛病
- 继续处理 → 用旧 B 复用作为新 A → **用户输入的 "hello" 留在了"现在显示 A"的那个 input 里**

> 用户明明在 B 里输入的，结果切换顺序后内容跑到 A 里去了——这就是"节点错位复用"。

##### 加 key 后

```html
<li v-for="item in list" :key="item.id">
```

- `oldKeyToIdx` 提前构好 `{ A:0, B:1, C:2 }`
- 新头 C → O(1) 找到旧索引 2 → 复用真正的旧 C 节点
- input 跟着节点本身走 → 用户输入正确跟随

#### 5. 一句话总结

> `findIdxInOld` 是 Vue 2 在节点**没有 key** 时的兜底机制：在剩余旧列表里线性扫描 `sameVnode`。
> 它把单次查找从 O(1) 退化为 O(n)，且**只按结构特征匹配**，因此带状态的节点（input、子组件、动画）容易发生"错位复用"——这就是 `v-for` 必须写 `:key` 的根本原因。

---

## 五、完整示例：双端 diff 走一遍

### 旧列表：`[A, B, C, D]`
### 新列表：`[D, A, B, C]`

初始指针：
```
oldCh:  A   B   C   D       newCh:  D   A   B   C
        ↑           ↑               ↑           ↑
       oS          oE              nS          nE
```

#### 第 1 轮
- 旧头 A vs 新头 D → 不同
- 旧尾 D vs 新尾 C → 不同
- 旧头 A vs 新尾 C → 不同
- 旧尾 D vs 新头 D → ✅ 命中！
  - `patchVnode(D, D)`
  - 把 D 的 DOM 移到旧头 A 的左边
  - `oE--` 指向 C，`nS++` 指向 A

```
oldCh:  A   B   C   D       newCh:  D   A   B   C
        ↑       ↑                       ↑       ↑
       oS      oE                      nS      nE
DOM:   [D A B C]
```

#### 第 2 轮
- 旧头 A vs 新头 A → ✅ 命中
  - `patchVnode(A, A)`，`oS++` `nS++`

```
oldCh:  A   B   C   D       newCh:  D   A   B   C
            ↑   ↑                           ↑   ↑
           oS  oE                          nS  nE
```

#### 第 3 轮
- 旧头 B vs 新头 B → ✅ 命中
  - `patchVnode(B, B)`，`oS++` `nS++`

```
oldCh:  A   B   C   D       newCh:  D   A   B   C
                ↑↑                              ↑↑
                oS oE                          nS nE
```

#### 第 4 轮
- 旧头 C vs 新头 C → ✅ 命中
  - `patchVnode(C, C)`，`oS++` `nS++`
- `oldStartIdx > oldEndIdx`，循环退出

最终结果：DOM 顺序 `[D, A, B, C]`，只发生了一次 DOM 移动（D 从尾移到头）。

---

## 六、关键设计点深入分析

### 1. 为什么是"双端"而不是"单端"？

单端比较（只从头到尾）在很多常见操作下表现差：

- **倒序**：`[A,B,C,D]` → `[D,C,B,A]` 单端要 n 次移动，双端只需识别"旧尾=新头"反复命中
- **整体右移**：`[A,B,C,D]` → `[D,A,B,C]` 单端要把 D 找到再移动，双端"旧尾=新头"一次命中
- **整体左移**：`[A,B,C,D]` → `[B,C,D,A]` 双端"旧头=新尾"一次命中

双端比较把"头/尾对齐 / 反向对齐"这 4 种**高频用户操作模式**直接编码进算法，避免走最慢的 key map 查找。

### 2. 为什么必须用 `key`？

```html
<!-- 不写 key 的灾难场景 -->
<input v-for="item in list" :placeholder="item.name">
```

不写 key 时，Vue 默认按**就地复用**策略——只看相同位置上的节点 tag 是否一致，一致就复用。如果用户在 input 里输入了内容，再排序列表，DOM 元素不变，但 placeholder 错位，导致用户输入的内容被错配到错误的项上。

带 key 后：
- 双端比较失败时进入第 ⑤ 分支
- 用 `oldKeyToIdx[key]` O(1) 找到原本的 vnode
- 复用对应的真实 DOM，保持组件状态/输入框值正确

### 3. `oldCh[idxInOld] = undefined` 的占位意义

第 ⑤ 分支命中后：

```javascript
oldCh[idxInOld] = undefined
```

为什么不直接 `splice` 删掉？因为 splice 会让后面的所有索引前移，破坏 `oldEndIdx` 等指针。置 `undefined` 后下一轮循环开头的判断会跳过：

```javascript
if (isUndef(oldStartVnode)) {
  oldStartVnode = oldCh[++oldStartIdx]
}
```

### 4. 静态节点跳过优化

```javascript
if (isTrue(vnode.isStatic) && ...) {
  vnode.componentInstance = oldVnode.componentInstance
  return
}
```

编译时通过 `optimize` 阶段标记的"静态节点"（不含任何响应式插值的子树）在更新时直接跳过 patch，仅复用引用——这是 Vue 2 编译期优化的兜底。

---

## 七、Vue 2 Diff 的局限

| 问题 | 说明 |
|------|------|
| **没有最长递增子序列优化** | 复杂乱序时移动次数偏多 |
| **全量比对** | 即使只有 1 个节点变了，也要走完整个 children 循环 |
| **无静态节点提升** | 静态节点仍会出现在 vnode 树中，每次 patchVnode 都需判断 |
| **patchFlag 缺失** | 不知道一个节点只有 class 变了/text 变了，每次都全字段 diff |
| **block tree 缺失** | 跨层级的稳定节点无法快速跳过 |

这些痛点正是 Vue 3 改造 diff 的动机。

---

## 八、一句话总结

> Vue 2 Diff = **同层比较** + **`sameVnode` 判同** + **双端比较 4 命中** + **key 索引兜底**。
> 在常见的"头部增删、尾部增删、整体平移、倒序"场景下能 O(1)/O(n) 完成；
> 在复杂乱序场景下退化到 O(n) 的 key map 查找，整体比传统 O(n³) 树 diff 快得多，
> 但比 Vue 3 的"编译期标记 + 最长递增子序列"还慢一档。
