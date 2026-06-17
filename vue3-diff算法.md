# Vue 3 Diff 算法详解

> Vue 3 在 Vue 2 双端 diff 的基础上做了根本性变革：
> **编译期标记（patchFlag / block）** + **运行时最长递增子序列（LIS）** + **静态提升 / 缓存事件**。
> 设计目标：让 diff 在大多数实际场景下不再"全量比对"，而是**按需 patch、按需移动**。

---

## 一、核心改进概览

| 维度 | Vue 2 | Vue 3 |
|------|-------|-------|
| 子节点 diff 主算法 | 双端比较（4 命中） | 双端预处理 + 中间用最长递增子序列 |
| 静态节点处理 | 编译时仅标记 isStatic，patch 仍要遍历 | **静态提升**：直接复用同一个 vnode 引用 |
| 节点变更类型识别 | 运行时全字段比较 class/style/attr/text | **patchFlag**：编译期标好"只有 class / 只有 text / 完整动态"，按位 patch |
| 跨层级稳定节点 | 必须递归走到 | **block tree**：跳过所有静态包裹，只遍历"动态后代数组" |
| 事件 | 每次更新都重新绑 | **cacheHandlers**：事件函数缓存 |
| 文本插值 | 走通用 patchVnode | **快速 text patch 路径** |

> 一句话：Vue 2 优化的是"diff 算法本身"，Vue 3 优化的是"diff 之前的信息密度"——在编译期就告诉运行时该做什么。

---

## 二、运行时 diff 入口：`patch` 与 `patchElement`

```typescript
// packages/runtime-core/src/renderer.ts
const patch = (n1, n2, container, anchor, parentComponent, ..., optimized = false) => {
  if (n1 === n2) return

  // 类型不同：直接卸载旧节点
  if (n1 && !isSameVNodeType(n1, n2)) {
    unmount(n1, ...)
    n1 = null
  }

  // patchFlag === -2 表示 BAIL（编译期已放弃优化）
  if (n2.patchFlag === PatchFlags.BAIL) optimized = false

  const { type, ref, shapeFlag } = n2
  switch (type) {
    case Text:        processText(n1, n2, ...);        break
    case Comment:     processCommentNode(...);          break
    case Static:      n1 == null ? mountStaticNode(n2, ...) : patchStaticNode(...); break
    case Fragment:    processFragment(n1, n2, ...);     break
    default:
      if (shapeFlag & ShapeFlags.ELEMENT)         processElement(...)
      else if (shapeFlag & ShapeFlags.COMPONENT)  processComponent(...)
      else if (shapeFlag & ShapeFlags.TELEPORT)   type.process(...)
      else if (shapeFlag & ShapeFlags.SUSPENSE)   type.process(...)
  }
}
```

`isSameVNodeType` 判定（比 Vue 2 简单）：

```typescript
export function isSameVNodeType(n1: VNode, n2: VNode): boolean {
  return n1.type === n2.type && n1.key === n2.key
}
```

---

## 三、编译期：patchFlag —— 告诉运行时"哪些字段是动态的"

### 1. patchFlag 枚举（按位编码）

```typescript
export const enum PatchFlags {
  TEXT             = 1,        // 动态文本
  CLASS            = 1 << 1,   // 动态 class
  STYLE            = 1 << 2,   // 动态 style
  PROPS            = 1 << 3,   // 动态非 class/style 属性
  FULL_PROPS       = 1 << 4,   // 包含动态 key 的 props，需全量 diff
  HYDRATE_EVENTS   = 1 << 5,   // SSR 客户端激活需绑事件
  STABLE_FRAGMENT  = 1 << 6,   // 子节点顺序不变的 Fragment（v-for 静态长度）
  KEYED_FRAGMENT   = 1 << 7,   // 带 key 的 Fragment
  UNKEYED_FRAGMENT = 1 << 8,   // 无 key 的 Fragment
  NEED_PATCH       = 1 << 9,   // 仅需挂载/卸载钩子，本身无动态绑定
  DYNAMIC_SLOTS    = 1 << 10,  // 动态插槽
  DEV_ROOT_FRAGMENT= 1 << 11,  // dev 用的根 Fragment
  HOISTED          = -1,       // 静态提升节点
  BAIL             = -2        // 退出优化模式
}
```

### 2. 编译产物示例

```vue
<template>
  <div>
    <p>Static</p>
    <p>{{ msg }}</p>
    <p :class="cls">{{ msg }}</p>
  </div>
</template>
```

编译为：

```javascript
import { createElementVNode as _createElementVNode } from "vue"

const _hoisted_1 = /*#__PURE__*/_createElementVNode("p", null, "Static", -1 /* HOISTED */)
//                                                                      ↑ 静态提升

export function render(_ctx, _cache) {
  return (_openBlock(), _createElementBlock("div", null, [
    _hoisted_1,                                            // 静态节点引用复用
    _createElementVNode("p", null, _toDisplayString(_ctx.msg), 1 /* TEXT */),
    _createElementVNode("p", { class: _ctx.cls }, _toDisplayString(_ctx.msg), 3 /* TEXT, CLASS */)
    //                                                                          ↑ 1 | 2 = 3
  ]))
}
```

### 3. 运行时按 flag 分发：`patchElement`

#### 关于 `n1` / `n2` 的命名约定

在 Vue 3 渲染器（`packages/runtime-core/src/renderer.ts`）中，几乎所有 patch 系列函数都遵循同一套命名：

| 参数 | 含义 | 可能为 null 吗 |
|------|------|---------------|
| **`n1`** | **旧 VNode**（old VNode，上一次渲染的结果） | ✅ 首次挂载时为 `null` |
| **`n2`** | **新 VNode**（new VNode，本次渲染要呈现的结果） | ❌ 永远存在 |

`n1` / `n2` 不是任意命名，而是 Vue 3 源码里**全局统一的约定**——`patch / patchElement / patchBlockChildren / processText / processFragment / processComponent` 等所有比对函数都用这两个参数名。

##### 一个最小示例

```typescript
// 父节点上一次渲染：<div id="a">old</div>
const n1: VNode = {
  type: 'div',
  props: { id: 'a' },
  children: 'old',
  el: <真实 DOM 引用>,         // ← 关键：旧 vnode 持有当前挂载的真实 DOM
  patchFlag: ...
}

// 父节点这一次渲染：<div id="b">new</div>
const n2: VNode = {
  type: 'div',
  props: { id: 'b' },
  children: 'new',
  el: null,                    // ← 新 vnode 还没绑定真实 DOM
  patchFlag: 1 | 8             // TEXT | PROPS
}

patchElement(n1, n2, ...)
//  ↓
//  const el = (n2.el = n1.el!)       // ★ 把旧 vnode 持有的真实 DOM 引用过户给新 vnode
//  按 patchFlag 更新 props / text
```

##### 为什么要 `n2.el = n1.el`

VNode 是一次渲染生成的"快照"，每次 render 都会产生**全新的** vnode 对象（即使内容完全相同）。但**真实 DOM 元素是同一个**——它由旧 vnode 的 `el` 字段持有。

`n2.el = n1.el` 这一步就是**所有权移交**：把真实 DOM 的引用从"上一帧的 vnode"过户到"这一帧的 vnode"，让下一次 patch 时 `n1 = 这次的 n2`，继续往后用。

##### 全链路：`n1` / `n2` 的来源与去向

```
                  组件首次挂载
                       │
                       ▼
              setupRenderEffect()
                  effect(() => {
                       │
                       ▼
            const subTree = renderComponentRoot()   ← 生成本次 vnode 树
                       │
                       ▼
            patch(prevTree, subTree, ...)            ← 旧→新，prevTree=null 表示首次
              │  n1     n2
              │
              ├─ shapeFlag 判断 type
              │
              └─ patchElement(n1, n2, ...)
                    │  旧    新
                    │
                    ├─ n2.el = n1.el          ← 真实 DOM 过户
                    ├─ 按 patchFlag 精准更新
                    └─ 递归 patchBlockChildren / patchChildren
                                │  n1.dynamicChildren / n2.dynamicChildren
                                │   旧子               新子
                                ▼
                          (继续往下递归)
            ★ 本次渲染结束后：
              instance.subTree = subTree     ← 这次的 n2 变成"下一次的 n1"
            ★ 下一次响应式触发 effect 时：
              patch(instance.subTree /* 这就是上次的 n2 */, 新的 subTree, ...)
```

##### 各 patch 函数中 `n1` / `n2` 的常见用法

| 操作 | 代码 | 含义 |
|------|------|------|
| 复用真实 DOM | `n2.el = n1.el` | 把 DOM 引用从旧 vnode 过户到新 vnode |
| 提前返回 | `if (n1 === n2) return` | 静态提升节点引用相同时跳过 |
| 类型变更 | `if (n1 && !isSameVNodeType(n1, n2))` | 旧的销毁、新的从头创建 |
| 取 patchFlag | `n2.patchFlag \|= n1.patchFlag & PatchFlags.FULL_PROPS` | 继承旧 vnode 的 FULL_PROPS 标记 |
| 旧/新 props 对比 | `const oldProps = n1.props \|\| EMPTY_OBJ; const newProps = n2.props \|\| EMPTY_OBJ` | 准备 patchProps 入参 |
| 子节点递归 | `patchBlockChildren(n1.dynamicChildren!, n2.dynamicChildren, ...)` | 把旧/新各自的动态子数组继续往下 diff |

##### `n1 = null` 的特殊语义

在 `patch(n1, n2, ...)` 中 `n1 = null` 表示 **"没有旧节点"**，即首次挂载：

```typescript
// 第 i 个新节点是新增的，没有对应旧节点
patch(null, c2[i], container, anchor, ...)
//      ↑    ↑
//     n1   n2
```

这时 patch 函数走 mount 路径而不是 patchXxx 更新路径。

#### 完整源码

```typescript
const patchElement = (n1, n2, parentComponent, ..., optimized) => {
  const el = (n2.el = n1.el!)
  let { patchFlag, dynamicChildren, dirs } = n2

  patchFlag |= n1.patchFlag & PatchFlags.FULL_PROPS

  const oldProps = n1.props || EMPTY_OBJ
  const newProps = n2.props || EMPTY_OBJ

  if (patchFlag > 0) {
    if (patchFlag & PatchFlags.FULL_PROPS) {
      // 全量 props diff（含动态 key）
      patchProps(el, n2, oldProps, newProps, ...)
    } else {
      // ★ 精准 patch：只更新对应字段
      if (patchFlag & PatchFlags.CLASS && oldProps.class !== newProps.class) {
        hostPatchProp(el, 'class', null, newProps.class, ...)
      }
      if (patchFlag & PatchFlags.STYLE) {
        hostPatchProp(el, 'style', oldProps.style, newProps.style, ...)
      }
      if (patchFlag & PatchFlags.PROPS) {
        // 只遍历 dynamicProps 数组中的字段
        const propsToUpdate = n2.dynamicProps!
        for (let i = 0; i < propsToUpdate.length; i++) {
          const key = propsToUpdate[i]
          const prev = oldProps[key]
          const next = newProps[key]
          if (next !== prev || key === 'value') {
            hostPatchProp(el, key, prev, next, ...)
          }
        }
      }
    }
    if (patchFlag & PatchFlags.TEXT) {
      if (n1.children !== n2.children) hostSetElementText(el, n2.children as string)
    }
  } else if (!optimized && dynamicChildren == null) {
    // 没有 patchFlag 信息 → 退回全量 patchProps
    patchProps(el, n2, oldProps, newProps, ...)
  }

  // 子节点 patch（核心，下节展开）
  if (dynamicChildren) {
    patchBlockChildren(n1.dynamicChildren!, dynamicChildren, ...)
  } else if (!optimized) {
    patchChildren(n1, n2, el, ...)
  }
}
```

**关键改变**：Vue 2 中每次都比对 `class / style / attrs / domProps` 全字段；Vue 3 通过 `patchFlag` 按位测试，只看真正可能变化的字段。

### 4. 细节：`patchFlag |= n1.patchFlag & PatchFlags.FULL_PROPS` 是什么意思

这一行（对应源码注释 [#1426](https://github.com/vuejs/core/pull/1426)）看着拗口，其实是一个 **de-opt（去优化）保护性补丁**，专门处理"用户克隆 vnode 导致优化丢失"的边界情况。

#### 1) 先拆解语法

```typescript
patchFlag |= n1.patchFlag & PatchFlags.FULL_PROPS

// 等价展开：
const a = n1.patchFlag & PatchFlags.FULL_PROPS   // ① 取出旧 vnode 是否带 FULL_PROPS 这一位
patchFlag = patchFlag | a                        // ② 把这一位"或"进当前的 patchFlag
```

回顾枚举（用二进制位编码）：

```typescript
TEXT       = 1       // 0b00000001
CLASS      = 1 << 1  // 0b00000010
STYLE      = 1 << 2  // 0b00000100
PROPS      = 1 << 3  // 0b00001000
FULL_PROPS = 1 << 4  // 0b00010000   ← 第 5 位
```

- **`&`（按位与）**：用作"提取某一位"——`x & FULL_PROPS` 结果要么是 `FULL_PROPS`，要么是 `0`
- **`|=`（按位或赋值）**：用作"设置某一位"——把该位置 1，其他位不动

整行的语义就是：

> **"如果旧 vnode 的 patchFlag 里有 FULL_PROPS 这一位，就把它也加到当前要用的 patchFlag 上。"**

#### 2) `FULL_PROPS` 表示什么

它表示**"这个节点的 props 里出现了不可静态分析的动态 key"**：

```vue
<!-- 动态 key：编译器无法预先列出会变的字段 -->
<div v-bind="dynamicObj"></div>
<div :[propName]="value"></div>
```

带 `FULL_PROPS` 时，运行时**不能**只更新 `dynamicProps` 数组里那几个字段，必须对 `oldProps` 和 `newProps` **全字段 diff**——因为编译器不知道哪些 key 旧的有、新的没有，要"删掉旧的不在新的里的、添加新的不在旧的里的"。

```typescript
if (patchFlag & PatchFlags.FULL_PROPS) {
  patchProps(el, n2, oldProps, newProps, ...)    // ★ 全量 props diff
} else {
  // 只 patch CLASS / STYLE / dynamicProps 数组里的字段
}
```

#### 3) 为什么要从 `n1` 把这一位"或"过来

源码注释：

```typescript
// #1426 take the old vnode's patch flag into account since user may clone a
// compiler-generated vnode, which de-opts to FULL_PROPS
```

**触发场景：用户手动 `cloneVNode`**

```typescript
import { cloneVNode } from 'vue'

function render() {
  const orig = h('div', { id: 'a' }, 'hello')      // 编译器生成，patchFlag=PROPS（精准）
  const cloned = cloneVNode(orig, { class: 'red' }) // ★ 克隆+合并 → 升级 FULL_PROPS
  return cloned
}
```

`cloneVNode` 内部（简化）：

```typescript
export function cloneVNode(vnode, extraProps) {
  return {
    ...vnode,
    props: extraProps ? mergeProps(vnode.props, extraProps) : vnode.props,
    // ★ 合并了额外 props 时，patchFlag 强制升级为 FULL_PROPS
    patchFlag: extraProps
      ? vnode.patchFlag | PatchFlags.FULL_PROPS
      : vnode.patchFlag,
  }
}
```

因为 `extraProps` 在编译期不可见，编译期标的 `dynamicProps: ['id']` 已经不能完整描述新对象，所以 cloneVNode 强制升级为 FULL_PROPS，保证运行时走全量 diff。

**跨渲染帧的传染问题**：

```
第 1 次渲染：
  vnode_v1 = cloneVNode(原始)        →  patchFlag = FULL_PROPS  → 全量 diff ✅

第 2 次渲染：
  vnode_v2 = h('div', { id: 'a' })   →  patchFlag = PROPS（精准）
  patch(n1=vnode_v1, n2=vnode_v2)
              │              │
        带 FULL_PROPS    只 PROPS（编译器认为只有 id 是动态的）
```

旧 vnode（n1）是 cloneVNode 出来的，props 里残留着 `class: 'red'`，新 vnode（n2）的 `dynamicProps=['id']` 并不包含 `class`。**如果只按 n2.patchFlag 走精准 PROPS 路径，`class` 字段不会被清掉**——DOM 上残留上一次的 `class="red"`。

**解决方案**：把 `n1.patchFlag` 上的 FULL_PROPS 位"或"到当前 `patchFlag`，强制这一帧也走全量 diff，把"上一帧多塞进去的字段"清理干净。

#### 4) 为什么不直接 `patchFlag |= FULL_PROPS`

因为不能**无条件**升级——大多数情况下 `n1.patchFlag` 里没有 FULL_PROPS，这时 `n1.patchFlag & FULL_PROPS = 0`，`patchFlag |= 0` 是无操作，**保留原有的精准 patch 优化**。

只有当 n1 真的曾经被克隆/合并过、确实带了 FULL_PROPS 标志时，才把它传染过来。这是一种**有条件的"残留状态传递"**。

#### 5) 位运算图示

```
┌───────────────────────────────────────────────────────────────────┐
│                                                                   │
│   n1.patchFlag  =  PROPS | FULL_PROPS  =  0b00011000               │
│                                                                   │
│   n1.patchFlag & FULL_PROPS                                       │
│       0b00011000                                                  │
│   &   0b00010000                                                  │
│   ──────────────                                                  │
│       0b00010000   ← 提取出 FULL_PROPS 这一位（其他位都清零）       │
│                                                                   │
│   patchFlag (来自 n2) = PROPS = 0b00001000                         │
│                                                                   │
│   patchFlag |= 0b00010000                                          │
│       0b00001000                                                  │
│   |   0b00010000                                                  │
│   ──────────────                                                  │
│       0b00011000   ← 现在带上了 FULL_PROPS，走全量 diff             │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

#### 6) 一句话总结

> 如果**旧 vnode 上带着 `FULL_PROPS` 标记**（往往是因为用户用 `cloneVNode` 合并了额外 props 而被强制 de-opt），就把这个标记"传染"到本次 patch 用的 patchFlag 上，强制走全量 props diff，
> 防止"上一帧塞进去的多余字段"在这一帧得不到清理。

---

## 四、编译期：Block Tree —— 跨层级跳过静态节点

### 1. 什么是 Block

Block 是 Vue 3 引入的"动态节点收集容器"：

```typescript
function createBlock(type, props, children, patchFlag, dynamicProps) {
  return setupBlock(createVNode(type, props, children, patchFlag, dynamicProps, true))
}
```

`openBlock()` / `createBlock()` 配对使用，在 vnode 创建过程中**收集所有动态子节点**到一个扁平数组 `dynamicChildren`。

### 2. dynamicChildren：动态后代的扁平数组

```vue
<template>
  <div>
    <header>
      <h1>Static Title</h1>
    </header>
    <main>
      <article>
        <p>{{ content }}</p>            <!-- 动态 -->
      </article>
    </main>
    <footer>{{ year }}</footer>          <!-- 动态 -->
  </div>
</template>
```

block 收集后：

```
block (div)
  dynamicChildren: [
    p(TEXT, content),       ← 跨过 main/article
    footer(TEXT, year)
  ]
```

### 3. `patchBlockChildren`：只遍历动态后代

```typescript
const patchBlockChildren = (
  oldChildren: VNode[],
  newChildren: VNode[],
  fallbackContainer: RendererElement,
  ...
) => {
  for (let i = 0; i < newChildren.length; i++) {
    const oldVNode = oldChildren[i]
    const newVNode = newChildren[i]
    const container = ...
    patch(oldVNode, newVNode, container, null, ..., true)  // ★ optimized=true
  }
}
```

**核心收益**：上面的例子里，更新 `content` 时根本不需要遍历 `header → h1`、`main → article` 这些路径，直接对 `dynamicChildren` 里的两个节点做 patch。

### 4. Block 嵌套规则

某些场景会创建子 block：

- `v-if` / `v-else-if` / `v-else`：每个分支是独立 block，分支切换时整体替换
- `v-for`：每次循环的根是一个 block
- `<Suspense>`、`<Teleport>`：内部独立 block

这些"边界 block"打断了 dynamicChildren 的扁平化，避免乱序时优化失效。

---

## 五、子节点 diff 主算法：`patchKeyedChildren`

当一个节点真的有需要 diff 的子节点列表时（如 `v-for` 的 KEYED_FRAGMENT），走 `patchKeyedChildren`：

### 关于 `c1` / `c2` 的命名约定

延续 `n1` / `n2` 表示"旧 vnode / 新 vnode"的约定，**`c` 是 children 的缩写**：

| 参数 | 含义 | 类型 |
|------|------|------|
| **`c1`** | **旧子节点数组**（old children，上一次渲染的子 vnode 列表） | `VNode[]` |
| **`c2`** | **新子节点数组**（new children，本次渲染的子 vnode 列表） | `VNode[]` |
| `container` | 这些子节点共同的**父真实 DOM 元素**（要往里 insert / remove 的 DOM） | `RendererElement` |
| `parentAnchor` | **末尾锚点**，用于 `insertBefore(node, anchor)` 时定位 | `RendererNode \| null` |

#### 它们从哪里来

`patchKeyedChildren` 是从 `patchChildren` 中分发出来的：

```typescript
const patchChildren = (n1, n2, container, anchor, ...) => {
  const c1 = n1 && n1.children       // ★ 旧 vnode 的子节点
  const c2 = n2.children              // ★ 新 vnode 的子节点
  const prevShapeFlag = n1 ? n1.shapeFlag : 0
  const { patchFlag, shapeFlag } = n2

  if (patchFlag > 0) {
    if (patchFlag & PatchFlags.KEYED_FRAGMENT) {
      patchKeyedChildren(c1 as VNode[], c2 as VNodeArrayChildren, container, anchor, ...)
      return
    } else if (patchFlag & PatchFlags.UNKEYED_FRAGMENT) {
      patchUnkeyedChildren(c1 as VNode[], c2 as VNodeArrayChildren, container, anchor, ...)
      return
    }
  }
  // ...
}
```

所以可以理解为 **`c1 = n1.children`**、**`c2 = n2.children`**——`n1`/`n2` 是"父 vnode"层级的对照，`c1`/`c2` 是它们的"子数组"层级的对照。

#### 一个具体例子

```vue
<template>
  <ul>
    <li v-for="item in list" :key="item.id">{{ item.name }}</li>
  </ul>
</template>
```

```typescript
// 旧 render：list = [{id:1,name:'A'}, {id:2,name:'B'}]
n1 = h('ul', null, [
  h('li', { key: 1 }, 'A'),    // ← c1[0]
  h('li', { key: 2 }, 'B'),    // ← c1[1]
])

// 新 render：list = [{id:2,name:'B'}, {id:1,name:'A'}]（顺序换了）
n2 = h('ul', null, [
  h('li', { key: 2 }, 'B'),    // ← c2[0]
  h('li', { key: 1 }, 'A'),    // ← c2[1]
])

// 进入 patchChildren → patchKeyedChildren：
patchKeyedChildren(
  c1 = [li_A, li_B],            // 旧子数组
  c2 = [li_B, li_A],            // 新子数组
  container = <ul真实DOM>,        // 父元素
  parentAnchor = null
)
```

#### 算法内的别名与配套变量

`patchKeyedChildren` 体内常见的几个伴生变量：

| 变量 | 含义 |
|------|------|
| `l2` | `c2.length`，新子数组长度 |
| `e1` | end of `c1` —— 旧数组当前未处理段的尾索引 |
| `e2` | end of `c2` —— 新数组当前未处理段的尾索引 |
| `i`  | 当前从头部同步扫描的指针 |
| `s1` / `s2` | 进入 Step 5（未知序列）时的起点（start）|

`c1[i]` / `c2[i]` 在源码里经常被赋给临时变量 `n1` / `n2` —— 这时 `n1` / `n2` 又回到"旧 vnode / 新 vnode"的语义，只不过是 children 层级的某个具体节点。这种 **c → n** 的过渡在源码里很常见：

```typescript
while (i <= e1 && i <= e2) {
  const n1 = c1[i]            // ← 取出旧数组里第 i 个 vnode
  const n2 = c2[i]            // ← 取出新数组里第 i 个 vnode
  if (isSameVNodeType(n1, n2)) {
    patch(n1, n2, container, null, ..., optimized)
    i++
  } else {
    break
  }
}
```

#### 一句话总结

> `c` 是 children 缩写，`c1` 是**旧子节点数组**，`c2` 是**新子节点数组**——它们正是父级 `n1` / `n2` 的 `.children`。
> 这套 `n` / `c` 命名约定贯穿整个 Vue 3 渲染器，记住后看源码不会再绕。

### 整体五步走

```typescript
const patchKeyedChildren = (c1, c2, container, parentAnchor, ...) => {
  let i = 0
  const l2 = c2.length
  let e1 = c1.length - 1        // 旧列表尾
  let e2 = l2 - 1               // 新列表尾

  // 1. 从头部预处理：相同节点直接 patch
  // 2. 从尾部预处理：相同节点直接 patch
  // 3. 处理仅新增/仅删除的简单情况
  // 4. 复杂情况：用 keyToNewIndexMap + LIS 算法
}
```

### Step 1：头部同步扫描

```typescript
// 1. sync from start
// (a b) c
// (a b) d e
while (i <= e1 && i <= e2) {
  const n1 = c1[i]
  const n2 = c2[i]
  if (isSameVNodeType(n1, n2)) {
    patch(n1, n2, container, null, ..., optimized)
    i++
  } else {
    break
  }
}
```

### Step 2：尾部同步扫描

```typescript
// 2. sync from end
// a (b c)
// d e (b c)
while (i <= e1 && i <= e2) {
  const n1 = c1[e1]
  const n2 = c2[e2]
  if (isSameVNodeType(n1, n2)) {
    patch(n1, n2, container, null, ..., optimized)
    e1--
    e2--
  } else {
    break
  }
}
```

### Step 3：只有新增

```typescript
// 3. common sequence + mount
// (a b)            旧
// (a b) c          新
// i = 2, e1 = 1, e2 = 2
if (i > e1) {
  if (i <= e2) {
    const nextPos = e2 + 1
    const anchor = nextPos < l2 ? (c2[nextPos] as VNode).el : parentAnchor
    while (i <= e2) {
      patch(null, c2[i], container, anchor, ..., optimized)
      i++
    }
  }
}
```

### Step 4：只有删除

```typescript
// 4. common sequence + unmount
// (a b) c          旧
// (a b)            新
// i = 2, e1 = 2, e2 = 1
else if (i > e2) {
  while (i <= e1) {
    unmount(c1[i], parentComponent, parentSuspense, true)
    i++
  }
}
```

### Step 5：未知序列（核心算法）

走到这里说明中间有一段乱序，需要用 LIS 来最小化移动次数。

#### 什么是"未知序列"

"未知序列"（unknown sequence）是 Vue 3 源码里的术语，指 **经过 Step 1（头同步）和 Step 2（尾同步）剥离了公共前缀/后缀之后，中间剩下的那一段——新旧节点之间的对应关系不能仅凭索引推断**。这是相对前面 4 步"已知模式"而言的。

##### 1) 为什么叫"未知"

前 4 步处理的是 4 种**已知的、有规律的模式**：

| Step | 模式 | 用什么信息判定 |
|------|------|---------------|
| Step 1 头同步 | 前缀相同 | 从 i=0 开始，逐个比较 |
| Step 2 尾同步 | 后缀相同 | 从 e1/e2 开始，向前比较 |
| Step 3 纯新增 | `i > e1 && i <= e2` | 旧的扫完了，新的还有 → 全是新增 |
| Step 4 纯删除 | `i > e2 && i <= e1` | 新的扫完了，旧的还有 → 全是删除 |

它们的共同特点是：**只看索引（i / e1 / e2）就能直接给出操作**。

而 Step 5 走到的场景是：

```
i ≤ e1  且  i ≤ e2     ← 两边都还有节点没处理
```

且这些剩余节点**互相之间不能凭索引匹配**——它们可能是乱序、可能既有新增也有删除、可能跨位置移动。这时 Vue 不知道哪个旧节点对应哪个新节点，所以叫"unknown sequence"。

##### 2) 真实例子

**例 ①：纯乱序（最经典）**

```
旧:  a b c d e f g
新:  a b e d c h f g

  ① Step 1：头同步 → a, b 相同 → i=2
  ② Step 2：尾同步 → f, g 相同 → e1=4, e2=5
  ③ 此时 i=2, e1=4, e2=5，两边中间还各剩：
      旧中间段 [c, d, e]
      新中间段 [e, d, c, h]
      → 进 Step 5
```

**例 ②：中间夹着新增**

```
旧:  a [b c] d
新:  a [c x b] d

  头同步: a → i=1
  尾同步: d → e1=2, e2=3
  剩余:
    旧 [b, c]
    新 [c, x, b]
  → 进 Step 5（既要移动 b/c，又要新增 x）
```

**例 ③：中间夹着删除**

```
旧:  a [b c d] e
新:  a [d b] e

  头同步: a → i=1
  尾同步: e → e1=3, e2=2
  剩余:
    旧 [b, c, d]
    新 [d, b]
  → 进 Step 5（要删 c，还要把 d 提到前面）
```

**例 ④：小段重排**

```
旧:  a x y b
新:  a y x b

  头同步: a → i=1
  尾同步: b → e1=2, e2=2
  剩余:
    旧 [x, y]
    新 [y, x]
  → 进 Step 5（互换位置）
```

##### 3) Step 5 与前 4 步的判定关系

```typescript
// 头同步循环结束
while (i <= e1 && i <= e2) { ... }    // Step 1

// 尾同步循环结束
while (i <= e1 && i <= e2) { ... }    // Step 2

if (i > e1) {                          // Step 3：旧的扫完了，新的还剩 → 全部新增
  if (i <= e2) { ... }
} else if (i > e2) {                   // Step 4：新的扫完了，旧的还剩 → 全部删除
  while (i <= e1) { unmount(c1[i++]) }
} else {                               // ★ Step 5：i ≤ e1 && i ≤ e2 → 两边都剩
  // unknown sequence
}
```

也就是说，**未知序列 = Step 1/2 削掉相同的前后缀后，两端都还有节点没消化完的情况**。

##### 4) 为什么把它单独拎出来叫"未知序列"

性能上的考虑：

| 步骤 | 单步代价 | 触发条件 |
|------|---------|---------|
| Step 1/2 | O(1) 比较 + O(共同长度) 总和 | 几乎所有更新都能命中 |
| Step 3/4 | O(剩余长度) | 纯追加 / 纯删除 |
| **Step 5** | **O(n log n)**（含 LIS） | 真正乱序的情况 |

绝大多数实际场景（列表追加、删除某项、首尾插入）都被前 4 步快速吃掉了；只有"中间真的发生重排"才进 Step 5。**Vue 用 Step 1/2 作为"廉价快速路径"，把最贵的 Step 5 保留给最复杂的情况**——这就是分阶段算法的精髓。

##### 5) 一句话总结

> **"未知序列"** = 头同步、尾同步剥掉公共前后缀之后，**两端都还剩节点未处理**的那段中间区间。
> 这时无法仅靠索引推断新旧关系，必须建立 key → 新索引的映射表，对旧节点逐个查找匹配，再用最长递增子序列计算最少移动方案。
> 它是 Vue 3 子节点 diff 的"最后兜底分支"，也是唯一会触发 LIS 算法的分支。

#### Step 5 源码逐行解析

```typescript
// 5. unknown sequence
// [i ... e1 + 1]: a b [c d e] f g
// [i ... e2 + 1]: a b [e d c h] f g
// i = 2, e1 = 4, e2 = 5
else {
  const s1 = i  // 旧列表中需要 diff 的起点
  const s2 = i  // 新列表中需要 diff 的起点

  // 5.1 建立新列表的 key → 新索引 映射表
  const keyToNewIndexMap: Map<string|number, number> = new Map()
  for (i = s2; i <= e2; i++) {
    const nextChild = c2[i]
    if (nextChild.key != null) keyToNewIndexMap.set(nextChild.key, i)
  }

  // 5.2 遍历旧列表中间段：尝试找对应的新节点
  let j
  let patched = 0
  const toBePatched = e2 - s2 + 1
  let moved = false
  let maxNewIndexSoFar = 0
  // 新中间段每个位置对应的旧节点索引；0 表示该位置是新增节点
  const newIndexToOldIndexMap = new Array(toBePatched).fill(0)

  for (i = s1; i <= e1; i++) {
    const prevChild = c1[i]
    if (patched >= toBePatched) {
      // 新中间段所有节点都已 patch 完，旧的多余 → 删除
      unmount(prevChild, parentComponent, parentSuspense, true)
      continue
    }
    let newIndex
    if (prevChild.key != null) {
      // 看有没有旧Node
      newIndex = keyToNewIndexMap.get(prevChild.key)
    } else {
      // 没 key 的退化：在新列表里线性扫描
      for (j = s2; j <= e2; j++) {
        if (newIndexToOldIndexMap[j - s2] === 0 && isSameVNodeType(prevChild, c2[j])) {
          newIndex = j
          break
        }
      }
    }
    if (newIndex === undefined) {
      unmount(prevChild, ...)                  // 旧节点在新列表中找不到 → 删除
    } else {
      newIndexToOldIndexMap[newIndex - s2] = i + 1   // ★ +1 是为了避免与"新增节点"的 0 冲突
      if (newIndex >= maxNewIndexSoFar) {
        maxNewIndexSoFar = newIndex
      } else {
        moved = true                          // 检测到逆序 → 需要移动
      }
      patch(prevChild, c2[newIndex], container, ...)
      patched++
    }
  }

  // 5.3 求最长递增子序列（仅在 moved=true 时计算）
  const increasingNewIndexSequence = moved
    ? getSequence(newIndexToOldIndexMap)
    : EMPTY_ARR
  j = increasingNewIndexSequence.length - 1

  // 5.4 从右往左遍历：要么挂载新增节点，要么移动节点
  for (i = toBePatched - 1; i >= 0; i--) {
    const nextIndex = s2 + i
    const nextChild = c2[nextIndex]
    const anchor = nextIndex + 1 < l2 ? (c2[nextIndex + 1] as VNode).el : parentAnchor

    if (newIndexToOldIndexMap[i] === 0) {
      // 新增
      patch(null, nextChild, container, anchor, ..., optimized)
    } else if (moved) {
      if (j < 0 || i !== increasingNewIndexSequence[j]) {
        // ★ 不在 LIS 中 → 需要移动
        move(nextChild, container, anchor, MoveType.REORDER)
      } else {
        // ★ 在 LIS 中 → 不需要移动
        j--
      }
    }
  }
}
```

#### 细节：`moved` 检测 + LIS 计算 + 倒序执行（5.2 ~ 5.4 核心）

这部分是 Step 5 的"决策大脑"：**先用一个廉价开关判断要不要算 LIS，再用 LIS 算出"不动的节点"，最后倒序遍历落实 DOM 操作**。

##### 0. 先澄清一个常见误解：`patch` 不会移动 DOM 位置

很多人看到这段代码：

```typescript
if (newIndex >= maxNewIndexSoFar) {
  maxNewIndexSoFar = newIndex
} else {
  moved = true                          // 检测到逆序 → 需要移动
}
patch(prevChild, c2[newIndex], container, ...)
```

会疑惑：**`patch` 不是已经把旧节点复用了吗？为什么还要标 `moved` 后续重排？**

答案是：**`patch` 只复用节点内容，不动 DOM 位置**。

###### `patch` 内部到底做什么

```typescript
patch(n1, n2, container, anchor, ...) {
  n2.el = n1.el                              // 1. 复用真实 DOM 引用
  patchProps(n2.el, n2, oldProps, newProps, ...) // 2. diff props
  patchChildren(n1, n2, n2.el, ...)          // 3. diff children
}
```

**全程没有 `insertBefore` 或 `appendChild`** —— `n2.el` 这个真实 DOM 元素在父容器中的**物理位置原封不动**。

###### 举例：patch 后 DOM 顺序仍是旧顺序

```
旧 DOM:    <ul>
             <li>a</li>      ← elm-a
             <li>b</li>      ← elm-b
             <li>c</li>      ← elm-c
           </ul>

新数据:    [c, a, b]
```

5.2 遍历旧节点全部 `patch` 完后：

```
DOM 顺序仍然是:  [a, b, c]    （只是 a/b/c 的内容更新了）
但新数据要求的: [c, a, b]
                ↑ 必须把 c 移到最前面
```

这就是为什么需要 `moved` 标志和 5.4 阶段的重排。

###### 复用 ≠ 已在正确位置

| 维度 | 由谁决定 | `patch` 改吗 |
|------|----------|-------------|
| DOM 是哪个元素（内存对象） | `n2.el = n1.el` | ✅ 复用 |
| DOM 内部内容（textContent / class / 子节点） | `patchProps` + `patchChildren` | ✅ 更新 |
| DOM 在父元素中的物理位置（兄弟顺序） | 父元素的 `childNodes` 数组 | ❌ 不动 |

**`patch` 处理的是"节点的属性"，5.4 处理的是"节点的位置"** —— 这是两个正交的维度。

###### 为什么不在 patch 时直接移动

1. **拿不到正确的锚点**：5.2 时 DOM 顺序还是旧的，新顺序里的"右邻居"还没就位
2. **可能白移**：当前节点也许属于 LIS（不该动），patch 时立刻 move 就浪费了
3. **集中移动性能更好**：5.4 一次性用 LIS 算出最少移动方案，避免重复操作

###### 类比理解

> **整理书架**：
> - **`patch`** = 擦干净每本书（更新内容） —— 书还在原来位置
> - **`moved`** = 看一眼目标顺序对不对
> - **5.4 的 `move`** = 把需要换位的书真正搬过去
>
> 擦书和摆书完全是两件事，擦完了仍要摆。

###### 一句话

> `patch` 只做"内容复用与更新"——`n2.el = n1.el` 把 DOM 引用过户、`patchProps` 改属性、`patchChildren` 递归子节点——**但这个 DOM 元素在父容器中的物理位置一动也没动**。
> `moved = true` 标志预告了"新旧顺序不一致"，让 5.4 阶段用 LIS 算出"哪些节点需要重新插入到新位置"。**复用节点 ≠ 节点已在正确位置**。

---

##### A. `moved` 检测：判断"是否需要计算 LIS"

```typescript
if (newIndex >= maxNewIndexSoFar) {
  maxNewIndexSoFar = newIndex
} else {
  moved = true                          // 检测到逆序 → 需要移动
}
```

这段嵌在 5.2 循环里——每处理完一个旧节点找到对应的新位置 `newIndex` 之后执行。

###### 1) `maxNewIndexSoFar` 是什么

> **遍历到目前为止，所有旧节点对应"新位置"中的最大值**。

初始 `let maxNewIndexSoFar = 0`，单调向上更新。

###### 2) 核心思想：单调性 = 顺序一致

- 按旧顺序遍历，每个旧节点的 `newIndex` 都单调不减 → 旧的相对顺序在新数组里保持着 → **不需要移动**
- 一旦出现"当前 newIndex 比之前的最大值还小" → 该旧节点在新数组里被前置了 → **必然需要 move()**

###### 3) 三种典型场景

**例 A：顺序保持（无移动）**

```
旧:  a b c d         新:  a x b c d  （新增 x）

遍历旧:
  a → newIndex=0,  max=0   0>=0 ✓
  b → newIndex=2,  max=2   2>=0 ✓
  c → newIndex=3,  max=3   3>=2 ✓
  d → newIndex=4,  max=4   4>=3 ✓
→ moved = false   无需移动，只挂载 x
```

**例 B：发生重排**

```
旧:  a b c         新:  c a b

遍历旧:
  a → newIndex=1,  max=1   1>=0 ✓
  b → newIndex=2,  max=2   2>=1 ✓
  c → newIndex=0   ★ 0 < 2  → moved = true
```

**例 C：纯追加**

```
旧:  a b c         新:  a b c d e

遍历旧: 0,1,2 全程单调 → moved=false
```

###### 4) 为什么需要这个标志位

LIS 算法本身是 O(n log n)，对**纯追加 / 纯顺序保持**的场景毫无必要。`moved` 是一个**廉价的提前优化**：

```typescript
const increasingNewIndexSequence = moved
  ? getSequence(newIndexToOldIndexMap)   // 真要算
  : EMPTY_ARR                            // ★ 不算，直接用空数组
```

`EMPTY_ARR` 是个冻结的空数组（节省创建开销）。后续 `else if (moved)` 分支也不会进 → **完全跳过移动判定**。

###### 5) `moved` 不会被"反转"

```typescript
if (newIndex >= maxNewIndexSoFar) {
  maxNewIndexSoFar = newIndex        // 注意这里没动 moved
} else {
  moved = true                       // 一旦置 true 就再也不重置
}
```

只要中途有过一次逆序，整个 Step 5 都走 LIS 路径——后续无论是否再逆序，发生过就说明需要重排。

---

##### B. 5.3 + 5.4：LIS 计算 + 从右往左执行

```typescript
// 5.3
const increasingNewIndexSequence = moved
  ? getSequence(newIndexToOldIndexMap)
  : EMPTY_ARR
j = increasingNewIndexSequence.length - 1

// 5.4
for (i = toBePatched - 1; i >= 0; i--) {
  const nextIndex = s2 + i
  const nextChild = c2[nextIndex]
  const anchor = nextIndex + 1 < l2 ? (c2[nextIndex + 1] as VNode).el : parentAnchor

  if (newIndexToOldIndexMap[i] === 0) {
    patch(null, nextChild, container, anchor, ..., optimized)   // 新增
  } else if (moved) {
    if (j < 0 || i !== increasingNewIndexSequence[j]) {
      move(nextChild, container, anchor, MoveType.REORDER)      // 不在 LIS → 移动
    } else {
      j--                                                       // 在 LIS → 不动
    }
  }
}
```

###### 1) 关键变量速查

| 变量 | 含义 |
|------|------|
| `toBePatched` | 新中间段长度 `e2 - s2 + 1` |
| `newIndexToOldIndexMap` | 长度 = `toBePatched`，记录每个新位置对应"旧索引 + 1"；0 = 新增 |
| `increasingNewIndexSequence` | LIS 算法返回的**索引数组**（不是值数组），元素是新中间段的局部位置 |
| `j` | 从 LIS 最后一个开始倒序匹配的指针 |
| `i` | 从 `toBePatched-1` 开始倒序遍历新中间段的局部索引 |
| `nextIndex` | `s2 + i`，新节点在 c2 全局的索引 |
| `nextChild` | 当前要处理的新节点 |
| `anchor` | `insertBefore` 的锚点（右邻居的真实 DOM） |

###### 2) LIS 算的是"不动的节点集合"

`newIndexToOldIndexMap` 记录"新位置 → 旧索引（+1）"。

**举例**：

```
旧:  [a, b, c, d, e]            新:  [e, c, d, b, h]

newIndexToOldIndexMap:
  新位置 0 (e): 旧 4 → 存 5（旧位置i + 1）
  新位置 1 (c): 旧 2 → 存 3（旧位置i + 1）
  新位置 2 (d): 旧 3 → 存 4（旧位置i + 1）
  新位置 3 (b): 旧 1 → 存 2（旧位置i + 1）
  新位置 4 (h): 无 → 0 (新增)

数组 = [5, 3, 4, 2, 0]
```

要找：**哪些节点在新数组中的相对顺序与旧数组一致？** 等价于该数组的**最长递增子序列**。

- 忽略新增节点的 0 → `[5,3,4,2]`
- LIS 是 `[3, 4]`，对应新位置索引 `[1, 2]`（即 c 和 d）

`getSequence` 返回的就是 `[1, 2]` —— **新位置 1 和 2 的节点（c 和 d）不需要移动**，其他匹配节点（e、b）需要 move()，h 是新增需要 mount。

###### 3) 为什么从右往左遍历

DOM 操作 `insertBefore(node, anchor)` 要求 **`anchor` 是一个已经在 DOM 中正确位置的右邻居**：

```typescript
const anchor = nextIndex + 1 < l2
  ? (c2[nextIndex + 1] as VNode).el     // 右邻居已经在它该在的位置
  : parentAnchor                         // 已经在最右，用父锚点
```

从右往左走，**当处理位置 i 时，位置 i+1 在 DOM 里已经是终态了**（要么刚 mount/move 过去，要么 LIS 里跳过但本就在末尾）。这样 `anchor` 永远是"对的右邻居"，把 i 插到 anchor 前就一定到正确位置。

从左往右遍历的话，处理 i 时右邻居 i+1 还没就位，根本拿不到正确锚点。

###### 4) 三个分支的语义

```typescript
if (newIndexToOldIndexMap[i] === 0) {
  // ★ 分支 ①：新增（该位置在旧数组里没匹配）
  patch(null, nextChild, container, anchor, ..., optimized)
}
else if (moved) {
  // `getSequence` 返回的就是 `[1, 2]` —— **新位置 1 和 2 的节点（c 和 d）不需要移动**
  if (j < 0 || i !== increasingNewIndexSequence[j]) {
    // ★ 分支 ②：matched 但不在 LIS 中 → 移动
    move(nextChild, container, anchor, MoveType.REORDER)
  } else {
    // ★ 分支 ③：在 LIS 中 → 不动，j--
    j--
  }
}
```

注意没有 `else { ... }` 处理"未 moved + 已匹配"的情况：

- 5.2 已经对每个 matched 节点调用过 `patch(prevChild, c2[newIndex], ...)` 完成了 props/children 更新
- 5.4 只负责 **DOM 排序**
- `moved=false` 意味着"matched 节点的相对顺序已经对了"——连排序都不用，整个 if 都不进，**零开销**

###### 5) `j < 0` 的边界

```typescript
if (j < 0 || i !== increasingNewIndexSequence[j]) move(...)
```

`j < 0` 表示 **LIS 里所有"不动的节点"都已匹配完了**，剩下的 matched 节点必然都要 `move()`。

**那如果不写 `j < 0`，让它走 `increasingNewIndexSequence[-1]` 会怎样？**

###### JS 中 `arr[-1]` 的行为

JavaScript 的数组**不支持负数索引**（不像 Python）。`arr[-1]` 会被当作访问一个不存在的字符串键 `"-1"`，返回 `undefined`：

```javascript
const a = [1, 2, 3]
a[-1]    // undefined（不是 3！）
a[5]     // undefined
```

###### 不写 `j < 0` 会发生什么

```typescript
// 假设去掉 j < 0：
if (i !== increasingNewIndexSequence[j]) move(...)
else j--
```

当 `j = -1` 时：

```typescript
i !== increasingNewIndexSequence[-1]
i !== undefined         // i 是数字，结果恒为 true
→ 进入 move 分支         // ✅ 行为正确，照样移动
```

`else { j-- }` 分支只在 `i === increasingNewIndexSequence[j]` 时触发，而 `i === undefined` 必为 false，所以 `j` 也不会继续往下减——**不会出现 `j = -2, -3, ...` 的递减失控**。

##### 所以加 `j < 0` 不是"非加不可"，而是出于以下考量：

| 考量 | 说明 |
|------|------|
| **可读性 / 意图清晰** | 一眼看出"LIS 用完了，剩下全要 move"——比 "`i !== undefined`" 直接 |
| **短路求值 → 性能微优化** | 命中 `j < 0` 时直接 `||` 短路，省去一次数组访问（虽然 V8 极小开销，但循环里高频出现） |
| **类型安全（TS strict）** | 开启 `noUncheckedIndexedAccess` 时，`arr[j]` 类型推断为 `number \| undefined`，需要单独处理 `undefined` 情况；显式 `j < 0` 避免依赖运行时巧合 |
| **防御编程** | 一旦未来 LIS 算法返回值或循环逻辑改动，`j < 0` 兜底也能避免引入隐式 bug |
| **避免"靠 JS 怪异行为吃饭"** | 依赖 `arr[-1] === undefined` 这种语言细节让代码可读性变差，可移植性差（写过 Python 的人会想当然认为是末尾元素） |

###### 反过来：什么情况下这种"潜在 undefined 比较"会真出问题？

如果 LIS 数组里**正好就有 `undefined`** 这种值，`i !== undefined` 就不再总是 true。但 `getSequence` 的返回值是**索引数组（全是有效非负整数）**，永远不会含 `undefined`——所以**当前实现下不会出 bug**，但仍是"暗坑"。

###### 一句话总结

> 不写 `j < 0`，靠 JS 中 `arr[-1] === undefined` + `i !== undefined` 恒为 true 的巧合，**功能上仍然正确**。
> 但 Vue 选择显式判断 `j < 0`，是为了**意图清晰 / 短路性能 / TS 严格模式 / 防御未来改动**——好的工程代码不应依赖语言的隐式行为来工作。

###### 6) 完整执行过程（继续上面例子）

```
新:                [e, c, d, b, h]
newIndexToOldIndexMap = [5, 3, 4, 2, 0]
LIS（索引）:       [1, 2]              （c 和 d）
j 初始 = 1

倒序遍历 i = 4 → 0:

i=4 (h)
   map[4]===0 → ★ mount h
   anchor: i+1=5 ≥ l2 → 用 parentAnchor

i=3 (b)
   map[3]===2 ≠0
   moved=true, i===LIS[j]?  3 === LIS[1]=2? ✗
   → ★ move b 到 h 前面
   anchor: c2[4].el (h)

i=2 (d)
   map[2]===4 ≠0
   moved=true, i===LIS[j]?  2 === LIS[1]=2? ✓
   → ★ 不动，j-- (j=0)

i=1 (c)
   map[1]===3 ≠0
   moved=true, i===LIS[j]?  1 === LIS[0]=1? ✓
   → ★ 不动，j-- (j=-1)

i=0 (e)
   map[0]===5 ≠0
   moved=true, j<0 ✓
   → ★ move e 到 c 前面
   anchor: c2[1].el (c)

最终 DOM 操作：
  ① mount h
  ② move b → h 前
  ③ move e → c 前
共 3 次 DOM 操作（1 mount + 2 move），c 和 d 完全不动 ✅
```

##### C. 完整决策树

```
对当前 i：
  ┌─ newIndexToOldIndexMap[i] === 0 ? ──► YES → mount 新节点
  │                                       NO
  ▼
  ┌─ moved (整体是否需要移动) ? ──────► NO → 不动（已在 5.2 patch 完）
  │                                  YES
  ▼
  ┌─ i 是 LIS 中的当前指针 j 吗 ? ─────► YES → 不动，j--
  │                                  NO
  ▼
  → move(nextChild, ..., anchor)
```

##### D. 整体设计哲学

| 优化点 | 体现 |
|--------|------|
| **能不算就不算** | `moved=false` 直接跳过 LIS（EMPTY_ARR） |
| **算最少的活** | LIS 找的是"不动的最长序列"，剩下的才动——DOM 移动次数最优 |
| **DOM 操作友好** | 倒序遍历 + 右邻居作 anchor，`insertBefore` 永远有正确锚点 |
| **职责分离** | 5.2 负责 patch 节点内容；5.4 只负责 DOM 排序 |
| **隐式 else 也是优化** | matched 且未 moved 时连 `if` 都不进，零开销 |

##### E. 一句话总结

> - **`moved` 检测**：遍历旧中间段时，看新位置是否单调不减。一旦出现回退就标 `moved=true`——一个 **O(1) 廉价开关**决定"是否值得花 O(n log n) 算 LIS"。
> - **LIS + 倒序遍历**：LIS 算出**不需要移动的最长序列**；倒序配合右邻居 anchor 保证 `insertBefore` 永远拿到正确锚点。对每个新位置三选一：**新增 / 不动 / 移动**——最终把 DOM 操作压到理论最小。

#### 细节：无 key 兜底匹配的双条件守卫

源码中 5.2 段有这样一段"无 key 兜底"分支：

```typescript
if (prevChild.key != null) {
  newIndex = keyToNewIndexMap.get(prevChild.key)        // ★ 有 key：O(1) 哈希
} else {
  for (j = s2; j <= e2; j++) {                          // ★ 无 key：O(n) 线性扫描
    if (newIndexToOldIndexMap[j - s2] === 0 && isSameVNodeType(prevChild, c2[j])) {
      newIndex = j
      break
    }
  }
}
```

这两个条件缺一不可，分别守护不同的错误。

##### 条件 ①：`newIndexToOldIndexMap[j - s2] === 0`

> **"这个新位置还没被任何旧节点认领过。"**

`newIndexToOldIndexMap` 初始全为 0，每次成功匹配后会把对应位置写成 `i + 1`：

```typescript
newIndexToOldIndexMap[newIndex - s2] = i + 1
//                                     ↑ +1 让"新增节点"的 0 与"旧索引 0"区分
```

`=== 0` 表示"这个新位置目前空着，可以被认领"。

**没有这个条件会发生什么？** —— 一对多错配：

```
旧中间段:  [div, div]     ← 都没 key
新中间段:  [div, div]     ← 都没 key

第一轮：旧 div(0) → j=0 命中 → newIndex=0
第二轮：旧 div(1) → j=0 又命中（无 ① 阻止）→ newIndex=0   ❌
结果：j=1 永远不被认领 → 误判为新增，导致双重挂载 + 旧节点泄漏
```

加上 ① 后第二轮 `map[0]===1`（非 0），自动跳过 j=0 继续 j=1 → 正确匹配。

##### 条件 ②：`isSameVNodeType(prevChild, c2[j])`

> **"旧节点和新节点 type/key 一致，可视为同一节点。"**

```typescript
function isSameVNodeType(n1, n2) {
  return n1.type === n2.type && n1.key === n2.key
}
```

走到这里 `prevChild` 本身没 key，所以判定退化为 "type 相同" + "新节点也没 key"。

**没有这个条件会发生什么？** —— 类型错配：

```
旧中间段:  [div, span]
新中间段:  [span, div]

旧 div → 不判类型直接匹配 c2[0]=span
patch(div, span) → type 不同 → 卸载 div、创建 span
→ 本可以原地复用，现在变成无意义的 DOM 销毁重建
```

##### 整体扫描流程示意

```
新中间段索引（j-s2）:    0     1     2     3
newIndexToOldIndexMap:  [0]   [0]   [0]   [0]   ← 初始全 0
新中间段 vnode:         div   p     div   span

旧节点 prevChild = div （没 key），i = s1
   │
   └─ for j = s2 to e2:
         j=s2+0: map[0]===0 ✓ && sameType(div,div) ✓ → newIndex=s2+0, break
                 然后 map[0] = i+1 → [i+1, 0, 0, 0]

下一个旧节点 prevChild = div （没 key），i = s1+1
   │
   └─ for j = s2 to e2:
         j=s2+0: map[0]≠0  ✗（已认领）→ 跳过
         j=s2+1: map[1]===0 ✓ but sameType(div,p) ✗ → 跳过
         j=s2+2: map[2]===0 ✓ && sameType(div,div) ✓ → newIndex=s2+2, break
                 map[2] = i+1 → [i, 0, i+1, 0]
```

**两个条件配合实现了"按顺序唯一认领、且只认领类型一致的位置"**。

##### 复杂度与性能含义

| 路径 | 单次匹配 | 整体最坏 |
|------|---------|---------|
| 有 key（`keyToNewIndexMap.get`） | **O(1)** | O(n) |
| 无 key（线性扫描 + 双条件守卫） | **O(n)** | **O(n²)** |

这就是 Vue 反复强调 "v-for 务必加 key" 的关键原因之一——不仅是错位复用风险，也是性能退化。

##### 与 Vue 2 `findIdxInOld` 的对比

| | Vue 2 `findIdxInOld` | Vue 3 这段线性扫描 |
|---|---------------------|---------------------|
| 触发条件 | 新节点没 key | 旧节点没 key |
| 扫描方向 | 在**旧数组**里找新节点 | 在**新数组**里找旧节点 |
| 重复占用保护 | `oldCh[idxInOld] = undefined` 占位 | `newIndexToOldIndexMap[j-s2] !== 0` 标记 |
| 类型判定 | `sameVnode`（含 data 存在性等多字段） | `isSameVNodeType`（只看 type + key） |

虽然方向相反、机制略异，但**核心目的一致**：在缺乏 key 时，靠"线性扫描 + 已认领标记"避免错位和重复匹配。

##### 一句话总结

> 这两行是**旧节点没有 key 时的兜底匹配**：
> - 条件 ① 防止一个新位置被多个旧节点重复认领（避免双重挂载）
> - 条件 ② 确保 type/key 一致才视为同一节点（避免类型错配后的无效销毁重建）
>
> 它把有 key 时 O(1) 的哈希查找退化为 **O(n) 的线性扫描**，最坏总复杂度 O(n²)，是不写 key 时性能下降和潜在错配的根源。

---

## 六、最长递增子序列（LIS）：最小化移动次数

### 1. 为什么是 LIS？

`newIndexToOldIndexMap` 记录了"新列表中每个位置对应的旧索引"。我们想知道：**有哪些节点在新旧列表中相对顺序没变？**

答案就是它的**最长递增子序列**——这些节点保持原相对顺序，**不需要移动**；其它节点才需要 move。

### 2. 直观例子

```
旧:  a b c d e f g          索引: 0 1 2 3 4 5 6
新:  a b e c d h f g

中间段（去除头尾相同部分 a b 和 f g）:
旧中间段:  c d e             索引: 2 3 4
新中间段:  e c d h            索引: 0 1 2 3 (相对 s2)

newIndexToOldIndexMap:
  位置 0 (新 e): 旧索引 4 → 存 5 (4+1)
  位置 1 (新 c): 旧索引 2 → 存 3
  位置 2 (新 d): 旧索引 3 → 存 4
  位置 3 (新 h): 找不到 → 0 (新增)

数组 = [5, 3, 4, 0]
忽略 0 → [5, 3, 4] 的最长递增子序列是 [3, 4] → 对应位置 [1, 2]
```

也就是说，新 c 和新 d 不需要移动，只需要：
- 新 h（位置 3）→ 挂载
- 新 e（位置 0）→ 移动

### 3. Vue 3 的 `getSequence` 实现（贪心 + 二分）
<!-- 2 5 3 6 -->
```typescript
function getSequence(arr: number[]): number[] {
  const p = arr.slice()
  const result = [0]
  let i, j, u, v, c
  const len = arr.length
  for (i = 0; i < len; i++) {
    // i = 2；
    const arrI = arr[i] // 3
    if (arrI !== 0) {
      j = result[result.length - 1] // 1
      // 5 < 3 ?
      if (arr[j] < arrI) {
        // p[1] = 0;
        p[i] = j                  // 记录前驱
        result.push(i) // [0, 1]
        continue
      }
      // 二分查找
      u = 0
      v = result.length - 1 // 1
      while (u < v) {
        c = (u + v) >> 1 // 0
        // 2 < 3 ? 
        if (arr[result[c]] < arrI) u = c + 1 // 1
        else v = c
      }
      // 3 < 5 ?
      if (arrI < arr[result[u]]) {
        //  1 > 0 ? 
        if (u > 0) p[i] = result[u - 1] // p[2] = 0
        result[u] = i // result[1] = 2
      }
    }
  }
  // 通过前驱链回溯，得到真正的 LIS（不是简单的二分结果）
  u = result.length
  v = result[u - 1]
  while (u-- > 0) {
    result[u] = v
    v = p[v]
  }
  return result
}
```

时间复杂度 **O(n log n)**，远好于 O(n²) 的朴素 LIS。

#### `getSequence` 详细解析

这段代码看上去短小，实际信息密度极高。它的本质是**贪心 + 二分查找 + 前驱链回溯**的经典 LIS 算法（"耐心排序"思想），并针对 Vue 场景做了一个小定制——**跳过 `arr[i] === 0` 的位置**（表示新增节点，不参与 LIS）。

##### 1) 前置：朴素 LIS 与本算法的差异

朴素 LIS 用 DP `dp[i] = max(dp[j]) + 1`，是 **O(n²)**。

Vue 用的算法核心：**维护一个数组 `result`，使 `result` 中存放的索引对应的值是单调递增的**——`result` 的长度就是 LIS 的长度。每次新元素来时：

- 比 `result` 末尾大 → 直接 push（LIS 变长）
- 否则 → 在 `result` 里二分找到第一个**大于等于** `arrI` 的位置，**用 `i` 替换它**（让这一位的"门槛"更低，方便后续接续更长子序列）

这样得到的 `result` **长度正确**，但里面的值不一定是真正的 LIS。所以最后还需要"**前驱链回溯**"还原真实序列。

##### 2) 变量含义速查

| 变量 | 含义 |
|------|------|
| `arr` | 入参 = `newIndexToOldIndexMap`，元素是"旧索引+1"，0 表示新增 |
| `p` | 前驱链（predecessor）。`p[i]` = 在 LIS 中位于 i 之前的那个元素的索引 |
| `result` | 当前候选 LIS 的**索引序列**（注意：存的是 arr 的下标，不是值！） |
| `i` | 遍历 arr 的当前下标 |
| `arrI` | `arr[i]`，当前元素的值 |
| `j` | `result` 当前末尾的索引 |
| `u / v / c` | 二分查找的左右边界与中点 |

##### 3) 三大阶段逐段拆解

###### 阶段 A：初始化

```typescript
const p = arr.slice()     // 与 arr 等长的"前驱"数组（会逐个改写）
const result = [0]        // 假设第 0 个元素就是 LIS 的开头
```

但注意：如果 `arr[0] === 0`（首位是新增节点），那 `result[0] = 0` 就指向了一个被跳过的位置。**Vue 在算法末尾"前驱链回溯"时不会回溯到这里**（因为新增位置不会出现在 LIS 决策中），但首位作为占位还是存在的——这是个细节坑。

###### 阶段 B：主循环（贪心 + 二分）

```typescript
for (i = 0; i < len; i++) {
  const arrI = arr[i]
  if (arrI !== 0) {                          // ★ 0 = 新增节点，跳过
    j = result[result.length - 1]
    if (arr[j] < arrI) {
      p[i] = j                               // 当前比末尾大 → 接到末尾
      result.push(i)
      continue
    }
    // ★ 否则二分：在 result 里找"第一个 >= arrI"的位置
    u = 0
    v = result.length - 1
    while (u < v) {
      c = (u + v) >> 1
      if (arr[result[c]] < arrI) u = c + 1
      else v = c
    }
    if (arrI < arr[result[u]]) {
      if (u > 0) p[i] = result[u - 1]        // 记录前驱
      result[u] = i                          // 用 i 替换这个位置
    }
  }
}
```

关键点：

- **`if (arr[j] < arrI)`**：当前比末尾大，LIS 可以变长，直接 push。这是大多数顺序数据的热路径。
- **二分查找**：当前比末尾小，要在 `result` 里找一个能"替换"的位置——使 `result` 那个位置的值变小（方便后续更长子序列接续）。
- **`arr[result[c]] < arrI`** 而不是 `<=`：处理"等于"时也偏右，保证求出的是**严格递增** LIS（适合 Vue 场景，每个新位置唯一）。
- **`p[i] = result[u - 1]`**：记录当前 i 在 LIS 中的"前一个"是谁——为最后回溯做准备。
- **`if (arrI < arr[result[u]])` 的守卫**：等值时不替换，避免冗余写入。

###### 深入：`p[i] = result[u - 1]` 到底在做什么？

这一行是整个算法最绕的地方。从"它想表达什么"开始反推：

**`p[i]` 的语义**：

> **"在一条以 `arr[i]` 结尾的递增子序列中，**i 前面那个元素**的下标是谁。"**

**为什么是 `result[u-1]`**？

回顾 `result` 的含义：

> `result[k]` = "目前所有**长度为 k+1** 的递增子序列中，**结尾值最小**的那个，结尾元素的下标。"

现在准备执行 `result[u] = i` —— "**i 成为长度为 u+1 的子序列的最小结尾**"。
那么这条长度为 u+1 的子序列里，**i 的前驱**应该是谁？答案就是**当前 `result[u-1]` 指向的那个下标**，因为：

1. `result[u-1]` 是"目前长度为 u 的子序列的最小结尾"——最适合接上 i
2. 它对应的值 `arr[result[u-1]]` 必然 `< arr[i]`（否则 result[u-1] 早就被更新成更小的了）
3. 接上 i 后整体长度变为 u+1，与"i 处于第 u+1 位"的语义吻合

**`if (u > 0)` 守卫**：

u=0 时 i 直接当 LIS 的第一个元素——**没有前驱**，所以不记 `p[i]`。

**用例子推演**：

假设此刻 `result = [0, X]`，处理 i=2 且进入这个分支：

```
进入条件：arrI = arr[2] < arr[result[1]] = arr[X]
执行：
  u > 0 ✓
  ┌─ p[2] = result[u-1] = result[0] = 0
  │     语义："i=2 在 LIS 中的前驱是下标 0"
  │
  └─ result[1] = i = 2
        语义："长度=2 的子序列的最小结尾，现在改成 i=2"
        result 从 [0, X] 变为 [0, 2]
```

###### 为什么必须靠 `p` 而不能直接看 `result`

很多人会问："`result` 里不是已经存了 LIS 下标吗？为什么还要 `p` 回溯？"

**答案**：`result` 中间的下标在主循环里会被反复"覆盖替换"——这些下标不一定是真正 LIS 链路上的元素，只是当时被"借用"来降低门槛的候选。

反例：

```
arr = [5, 3, 4, 2, 7]

i=0: result=[0]                  arr 值: [5]
i=1: result=[1]                  arr 值: [3]    ← 替换 result[0]，门槛 5→3
i=2: result=[1, 2]               arr 值: [3, 4]  ← push
i=3: result=[3, 2]               arr 值: [2, 4]  ← 替换 result[0]，门槛 3→2
                                                  但 arr[3]=2 在 arr 中位置是 3，
                                                  arr[2]=4 在位置 2，
                                                  原始顺序是 4 在前 2 在后 —— 不是递增！
i=4: result=[3, 2, 4]            arr 值: [2, 4, 7]  ← push
```

i=3 之后直接读 `result = [3, 2]`，对应下标顺序 3→2 在原 arr 中是**倒着的**——这条 result 链不是合法 LIS。

**真正的 LIS 要靠 `p` 回溯**：

```
从 result 末尾开始：v = result[最后] = 4   （对应 arr[4]=7）
p[4] = 2                            v = 2  （对应 arr[2]=4）
p[2] = 1                            v = 1  （对应 arr[1]=3）
p[1] = undefined                    停

真正的 LIS 下标序列：[1, 2, 4]
对应的值：[3, 4, 7] ✅
```

**`p` 在元素被处理的"那个瞬间"就把前驱固化下来**，后续 `result` 怎么被替换都不影响 `p`，所以能反推出真正的 LIS。

###### 配套图示

```
                                   i=2 这一步发生的事
                                   ──────────────────

   result 状态:                      p 数组（前驱链）:
   ┌─────┬─────┐                     ┌────┬────┬────┬─...
   │  0  │  X  │                     │ _  │ _  │ _  │
   └─────┴─────┘                     └────┴────┴────┴─...
   长度=1   长度=2                   (尚未填)
   门槛     门槛
   arr[0]   arr[X]


   来了一个 i=2，arrI=arr[2] < arr[X]
                       │
                       ▼
   要去抢 result[1] 这一格（"长度=2"的位置）
                       │
                       ├─ ① 抢之前先记下"如果我成功了，我的前驱是谁"
                       │     p[2] = result[u-1] = result[0] = 0
                       │     ───────────────────────────────
                       │     语义："i=2 接在长度=1 的最优结尾后面"
                       │
                       └─ ② 正式抢占
                             result[1] = 2
                             ────────────
                             "长度=2 的最优结尾现在是 i=2"

   完成后：
   ┌─────┬─────┐                     ┌────┬────┬────┬─...
   │  0  │  2  │                     │ _  │ _  │ 0  │
   └─────┴─────┘                     └────┴────┴────┴─...
                                          ↑
                                      p[2]=0 永久固化
                                      后续 result 怎么变都不影响
```

###### 一句话总结

> **`p[i] = result[u-1]`** = "**当我把 i 放到 `result[u]` 这一格时（让 i 成为长度=u+1 的子序列的最小结尾），它的前驱就是 `result[u-1]` 此刻指向的下标。**"
>
> 这是一个**"抢位之前先固化前驱关系"** 的操作——后续 `result` 会被反复覆盖，但 `p` 里的前驱关系永久不变，回溯时按链反推就能得到真正的 LIS。

###### 阶段 C：前驱链回溯

```typescript
u = result.length
v = result[u - 1]                  // ★ 从 LIS 最后一个开始
while (u-- > 0) {
  result[u] = v
  v = p[v]
}
return result
```

为什么需要这一步？

二分阶段为了"压低门槛"会**替换 `result` 中间的位置**，所以 `result` 里中间的索引可能不是真正 LIS 中的一员，只是当时被借用做候选。但**结尾位置 `result[result.length-1]` 一定是 LIS 真正的最后一个元素**。

利用 `p`（前驱链）从后往前追溯，把真正的 LIS 索引依次写回 `result`：

```
v = result[末尾]      ← 真正的最后一个
v = p[v]              ← 它的前一个
v = p[v]              ← 再前一个
...
```

##### 4) 完整走例：`arr = [5, 3, 4, 2, 0]`（来自 Step 5 的例子）

> 旧:[a,b,c,d,e] 新:[e,c,d,b,h] → newIndexToOldIndexMap = [5,3,4,2,0]

| i | arrI | 操作 | result（存 arr 下标） | result 对应的值 | p 的变化 |
|---|------|------|----------------------|----------------|----------|
| 0 | 5 | 初始化 `result=[0]` | `[0]` | `[5]` | `p=[5,3,4,2,0]`（slice 副本） |
| 1 | 3 | `arr[末尾=0]=5 ≥ 3`，二分得 u=0；`arrI=3 < arr[result[0]]=5` → 执行 **`result[0] = i = 1`**；u=0 不记前驱 | `[1]` | `[3]` | p[1] 不变 |
| 2 | 4 | `arr[末尾=1]=3 < 4` → push：**`p[2] = j = 1`** 然后 **`result.push(2)`** | `[1, 2]` | `[3, 4]` | p[2]=1 |
| 3 | 2 | `arr[末尾=2]=4 ≥ 2`，二分得 u=0；`arrI=2 < arr[result[0]]=3` → 执行 **`result[0] = i = 3`**；u=0 不记前驱 | `[3, 2]` | `[2, 4]` | p[3] 不变 |
| 4 | 0 | **跳过**（arrI===0，新增节点） | `[3, 2]` | `[2, 4]` | 不变 |

主循环结束：
- `result = [3, 2]`
- `result` 中的值 = `arr[3]=2, arr[2]=4`（但这是被替换后的状态，不是真正 LIS！）
- `p = [_, _, 1, _, _]`（只有 p[2]=1 有意义）

**回溯阶段**：

```
u = 2 (length), v = result[1] = 2
u-- → u=1: result[1] = v=2;   v = p[2] = 1
u-- → u=0: result[0] = v=1;   v = p[1] = undefined (不再用)
```

最终 `result = [1, 2]`，对应 `arr` 中的 `[arr[1]=3, arr[2]=4]` —— 这就是真正的 LIS 索引序列。

回到原数据：`[1, 2]` 即新中间段的位置 1 和 2 → 节点 **c 和 d** 不需要移动 ✅（与前文 Step 5 例子吻合）

##### 5) 为什么 `arr[i] === 0` 要跳过

Vue 把"新增节点"在 `newIndexToOldIndexMap` 里编码为 0。新增节点在 5.4 阶段会走 mount 分支（不走 move），所以**它们不应该参与"是否要移动"的判定**。

如果不跳过，0 会被当作一个极小值塞进二分，破坏 LIS 单调性，让算法把"新增位置"误判为"应该不动的位置"——后续 move 判定就乱套了。

##### 6) 为什么用 `arr[result[c]] < arrI` 而不是 `<=`

`<` 求出来的是**严格递增**子序列。`<=` 会得到非严格递增（允许相等）。

Vue 场景下 `newIndexToOldIndexMap` 的元素（"旧索引+1"）**两两不同**（除了多个 0 表示新增）—— 因为每个旧节点只能对应一个新位置。所以严格递增和非严格递增的结果一样，用 `<` 没问题且效率更高（避免等值时多余的替换）。

##### 7) 复杂度分析

| 操作 | 单次代价 | 总代价 |
|------|---------|--------|
| 外层 for 遍历 | — | O(n) |
| 每次内部"接末尾" | O(1) | 平均 O(n) |
| 每次内部二分 | O(log n) | 最坏 O(n log n) |
| 回溯前驱链 | O(n) | O(n) |
| **总计** | | **O(n log n)** |

朴素 DP 是 O(n²)，对 1 万节点的列表差距是 100 倍以上。

##### 8) 一句话总结

> Vue 3 的 `getSequence` 是经典"耐心排序 LIS"的工程化实现：
> - **主循环**：用单调数组 `result` + 二分快速求出 LIS **长度**
> - **前驱链 `p`**：记录每个元素在 LIS 中的"前一个"
> - **回溯**：从末尾顺前驱链反推出**真实的 LIS 索引序列**
> - **特殊处理**：跳过 `arr[i] === 0`（新增节点），不参与移动判定
>
> 输入 `newIndexToOldIndexMap`，输出"哪些新位置上的节点不需要移动"——这是 5.4 阶段决定 `move()` vs 不动的依据。

### 4. 为什么从右往左遍历

```typescript
for (i = toBePatched - 1; i >= 0; i--) {
  // ...
  const anchor = nextIndex + 1 < l2 ? c2[nextIndex + 1].el : parentAnchor
  // 用"已经处理过的右边节点"作 anchor 来 insertBefore
}
```

`insertBefore(node, anchor)` 需要一个**已经在 DOM 里正确位置的右邻居**作锚点。从右往左，每次处理的当前节点的右边都已经就位。

---

## 七、静态提升 / 事件缓存 / 内联组件

### 1. 静态提升（Static Hoisting）

```vue
<div>
  <p>Static</p>
  <p>{{ msg }}</p>
</div>
```

```javascript
// 提升到模块作用域，整个生命周期只创建一次
const _hoisted_1 = createElementVNode("p", null, "Static", -1 /* HOISTED */)

export function render() {
  return openBlock(), createElementBlock("div", null, [
    _hoisted_1,            // ★ 每次 render 都引用同一个 vnode
    createElementVNode("p", null, toDisplayString(_ctx.msg), 1)
  ])
}
```

`patch` 看到 `n1 === n2` 直接 return，省掉所有比较。

### 2. 事件缓存（cacheHandlers）

```vue
<button @click="handleClick">+</button>
```

```javascript
export function render(_ctx, _cache) {
  return openBlock(), createElementBlock("button", {
    onClick: _cache[0] || (_cache[0] = (...args) => _ctx.handleClick(...args))
    //       ↑ 第一次执行后写入 _cache，后续都用同一个函数引用
  })
}
```

意义：避免每次 render 都生成新函数，**props 比较时 `oldProps.onClick === newProps.onClick`** 一致，跳过 patch。

### 3. PatchFlags.HOISTED = -1

提升的静态节点用 `-1` 作 patchFlag，`patch` 看到这个标记可走快速路径。

---

## 八、完整示例：v-for 列表重排

### 模板

```vue
<div>
  <Item v-for="item in list" :key="item.id" :data="item" />
</div>
```

### 旧 list：`[1, 2, 3, 4, 5]`
### 新 list：`[1, 2, 4, 5, 3]`（把 3 移到末尾）

进入 `patchKeyedChildren`：

#### Step 1：头同步
- 新旧 `[0] = 1`，patch，`i=1`
- 新旧 `[1] = 2`，patch，`i=2`
- 新 `[2]=4`，旧 `[2]=3` → 不同，停止

#### Step 2：尾同步
- 新旧 `[最后] = 3` ❌ 旧最后是 5，新最后是 3 → 不同，停止

此时 `i=2, e1=4, e2=4`

#### Step 3/4：略，i ≤ e1 且 i ≤ e2

#### Step 5：未知序列

- s1=s2=2, toBePatched=3 (位置 2,3,4)
- `keyToNewIndexMap = { 4→2, 5→3, 3→4 }`
- 遍历旧 [3,4,5]：
  - 旧 3 (i=2)：newIndex=4 → newIndexToOldIndexMap[2]=3, maxNewIndexSoFar=4
  - 旧 4 (i=3)：newIndex=2 → newIndexToOldIndexMap[0]=4, 2<4 → `moved=true`
  - 旧 5 (i=4)：newIndex=3 → newIndexToOldIndexMap[1]=5, 3<4 → moved=true
- `newIndexToOldIndexMap = [4, 5, 3]`
- LIS = `getSequence([4,5,3])` → `[0, 1]`（对应值 4,5）

#### Step 5.4：从右往左遍历
- i=2（新位置 4，节点 3）：在 LIS 中？ `2 !== 1` → **move** 节点 3 到末尾
- i=1（新位置 3，节点 5）：在 LIS 中？ `1 === 1` → 不移动，j--
- i=0（新位置 2，节点 4）：在 LIS 中？ `0 === 0` → 不移动

**结论**：只移动了 1 个节点（节点 3 到末尾），4 和 5 保持原位。

---

## 九、Vue 2 vs Vue 3 Diff 对照表

| 维度 | Vue 2 | Vue 3 |
|------|-------|-------|
| 算法 | 双端比较 + key map fallback | 头尾预处理 + key map + **LIS 最小移动** |
| 复杂度 | O(n) 但移动次数偏多 | O(n log n)，**移动次数最优** |
| 静态节点 | 编译标记 isStatic，运行时仍要 walk | **提升到模块作用域**，运行时直接复用引用 |
| 节点 diff 精度 | 全字段比对 class/style/attrs | **patchFlag 按位精准 patch** |
| 跨层级跳过 | 无 | **block + dynamicChildren** |
| 事件 | 每次新建 listener | **cacheHandlers** 复用函数引用 |
| Fragment | 不支持 | 原生支持，带 patchFlag |
| 编译期参与度 | 弱 | **强**：编译器和运行时是一对协作的"程序" |

---

## 十、一句话总结

> Vue 3 Diff 的根本变化不是"diff 算法更快了"，而是"diff 之前的信息更多了"——
> 编译器把**哪些是动态的、哪些是静态的、动态的具体是什么**通过 `patchFlag` 和 `dynamicChildren` 告诉运行时；
> 运行时只对真正会变的部分做工，并用**最长递增子序列**保证乱序时移动次数最少。
> 这是一次**编译期 + 运行时协同优化**的范式升级。
