# CSS 与工程化

> 从根级《前端知识点.md》按主题拆分而来。

## CSS BFC 与常见布局机制

### 一、什么是 BFC

BFC（Block Formatting Context，块级格式化上下文）可以理解为：

> 一个独立的布局区域，内部元素如何排版，不会直接影响外部。

---

### 二、哪些情况会触发 BFC

常见触发方式：

- 根元素
- `float` 不为 `none`
- `position: absolute` 或 `fixed`
- `display: inline-block`
- `display: flow-root`
- `overflow: hidden/auto/scroll`

现代项目里，最直观的显式写法通常是：

```css
.container {
  display: flow-root;
}
```

---

### 三、BFC 的典型作用

#### 1. 清除浮动

父元素包不住浮动子元素时，可以让父元素形成 BFC。

```css
.parent {
  overflow: hidden;
}
```

或者更推荐：

```css
.parent {
  display: flow-root;
}
```

#### 2. 阻止外边距重叠

普通文档流中的相邻块级元素，垂直 `margin` 可能重叠。  
形成不同 BFC 后，可以隔离这种影响。

#### 3. 避免文字环绕浮动

一个普通块盒遇到浮动元素时，可能发生环绕；形成 BFC 后会按独立区域布局。

---

### 四、Flex 布局高频点

#### 1. 主轴和交叉轴

```css
.box {
  display: flex;
  flex-direction: row;
}
```

- 主轴：`row` 时是水平方向
- 交叉轴：与主轴垂直

#### 2. 常见容器属性

- `justify-content`：主轴对齐
- `align-items`：单行交叉轴对齐
- `align-content`：多行交叉轴对齐
- `flex-wrap`：是否换行

#### 3. 常见子项属性

- `flex-grow`：剩余空间分配比例
- `flex-shrink`：空间不足时压缩比例
- `flex-basis`：主轴基础尺寸

#### 4. `flex: 1` 是什么

常见可近似理解为：

```css
flex: 1 1 0%;
```

意思是：

- 可以增长
- 可以收缩
- 基础尺寸从 `0` 开始参与分配

---

### 五、Grid 的定位

如果说 Flex 更适合**一维布局**，那么 Grid 更适合**二维布局**。

例如：

- 仪表盘卡片区
- 宫格布局
- 复杂后台页面区域分布

```css
.layout {
  display: grid;
  grid-template-columns: 240px 1fr;
  grid-template-rows: 64px 1fr;
}
```

---

### 六、面试速答

**Q1：BFC 有什么用？**  
最经典的是清除浮动、阻止 margin 重叠、避免浮动影响普通布局。

**Q2：`justify-content` 和 `align-items` 的区别？**  
前者管主轴，后者管交叉轴。

**Q3：什么时候用 Flex，什么时候用 Grid？**  
一维排列优先 Flex，二维区域布局优先 Grid。

---

---

## 前端模块化

### 一、为什么需要模块化

早期前端代码通常直接挂在全局作用域：

```javascript
var count = 0
function add() {
  count++
}
```

问题很明显：

1. 全局变量容易污染
2. 命名冲突概率高
3. 依赖关系不清晰
4. 代码复用、维护、测试都困难

模块化的核心目标就是：

- 隔离作用域
- 管理依赖
- 提高复用性
- 提高可维护性

---

### 二、常见模块化方案演进

前端模块化大致经历了这些阶段：

1. 全局函数模式
2. 命名空间模式
3. IIFE 立即执行函数
4. CommonJS
5. AMD / CMD
6. ES Module

---

### 三、IIFE 为什么是早期模块化方案

IIFE（Immediately Invoked Function Expression）通过函数作用域隔离变量：

```javascript
const counter = (function () {
  let count = 0

  return {
    add() {
      count++
    },
    getCount() {
      return count
    }
  }
})()
```

优点：

- 避免变量泄漏到全局
- 可以暴露有限 API

缺点：

- 依赖关系还是不够清晰
- 模块加载顺序要手动控制
- 不适合大型工程

---

### 四、CommonJS

#### 1. 基本写法

```javascript
// math.js
function add(a, b) {
  return a + b
}

module.exports = {
  add
}
```

```javascript
// app.js
const math = require('./math')
console.log(math.add(1, 2))
```

#### 2. 核心特点

- 使用 `require()` 导入
- 使用 `module.exports` / `exports` 导出
- **运行时加载**
- 输出的是**值的拷贝引用语义对象**

#### 3. 适合场景

最典型的是 Node.js 服务端生态。

#### 4. 局限

- 更适合服务端，不天然适合浏览器
- 同步加载思路不适合浏览器首屏资源加载

---

### 五、AMD 和 CMD

这两个现在更多是历史知识点，但面试偶尔会问。

#### AMD

代表：`RequireJS`

特点：

- **依赖前置**
- 推崇提前声明依赖

```javascript
define(['./math'], function (math) {
  return {
    result: math.add(1, 2)
  }
})
```

#### CMD

代表：`SeaJS`

特点：

- **依赖就近**
- 用到时再 `require`

```javascript
define(function (require, exports, module) {
  const math = require('./math')
  exports.result = math.add(1, 2)
})
```

#### 一句话区别

> AMD 依赖前置，CMD 依赖就近。

现代工程里，这两种方案基本都被 ES Module 和打包工具取代。

---

### 六、ES Module（ESM）

#### 1. 基本写法

```javascript
// math.js
export function add(a, b) {
  return a + b
}

export const PI = 3.14
```

```javascript
// app.js
import { add, PI } from './math.js'

console.log(add(1, 2))
console.log(PI)
```

#### 2. 默认导出

```javascript
// user.js
export default function getUser() {
  return { name: 'Tom' }
}
```

```javascript
import getUser from './user.js'
```

#### 3. 核心特点

- `import` / `export` 语法
- **编译时确定依赖关系**
- 支持静态分析
- 导出的是**实时绑定（live binding）**
- 天然适合 `Tree Shaking`

---

### 七、CommonJS 和 ES Module 的区别

#### 1. 加载时机不同

- CommonJS：运行时加载
- ES Module：编译时静态分析

#### 2. 导出机制不同

- CommonJS：导出一个对象
- ES Module：导出接口绑定

#### 3. 值是否“联动”

CommonJS 更接近导出当前结果：

```javascript
// counter.js
let count = 0
setInterval(() => count++, 1000)
module.exports = { count }
```

这里外部拿到的通常是导出对象上的当前属性值语义，不具备 ESM 那种标准化 live binding 语义。

而 ESM 的导出绑定会随源模块值变化而反映：

```javascript
// counter.js
export let count = 0
setInterval(() => count++, 1000)
```

```javascript
import { count } from './counter.js'
```

#### 4. `this` 不同

- CommonJS 顶层有自己的模块上下文
- ESM 顶层 `this` 是 `undefined`

#### 5. 循环依赖处理方式不同

ESM 因为是静态结构，循环依赖处理通常更可预测；CommonJS 更依赖运行时执行顺序。

---

### 八、`export default` 和命名导出的区别

#### 命名导出

```javascript
export const a = 1
export function foo() {}
```

导入时必须按名字取：

```javascript
import { a, foo } from './mod.js'
```

#### 默认导出

```javascript
export default function () {}
```

导入时名字可以自定义：

```javascript
import myFn from './mod.js'
```

#### 实战建议

- 工具函数库、公共常量：优先命名导出
- 一个模块只强调一个核心主体时：可用默认导出

---

### 九、动态导入 `import()`

动态导入是运行时按需加载模块：

```javascript
button.addEventListener('click', async () => {
  const module = await import('./dialog.js')
  module.openDialog()
})
```

作用：

- 路由懒加载
- 组件按需加载
- 降低首屏包体积

这和静态 `import` 的区别是：

- 静态 `import`：编译阶段就确定依赖
- 动态 `import()`：运行时才加载

---

### 十、什么是 Tree Shaking

Tree Shaking 指的是：

> 在打包阶段移除**没有被使用的导出代码**。

它依赖的关键前提就是：**模块依赖关系必须可静态分析**。  
所以 Tree Shaking 更适合 ES Module，不适合 CommonJS。

例如：

```javascript
// utils.js
export function a() {}
export function b() {}
```

```javascript
import { a } from './utils.js'
```

如果构建工具足够智能，`b` 就可能被移除。

#### 注意

如果模块里有副作用，Tree Shaking 就不能简单删除：

```javascript
console.log('side effect')
export const a = 1
```

---

### 十一、循环依赖

#### 1. 什么是循环依赖

模块 A 依赖模块 B，模块 B 又依赖模块 A。

```javascript
// a.js
import { b } from './b.js'
export const a = 'a'
console.log(b)
```

```javascript
// b.js
import { a } from './a.js'
export const b = 'b'
console.log(a)
```

#### 2. 为什么危险

- 容易出现未初始化值
- 容易出现 `undefined`
- 行为依赖执行顺序，排查困难

#### 3. 如何规避

1. 拆分公共依赖到第三个模块
2. 减少模块之间双向引用
3. 避免在模块顶层立即执行强耦合逻辑

---

### 十二、浏览器如何使用 ESM

浏览器中可以直接写：

```html
<script type="module" src="./app.js"></script>
```

特点：

- 会按模块方式解析
- 默认延迟执行，类似 `defer`
- 每个模块有独立作用域
- 可使用 `import` / `export`

也可以：

```html
<script type="module">
  import { add } from './math.js'
  console.log(add(1, 2))
</script>
```

---

### 十三、工程化里的模块化

现代前端项目里，模块化通常和构建工具配合：

- Vite
- Webpack
- Rollup
- esbuild

它们做的事情包括：

1. 解析依赖图
2. 转换模块格式
3. 代码分割
4. 按需加载
5. Tree Shaking
6. 打包压缩

所以今天说“前端模块化”，通常已经不只是语法问题，而是**语法 + 构建 + 运行时加载策略**的组合。

---

### 十四、面试速答

**Q1：CommonJS 和 ES Module 最大区别是什么？**  
最核心的是 CommonJS 是运行时加载，ES Module 是编译时静态分析；因此 ESM 更适合 Tree Shaking 和现代前端构建。

**Q2：为什么 Tree Shaking 更适合 ES Module？**  
因为 ESM 的依赖关系在编译阶段就能确定，构建工具能知道哪些导出没被使用。

**Q3：`export default` 和命名导出怎么选？**  
公共工具、常量、多个导出成员优先命名导出；一个模块只有一个核心主体时可用默认导出。

**Q4：动态导入有什么价值？**  
核心价值是按需加载，减少首屏包体积。

**Q5：AMD、CMD 现在还有必要学吗？**  
更多是作为历史演进和面试知识点了解，现代项目主流还是 ESM + 构建工具。

---

### 十五、一句话总结

前端模块化的本质，是把代码从“全局散装脚本”演进为“有边界、可复用、可分析、可按需加载”的依赖系统，而现代主流方案就是 **ES Module + 构建工具**。

---
