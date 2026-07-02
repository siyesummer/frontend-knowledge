# JavaScript 基础

> 从根级《前端知识点.md》按主题拆分而来。

## JavaScript 原型与原型链

### 一、为什么需要原型

JavaScript 是基于原型（prototype-based）的语言，而非传统的基于类（class-based）的语言。原型机制是 JS 实现**继承**和**属性共享**的核心方式。

通过原型，可以让多个实例共享同一份方法/属性，避免每个实例都创建一份副本，从而节省内存。

```javascript
function Person(name) {
  this.name = name;
}
Person.prototype.sayHi = function () {
  console.log("Hi, I'm " + this.name);
};

const p1 = new Person("Tom");
const p2 = new Person("Jerry");
console.log(p1.sayHi === p2.sayHi); // true，方法共享
```

---

### 二、三个核心概念

理解原型链，必须先理清三个属性/概念：

| 概念 | 属于谁 | 含义 |
|------|--------|------|
| `prototype` | **函数**独有 | 函数作为构造函数时，其实例的原型对象 |
| `__proto__`（即 `[[Prototype]]`） | **所有对象**都有 | 指向创建该对象的构造函数的 `prototype` |
| `constructor` | 原型对象上 | 指回构造函数本身 |

#### 三者关系图（含 Function / Object 完整链路）

```
   ┌────────────────────────────────────────────────────────────────────────┐
   │                                                                        │
   │   ┌──────────────────────────┐                                         │
   │   │   Function.prototype     │◄────────┐                               │
   │   │   (所有函数的原型)        │         │                               │
   │   │   constructor ──────────►│──► Function                             │
   │   │   __proto__  ────────────┼──┐      │                               │
   │   └──────────────▲───────────┘  │      │ __proto__                     │
   │                  │              │      │                               │
   │                  │ __proto__    │      │                               │
   │     ┌────────────┼──────────────┼──────┼─────────────┐                 │
   │     │            │              │      │             │                 │
   │ ┌───┴────┐   ┌───┴────┐   ┌─────┼──┴───┐   ┌─────┴────┐               │
   │ │ Person │   │ Object │   │     │Function│   │ 其他函数 │              │
   │ │(构造器)│   │(构造器)│   │     │(构造器)│   │          │              │
   │ └───┬────┘   └───┬────┘   └─────┼────────┘   └──────────┘              │
   │     │ prototype  │ prototype    │                                      │
   │     ▼            ▼              │                                      │
   │ ┌─────────────┐  │              │                                      │
   │ │Person.proto-│  │              │                                      │
   │ │type         │  │              │                                      │
   │ │ constructor │──┼──► Person    │                                      │
   │ │ sayHi: fn   │  │              │                                      │
   │ │ __proto__ ──┼──┼──────┐       │                                      │
   │ └─────▲───────┘  │      │       │                                      │
   │       │__proto__ │      ▼       ▼                                      │
   │ ┌─────┴───────┐  │   ┌──────────────────────┐                          │
   │ │  p1 (实例)  │  │   │  Object.prototype    │◄─────────────────────────┘
   │ │  name:'Tom' │  │   │  toString / hasOwn.. │   (Function.prototype 的
   │ └─────────────┘  │   │  constructor ───────►│──► Object   __proto__ 指向)
   │                  │   │  __proto__ ─────────►│──► null  ← 原型链尽头
   │                  │   └──────────▲───────────┘
   │                  │              │
   │                  └──────────────┘ (Object.prototype 也是 Object 的 prototype)
   │
   └────────────────────────────────────────────────────────────────────────┘
```

> 关键补全：**`Function.prototype.__proto__ === Object.prototype`**
> 因为 `Function.prototype` 本身也是一个普通对象（其实是一个可调用的函数对象），作为对象它必须挂在 `Object.prototype` 下，所有原型链最终都汇入 `Object.prototype`。

#### 关键链路文字版

**实例 → 原型链尽头**：
```
p1 ──▶ Person.prototype ──▶ Object.prototype ──▶ null
```

**函数 → 原型链尽头**（函数本身作为对象）：
```
Person   ──▶ Function.prototype ──▶ Object.prototype ──▶ null
Object   ──▶ Function.prototype ──▶ Object.prototype ──▶ null
Function ──▶ Function.prototype ──▶ Object.prototype ──▶ null   (Function 自指 Function.prototype)
```

代码验证：

```javascript
// === 实例侧 ===
p1.__proto__ === Person.prototype;                       // true
Person.prototype.constructor === Person;                 // true
p1.constructor === Person;                               // true（沿原型链查找到的）
Person.prototype.__proto__ === Object.prototype;         // true
Object.prototype.__proto__ === null;                     // true ← 原型链尽头

// === 函数侧（函数也是对象） ===
Person.__proto__ === Function.prototype;                 // true（所有函数都是 Function 的实例）
Function.__proto__ === Function.prototype;               // true ← 特殊：自己是自己的实例
Object.__proto__ === Function.prototype;                 // true（Object 也是构造函数）
Function.prototype.__proto__ === Object.prototype;       // true ★ 关键的一环：函数原型也是对象

// === 构造关系 ===
Person instanceof Function;                              // true
Person instanceof Object;                                // true
p1 instanceof Person;                                    // true
p1 instanceof Object;                                    // true
```

#### 一句话总结这张图

> 万物皆对象，对象都有 `__proto__` 通向 `Object.prototype`；函数都是 `Function` 的实例，`__proto__` 指向 `Function.prototype`；而 `Function.prototype` 自己也是一个对象，`__proto__` 同样指向 `Object.prototype`——所有链最终都汇入 `Object.prototype`，再到 `null` 终止。

---

### 三、原型链（Prototype Chain）

当访问对象的属性时，JS 引擎会：

1. 先在对象**自身**查找；
2. 找不到则去 `__proto__` 指向的原型对象上找；
3. 仍找不到继续沿 `__proto__` 向上查找；
4. 直到 `Object.prototype`，其 `__proto__` 为 `null`，链结束；
5. 若仍未找到，返回 `undefined`。

这条由 `__proto__` 串联起来的链就是**原型链**。

```javascript
p1.toString();
// 1. p1 自身无 toString
// 2. Person.prototype 无 toString
// 3. Object.prototype 有 toString → 调用
```

#### 完整链路示意

```
p1 ──▶ Person.prototype ──▶ Object.prototype ──▶ null
```

---

### 四、函数本身也是对象

函数是 `Function` 的实例，所以函数也有 `__proto__`：

```javascript
Person.__proto__ === Function.prototype;            // true
Function.prototype.__proto__ === Object.prototype;  // true
Object.prototype.__proto__ === null;                // true
```

**特殊关系**：

```javascript
Function.__proto__ === Function.prototype;  // true（Function 自己是自己的实例）
Object.__proto__ === Function.prototype;    // true（Object 也是个函数）
```

---

### 五、`new` 操作符做了什么

理解 `new` 有助于理解原型如何被建立：

```javascript
function myNew(Constructor, ...args) {
  // 1. 创建一个新对象，其 __proto__ 指向构造函数的 prototype
  const obj = Object.create(Constructor.prototype);
  // 2. 执行构造函数，this 指向新对象
  const result = Constructor.apply(obj, args);
  // 3. 若构造函数返回的是对象则用之，否则返回新对象
  return result instanceof Object ? result : obj;
}
```

---

### 六、基于原型实现继承

#### 1. 原型链继承（基础但有缺陷）

```javascript
function Parent() { this.list = [1, 2]; }
function Child() {}
Child.prototype = new Parent();
// 缺陷：引用类型属性被所有子实例共享
```

#### 2. 组合继承（最常用的经典方案）

```javascript
function Parent(name) { this.name = name; }
Parent.prototype.say = function () { console.log(this.name); };

function Child(name, age) {
  Parent.call(this, name);   // 借用构造函数（继承属性）
  this.age = age;
}
Child.prototype = Object.create(Parent.prototype); // 继承方法
Child.prototype.constructor = Child;               // 修复 constructor
```

#### 补充：修改 `Child.prototype` 会不会影响 `Parent.prototype`

**正常不会。**

```javascript
Child.prototype = Object.create(Parent.prototype);
```

这行代码创建的是一个**新对象**，然后让这个新对象的 `__proto__` 指向 `Parent.prototype`。

所以关系不是：

```javascript
Child.prototype === Parent.prototype // false
```

而是：

```javascript
Child.prototype.__proto__ === Parent.prototype // true
```

也就是说：

- `Child.prototype` 和 `Parent.prototype` **不是同一个对象**
- 给 `Child.prototype` 新增或重写方法，**不会影响** `Parent.prototype`

例如：

```javascript
Child.prototype.run = function () {};
Child.prototype.say = function () { console.log('child'); };
```

这里只会改 `Child.prototype` 自己，不会改到 `Parent.prototype`。

#### 什么时候会影响 `Parent.prototype`

#### 1. 直接修改 `Parent.prototype`

```javascript
Parent.prototype.say = function () { console.log('parent changed'); };
```

这当然会影响所有沿原型链访问到它的子类型实例。

#### 2. 修改共享引用类型属性的内部内容

```javascript
Parent.prototype.config = { theme: 'dark' };
Child.prototype.config.theme = 'light';

console.log(Parent.prototype.config.theme); // light
```

这里虽然没有给 `Parent.prototype` 重新赋值，但 `config` 指向的是**同一个对象**，所以改内部属性会互相影响。

#### 一句话总结

> `Object.create(Parent.prototype)` 建立的是“原型链关联”，不是“同一个对象共享”。  
> 改 `Child.prototype` 本身通常不会影响 `Parent.prototype`；只有直接改 `Parent.prototype`，或者改到它上面的共享引用值，才会影响。

#### 3. ES6 `class extends`（语法糖，本质仍是原型）

```javascript
class Parent {
  constructor(name) { this.name = name; }
  say() { console.log(this.name); }
}
class Child extends Parent {
  constructor(name, age) {
    super(name);
    this.age = age;
  }
}
// 等价于上面的组合继承 + Child.__proto__ === Parent（静态继承）
```

---

### 七、常用 API

| API | 作用 |
|------|------|
| `Object.getPrototypeOf(obj)` | 标准方式获取 `__proto__` |
| `Object.setPrototypeOf(obj, proto)` | 设置原型（性能差，慎用） |
| `Object.create(proto)` | 以指定原型创建新对象 |
| `obj.hasOwnProperty(key)` | 仅判断自身属性，不查原型链 |
| `key in obj` | 会查原型链 |
| `obj instanceof Constructor` | 沿原型链查找 `Constructor.prototype` |

```javascript
function isInstanceOf(obj, Ctor) {
  let proto = Object.getPrototypeOf(obj);
  while (proto) {
    if (proto === Ctor.prototype) return true;
    proto = Object.getPrototypeOf(proto);
  }
  return false;
}
```

---

### 八、易错点与注意事项

1. **`__proto__` 是非标准属性**，生产代码请使用 `Object.getPrototypeOf` / `Object.setPrototypeOf`。
2. **箭头函数没有 `prototype`**，不能作为构造函数使用。
3. **修改原型会影响所有实例**，包括已经创建的实例（因为引用关系）。
4. **`constructor` 可被覆盖**：手动赋值 `Child.prototype = new Parent()` 后需修复。
5. **不要随意修改内置原型**（如 `Array.prototype`），会污染全局。
6. **`Object.create(null)`** 可创建无原型的纯净对象（常用于字典）。

---

### 九、面试高频问题速答

**Q1：`prototype` 和 `__proto__` 的区别？**
`prototype` 是函数的属性，指向实例的原型对象；`__proto__` 是对象的属性，指向其构造函数的 `prototype`。即：`实例.__proto__ === 构造函数.prototype`。

**Q2：原型链的尽头是什么？**
`Object.prototype.__proto__ === null`。

**Q3：`class` 是否破坏了原型机制？**
没有。`class` 只是语法糖，底层仍基于原型链；`extends` 同时设置了实例原型链和构造函数的静态原型链。

**Q4：如何判断属性来自实例还是原型？**
`obj.hasOwnProperty(key)` 为 `true` 表示自身属性；否则可能在原型链上。

---

---

## JavaScript 作用域

### 一、什么是作用域

**作用域（Scope）** 是程序源代码中定义变量的**区域**，它决定了变量与函数的**可访问性（可见性）**与**生命周期**。

简而言之：**作用域回答"在哪里、什么时候可以访问这个变量"**。

JS 引擎通过作用域决定：
- 变量该在哪里寻找（标识符解析）
- 同名变量该取哪一个（就近原则）
- 变量何时被销毁（脱离作用域后被 GC）

---

### 二、作用域的种类

#### 1. 全局作用域（Global Scope）

代码最外层定义的变量，整个程序都能访问。

```javascript
var a = 1;          // 浏览器中会挂到 window
let b = 2;          // 全局，但不挂到 window
function foo() { console.log(a, b); }
```

#### 2. 函数作用域（Function Scope）

`function` 内部定义的变量，只能在该函数内访问。`var` 声明只识别函数作用域。

```javascript
function fn() {
  var x = 10;
  console.log(x); // 10
}
console.log(typeof x); // 'undefined'，外部访问不到
```

#### 3. 块级作用域（Block Scope，ES6 新增）

由 `{}` 包裹的代码块（`if`/`for`/`while`/独立 `{}` 等）。**只有 `let` 和 `const` 受块级约束**。

```javascript
{
  let y = 20;
  const z = 30;
  var w = 40;
}
console.log(typeof y); // 'undefined'，let 被块限制
console.log(typeof z); // 'undefined'，const 被块限制
console.log(w);        // 40，var 穿透块级
```

#### 4. 模块作用域（Module Scope）

ES6 模块（`<script type="module">` 或 `.mjs`）中，顶层变量默认是模块私有的，不会污染全局。

```javascript
// module.js
let secret = 'hi';   // 仅本模块可见，需 export 才能被其他模块访问
```

#### 5. 词法作用域（Lexical Scope）

JS 采用**词法作用域**（也叫静态作用域），即**作用域在代码书写时就已经确定**，与函数在哪里调用无关，只与函数在哪里**定义**有关。

```javascript
var value = 1;
function foo() { console.log(value); }
function bar() {
  var value = 2;
  foo();   // 1（foo 定义时外层是全局，不是 bar）
}
bar();
```

---

### 三、作用域链（Scope Chain）

当查找变量时，JS 引擎从**当前作用域**开始，找不到就沿着外层作用域**向上查找**，直到全局作用域。这条嵌套的查找路径就是**作用域链**。

```javascript
var a = 1;
function outer() {
  var b = 2;
  function inner() {
    var c = 3;
    console.log(a, b, c); // 1 2 3
    // 查找路径：inner → outer → global
  }
  inner();
}
outer();
```

**作用域链 vs 原型链**：
- 作用域链：查找**变量**，由代码嵌套结构决定，编译期形成
- 原型链：查找**对象属性**，由 `__proto__` 决定，运行期可变

---

### 四、变量提升（Hoisting）

JS 编译阶段会把声明"提升"到作用域顶部。

```javascript
console.log(a);   // undefined（不是报错！）
var a = 1;

// 等价于：
var a;
console.log(a);
a = 1;

foo();            // OK，函数声明整体提升
function foo() { console.log('hi'); }

bar();            // TypeError: bar is not a function
var bar = function () {};  // 函数表达式只提升变量名
```

---

### 五、闭包（Closure）

**闭包** = 函数 + 其定义时所处的词法作用域。当内层函数被带出原本的作用域执行时，它仍能访问外层变量。

```javascript
function makeCounter() {
  let count = 0;
  return () => ++count;
}
const counter = makeCounter();
counter(); // 1
counter(); // 2  ← count 不会被销毁，被闭包"捕获"
```

闭包让作用域跨越了生命周期，是 React Hooks、防抖节流、模块化等的底层基石。

---

---

## var 与 let 的详细比较

| 维度 | `var` | `let` |
|------|-------|-------|
| 作用域 | **函数作用域** | **块级作用域** |
| 变量提升 | ✅ 提升且初始化为 `undefined` | ✅ 提升但**不初始化**（暂时性死区） |
| 暂时性死区（TDZ） | ❌ 无 | ✅ 有 |
| 重复声明 | ✅ 允许 | ❌ 报错 `SyntaxError` |
| 全局声明挂 `window` | ✅ 挂到 `window` | ❌ 不挂到 `window` |
| 与 `for` 循环配合 | 共享同一变量 | 每次迭代创建新绑定 |
| ES 版本 | ES5 及之前 | ES6 (ES2015) 引入 |

### 1. 作用域差异

```javascript
function test() {
  if (true) {
    var a = 1;
    let b = 2;
  }
  console.log(a); // 1   ← var 不受块限制
  console.log(b); // ReferenceError: b is not defined
}
```

### 2. 变量提升 & 暂时性死区（TDZ）

```javascript
// var：提升并赋值 undefined
console.log(x); // undefined
var x = 10;

// let：虽提升但进入"暂时性死区"，访问即报错
console.log(y); // ReferenceError: Cannot access 'y' before initialization
let y = 20;
```

> **暂时性死区（Temporal Dead Zone, TDZ）**：从进入作用域开始，到 `let`/`const` 声明语句执行之前，变量都不可访问。TDZ 的目的是让代码更安全，强制"先声明后使用"。

### 3. 重复声明

```javascript
var a = 1;
var a = 2;        // OK
console.log(a);   // 2

let b = 1;
let b = 2;        // SyntaxError: Identifier 'b' has already been declared
```

### 4. 是否污染全局对象

```javascript
// 浏览器顶层脚本中
var gVar = 1;
let gLet = 2;

console.log(window.gVar); // 1     ← 被挂到 window
console.log(window.gLet); // undefined ← 不挂载
```

这是 `let` 的重要安全特性——避免全局污染。

### 5. for 循环中的经典差异（最常考！）

```javascript
// 用 var
for (var i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 0);
}
// 输出：3  3  3
// 原因：var 只有一个 i，三个回调闭包共享同一个 i，循环结束时 i 已是 3

// 用 let
for (let i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 0);
}
// 输出：0  1  2
// 原因：let 在每次迭代中创建一个新的块级绑定，三个回调各自闭包了不同的 i
```

ES6 规范明确：`for (let i …)` 的每次循环 i 都是一个**新的绑定**，并把上一轮的值拷贝过来。

#### ⚠️ 易误解澄清：var 不是"被覆盖"，而是"始终是同一个变量"

很多人会以为 `var` 在循环中是"每次声明又被覆盖了"，其实不是。**`var` 只声明了一次变量**，三次循环都是在**修改同一个变量的值**。

`var i` 是函数作用域（或全局作用域），上面的循环等价于：

```javascript
var i;                              // ① 声明只发生一次（被提升到作用域顶部）
for (i = 0; i < 3; i++) {           // ② 反复给同一个 i 赋值
  setTimeout(() => console.log(i), 0);
}
// 此时 i = 3，循环结束
// 三个 setTimeout 回调才开始执行 → 都读到同一个 i = 3
```

三个箭头函数闭包捕获的是**同一个变量 i 的引用**，不是三份独立的 `i`。等回调真正执行时，循环早已结束，`i` 当前值是 `3`，所以全打印 `3`。

而 `let` 的 `for` 循环按 ES6 规范，**每次迭代都新建一个块级绑定**，并把上一轮的值拷贝过来，概念上等价于：

```javascript
// 伪代码：let 版本概念展开
{ let i = 0; setTimeout(() => console.log(i), 0); }
{ let i = 1; setTimeout(() => console.log(i), 0); }
{ let i = 2; setTimeout(() => console.log(i), 0); }
```

三个回调各自闭包了**不同的 i**，所以输出 `0 1 2`。

#### 图示对比

```
var 版本：始终是同一个 i
  ┌─────────┐
  │  i = 3  │ ← 唯一的变量（最终值）
  └────▲────┘
       │ 三个闭包都指向它
  ┌────┼────┬────────┐
  cb1  cb2  cb3       → 输出 3 3 3

let 版本：每轮新建一个 i
  ┌───┐  ┌───┐  ┌───┐
  │i=0│  │i=1│  │i=2│ ← 三个独立的绑定
  └─▲─┘  └─▲─┘  └─▲─┘
    │      │      │
   cb1    cb2    cb3   → 输出 0 1 2
```

> **一句话**：`var` 全程只有一个 `i`，回调共享它；`let` 每轮一个新 `i`，回调各自独立。

#### 经典面试延伸：用 var 也能输出 0 1 2 吗？

可以，用 **IIFE** 或 **额外作用域** 手动给每轮造一个独立的变量：

```javascript
// 方案一：IIFE 立即执行函数
for (var i = 0; i < 3; i++) {
  (function (j) {
    setTimeout(() => console.log(j), 0);  // 0 1 2
  })(i);
}

// 方案二：setTimeout 第三个参数
for (var i = 0; i < 3; i++) {
  setTimeout(console.log, 0, i);  // 0 1 2
}
```

本质都是让回调闭包捕获一个**当前循环值的副本**，而不是共享的 `i`。

### 6. 全局/顶层 `this` 上的差异

```javascript
// 非严格模式浏览器
var v = 1;
let l = 2;
this.v;   // 1
this.l;   // undefined
```

### 7. 一张图记住差异

```
        ┌───────── var ─────────┐    ┌───────── let ─────────┐
作用域  │ 函数作用域            │    │ 块级作用域            │
提升    │ 提升 + 初始化undefined│    │ 提升 + TDZ            │
重复声明│ 允许                  │    │ 报错                  │
全局挂载│ 挂 window             │    │ 不挂 window           │
循环绑定│ 共享一个 i            │    │ 每轮新建一个 i        │
        └───────────────────────┘    └───────────────────────┘
```

---

### 选型建议

- 现代项目**默认使用 `const`**，需要重新赋值时改 `let`，**几乎不再使用 `var`**。
- 旧代码维护遇到 `var` 时小心其作用域穿透与提升带来的隐式 bug。
- ESLint 推荐规则：`no-var`、`prefer-const`。

---

### 面试速答

**Q1：var/let/const 的区别？**
作用域（函数 vs 块）、提升（var 给 undefined，let/const 在 TDZ）、重复声明（var 允许，let/const 报错）、全局对象挂载（var 挂 window，let/const 不挂）、`const` 还要求声明时初始化且不可重新赋值（但对象内部仍可改）。

**Q2：什么是暂时性死区？**
进入作用域后到 `let`/`const` 声明之前，变量虽存在但访问即报 `ReferenceError`，目的是强制"先声明后使用"。

**Q3：为什么 `for(let i…)` 能让 `setTimeout` 输出 0 1 2？**
`let` 在每次迭代生成一个新的块级绑定，每个回调闭包捕获的是各自循环那一轮的 `i`，而不是共享同一个 `i`。

**Q4：JS 是动态作用域还是静态作用域？**
静态（词法）作用域——作用域在书写代码时就已确定，由函数定义位置决定，与调用位置无关。

---

---

## TypeScript 构造函数参数属性（Parameter Properties）

### 一、是什么

在 TypeScript 的 `constructor` 参数前加上访问修饰符（`public` / `private` / `protected` / `readonly`），TS 会**自动声明同名实例属性并完成赋值**，省去手写 `this.xxx = xxx`。

```typescript
class Foo {
  constructor(public name: string) {}   // ← 一行解决声明 + 赋值
}

new Foo('vue').name; // 'vue'
```

### 二、源码场景：Vue 3 的 ReactiveEffect

```typescript
export class ReactiveEffect<T = any> {
  active = true
  deps: Dep[] = []
  parent: ReactiveEffect | undefined = undefined

  constructor(
    public fn: () => T,                              // ← 参数属性
    public scheduler: EffectScheduler | null = null, // ← 参数属性
    scope?: EffectScope                              // ← 普通参数，不挂 this
  ) {
    recordEffectScope(this, scope)
  }

  run() {
    // ...
    return this.fn()   // ✅ 可以直接调用，因为 this.fn 已被自动赋值
  }
}
```

**问题**：`run()` 里为什么能直接 `this.fn()`？
**答案**：`public fn: () => T` 是参数属性语法糖，编译器会自动生成 `this.fn = fn` 的赋值语句。

### 三、等价的"普通"写法

```typescript
// 参数属性写法（Vue 源码）
class ReactiveEffect<T> {
  constructor(public fn: () => T) {}
}

// 等价的展开写法
class ReactiveEffect<T> {
  fn: () => T;
  constructor(fn: () => T) {
    this.fn = fn;     // ← 编译器替你写的
  }
}
```

### 四、编译后的 JavaScript

```javascript
class ReactiveEffect {
  constructor(fn, scheduler = null, scope) {
    this.active = true;
    this.deps = [];
    this.parent = undefined;
    this.fn = fn;                 // ← 由参数属性生成
    this.scheduler = scheduler;   // ← 由参数属性生成
    recordEffectScope(this, scope);
    // 注意：scope 没有 this.scope，因为它不是参数属性
  }
  run() {
    return this.fn();             // 自然能调用
  }
}
```

### 五、四种修饰符的差异

| 修饰符 | 自动建属性 | 外部可访问 | 子类可访问 | 可重新赋值 |
|--------|-----------|-----------|-----------|-----------|
| `public` | ✅ | ✅ | ✅ | ✅ |
| `protected` | ✅ | ❌ | ✅ | ✅ |
| `private` | ✅ | ❌ | ❌ | ✅ |
| `readonly` | ✅ | ✅（默认 public） | ✅ | ❌（仅构造期可赋值） |

`readonly` 可与其他修饰符组合：`private readonly id: number`。

### 六、三种参数形态对比

```typescript
class Demo {
  constructor(
    public a: number,    // ① 参数属性 → this.a 可用
    b: number,           // ② 普通参数 → 仅构造期可见，外部访问不到
    private c: number    // ③ 参数属性（私有） → this.c 仅类内部访问
  ) {
    console.log(b);      // ✅ 构造期能用 b
  }
  test() {
    console.log(this.a); // ✅
    console.log(this.c); // ✅
    console.log(b);      // ❌ ReferenceError，b 不是属性
  }
}
```

### 七、易混淆点 & 注意事项

1. **没加修饰符就不是参数属性**。Vue 源码中 `scope?: EffectScope` 没有 `public`，所以**不会**变成 `this.scope`，外部访问不到。
2. **编译目标 < ES2022 时**，参数属性的赋值发生在 `super()` 调用之后、构造体代码之前。
3. **与 `strictPropertyInitialization` 不冲突**：参数属性等同于"已初始化"，不会报"属性未初始化"错误。
4. **不能与同名类字段重复声明**：

   ```typescript
   class Bad {
     fn: () => void;                  // ❌ 与参数属性重名会报错
     constructor(public fn: () => void) {}
   }
   ```

5. **JS 类不支持**：这是 TS 独有语法，纯 JS 必须手写 `this.xxx = xxx`。

### 八、一句话总结

> `public xxx: T` 写在构造函数参数上是 TS 的**参数属性语法糖**，等价于"声明 + 构造期赋值"两步合一；这就是 Vue 3 `ReactiveEffect.run()` 中可以直接 `this.fn()` 的原因。

---

---

## JavaScript `instanceof` 运算符

### 一、基本用法

`instanceof` 用于判断**一个对象**是否是**某个构造函数的实例**——更准确地说：判断**构造函数的 `prototype`** 是否在该对象的**原型链**上。

```javascript
[] instanceof Array              // true
[] instanceof Object             // true（Array 的原型链最终指向 Object）
function fn(){} instanceof Function  // true
new Date() instanceof Date       // true
```

语法：

```javascript
object instanceof Constructor
```

返回布尔值。

---

### 二、判断规则：原型链查找

**核心规则**：

> 沿着 `object.__proto__` 一路向上查找，看途中是否有任意一个节点 **=== `Constructor.prototype`**。命中则 `true`，到 `null` 都没命中则 `false`。

#### 图示

```javascript
class Animal {}
class Dog extends Animal {}
const d = new Dog()
```

```
   d
   │ __proto__
   ▼
   Dog.prototype  ──── === Dog.prototype ?  ✅
   │ __proto__
   ▼
   Animal.prototype ── === Animal.prototype ? ✅
   │ __proto__
   ▼
   Object.prototype ── === Object.prototype ?  ✅
   │ __proto__
   ▼
   null   ← 没找到时停止
```

```javascript
d instanceof Dog              // true
d instanceof Animal           // true
d instanceof Object           // true
d instanceof Array            // false (Array.prototype 不在链上)
```

---

### 三、手写实现 `instanceof`

理解原理最好的方式就是自己实现一遍：

```javascript
function myInstanceof(obj, Constructor) {
  // 1. 非对象（原始值）和 null 直接 false
  if (obj === null || (typeof obj !== 'object' && typeof obj !== 'function')) {
    return false
  }
  // 2. 构造函数必须是可调用对象，且必须有 prototype
  if (typeof Constructor !== 'function' || Constructor.prototype == null) {
    throw new TypeError("Right-hand side of instanceof is not callable")
  }

  let proto = Object.getPrototypeOf(obj)   // 等价于 obj.__proto__
  const target = Constructor.prototype

  while (proto !== null) {
    if (proto === target) return true       // ★ 在原型链上找到目标
    proto = Object.getPrototypeOf(proto)    // 继续往上
  }
  return false
}

// 验证
myInstanceof([], Array)        // true
myInstanceof([], Object)       // true
myInstanceof('abc', String)    // false（字符串原始值不是 String 的实例！）
myInstanceof(new String('abc'), String)  // true
```

---

### 四、原始值 vs 包装对象

**`instanceof` 只对对象有意义**，原始值（string / number / boolean / symbol / bigint）永远返回 `false`：

```javascript
'abc' instanceof String          // false ← 字符串原始值
new String('abc') instanceof String  // true ← 包装对象

123 instanceof Number            // false
new Number(123) instanceof Number    // true

true instanceof Boolean          // false
new Boolean(true) instanceof Boolean  // true
```

判断原始类型应该用 `typeof`：

```javascript
typeof 'abc'   // 'string'
typeof 123     // 'number'
```

---

### 五、特殊场景与陷阱

#### 1. `null` 与 `undefined`

```javascript
null instanceof Object        // false
undefined instanceof Object   // false
```

它们没有原型链，直接返回 false。

#### 2. 数组/函数都是对象

```javascript
[]     instanceof Object   // true
{}     instanceof Object   // true
function(){} instanceof Object  // true
function(){} instanceof Function // true
```

#### 3. 跨 iframe / 跨 realm 失效（经典坑）

```javascript
// 父页面
const iframe = document.createElement('iframe')
document.body.appendChild(iframe)
const iframeArray = iframe.contentWindow.Array
const arr = new iframeArray()

arr instanceof Array         // ❌ false！
arr instanceof iframeArray   // true
```

原因：每个 iframe 有自己的 `Array` 构造函数，两个 Array 的 `.prototype` 不是同一个对象。原型链上找不到当前作用域里的 `Array.prototype`。

**推荐替代**：

```javascript
Array.isArray(arr)            // true，跨 realm 也准确
Object.prototype.toString.call(arr) === '[object Array]'  // 通用方案
```

#### 4. 修改 `prototype` 会影响 instanceof 结果

```javascript
function Foo(){}
const f = new Foo()
f instanceof Foo   // true

Foo.prototype = {}     // ⚠️ 重新赋值原型
f instanceof Foo   // false ← f.__proto__ 仍是旧的 Foo.prototype
```

`instanceof` 比较的是**当前的 `Foo.prototype`** 与 `f.__proto__`，而 `f.__proto__` 在 `new` 那一刻就被固定了，所以重新赋值原型会让 `instanceof` 失准。

#### 5. `Symbol.hasInstance` 自定义

ES6 允许通过 `Symbol.hasInstance` 自定义 `instanceof` 行为：

```javascript
class Even {
  static [Symbol.hasInstance](v) {
    return typeof v === 'number' && v % 2 === 0
  }
}

2 instanceof Even   // true
3 instanceof Even   // false
```

当 `instanceof` 看到右边定义了 `Symbol.hasInstance` 方法时，会**优先调用它**，原型链查找逻辑被旁路掉。Vue 等框架不常这么用，但是 ES6 标准的一部分。

#### 6. 箭头函数 / class 的左侧

```javascript
const arrow = () => {}
arrow instanceof Function   // true（箭头函数也是 Function 的实例）

class Foo {}
Foo instanceof Function     // true（class 本质是构造函数，是 Function 的实例）
Foo instanceof Object       // true
```

---

### 六、与其他类型判断方式对比

| 方法 | 返回 | 适用 | 缺点 |
|------|------|------|------|
| `typeof x` | 字符串 `'string' / 'number' / ...` | 判断**原始类型**和 function | 区分不了 `null / array / object`（都是 `'object'`） |
| `x instanceof Y` | `boolean` | 判断**对象的构造关系** | 原始值无效；跨 realm 失效；可被 `Symbol.hasInstance` 改写 |
| `Array.isArray(x)` | `boolean` | 判断数组 | 仅数组专用，但**跨 realm 安全** |
| `Object.prototype.toString.call(x)` | 字符串 `'[object Array]'` 等 | 通用类型识别，跨 realm 安全 | 字符串匹配略繁琐 |
| `x.constructor === Y` | `boolean` | 直接看 constructor | 容易被原型重写绕过；不查原型链（不识别父类） |

`Object.prototype.toString.call` 的精确写法：

```javascript
function getType(x) {
  return Object.prototype.toString.call(x).slice(8, -1)
}

getType([])        // 'Array'
getType({})        // 'Object'
getType(null)      // 'Null'
getType(undefined) // 'Undefined'
getType(new Date) // 'Date'
getType(/a/)      // 'RegExp'
getType(new Map)  // 'Map'
```

这是最严谨的"判断 JS 数据类型"方案，框架内部常用。

---

### 七、与原型/原型链知识衔接

回到本文档前面的**原型与原型链**章节——`instanceof` 是原型链的最直接应用：

```javascript
// 摘自原型与原型链一节的手写实现
function isInstanceOf(obj, Ctor) {
  let proto = Object.getPrototypeOf(obj)
  while (proto) {
    if (proto === Ctor.prototype) return true
    proto = Object.getPrototypeOf(proto)
  }
  return false
}
```

理解了 `__proto__` 与 `prototype` 的关系后，`instanceof` 就是顺着 `__proto__` 链找 `prototype` 等值——一条非常清晰的查找路径。

---

### 八、面试高频问答

**Q1：`instanceof` 和 `typeof` 的区别？**
`typeof` 判断**原始类型**（返回字符串）；`instanceof` 判断**对象的构造关系**（返回布尔，沿原型链查找 `Constructor.prototype`）。`typeof null === 'object'` 是历史遗留 bug。

**Q2：手写 `instanceof`？**
循环 `obj.__proto__`，若途中等于 `Constructor.prototype` 返回 true，到 `null` 返回 false。（参考第三节代码）

**Q3：为什么 `'abc' instanceof String` 是 false？**
字符串原始值不是对象，没有原型链。只有 `new String('abc')` 这种包装对象才在 String 的原型链上。

**Q4：跨 iframe 的数组判断为什么 `instanceof Array` 不行？**
不同 frame 有各自独立的全局 `Array` 构造函数，它们的 `.prototype` 不是同一对象。改用 `Array.isArray()` 或 `Object.prototype.toString.call()`。

**Q5：`Function instanceof Object` 和 `Object instanceof Function` 哪个是 true？**
**两个都是 true**。
- `Object` 是函数 → `Object.__proto__ === Function.prototype` → `Object instanceof Function` ✅
- `Function.prototype.__proto__ === Object.prototype` → `Function instanceof Object` ✅

**Q6：如何更安全地做类型判断？**
- 数组 → `Array.isArray()`
- 通用 → `Object.prototype.toString.call(x).slice(8, -1)`
- 自定义类 → 仍可用 `instanceof`，但留意原型重写和跨 realm 风险

### 九、一句话总结

> **`instanceof`** 不直接看"对象是谁创建的"，而是**沿着对象的原型链，查找是否能遇到 `Constructor.prototype` 这个对象**。
> 它是原型链的最直接应用，简洁但有局限——**对原始值无效、跨 realm 失效、可被 `Symbol.hasInstance` 改写**。生产代码中判断数组用 `Array.isArray`，通用类型识别用 `Object.prototype.toString.call`。

---
