# JavaScript 语言机制

> 从根级《前端知识点.md》按主题拆分而来。

## JavaScript 浮点数：`0.1 + 0.2` 的精度问题

### 一、先看结果

```javascript
0.1 + 0.2
// 0.30000000000000004

0.1 + 0.2 === 0.3
// false
```

这不是 JS 的 bug，而是 **IEEE 754 双精度浮点数标准** 的固有限制——所有遵循该标准的语言（Python、Java、C 等）都会得到类似结果。

```python
# Python 3
>>> 0.1 + 0.2
0.30000000000000004
```

---

### 二、根本原因：十进制小数无法在二进制中精确表示

#### 1. 类比：十进制中的 `1/3`

十进制下 `1/3` 写成有限小数是不可能的：

```
1/3 = 0.33333333... (无限循环)
```

只能截断成 `0.3333...3` 这种**近似值**——丢失了精度。

#### 2. 二进制中的 `0.1`

二进制只用 2 作为基数。一个十进制小数能否被二进制**有限位**精确表示，取决于它能否写成 `分子/2^n` 的形式。

- `0.5 = 1/2 = 2^-1` → 二进制 `0.1` ✅ 精确
- `0.25 = 1/4 = 2^-2` → 二进制 `0.01` ✅ 精确
- `0.75 = 1/2 + 1/4` → 二进制 `0.11` ✅ 精确
- **`0.1 = 1/10`** → **无法用 `分子/2^n` 表示** → ❌ 无限循环

实际上 0.1 的二进制是：

```
0.0001100110011001100110011001100110011001100110011...
（0011 无限循环）
```

这跟十进制写 `1/3` 一样，必须**截断**才能存储。

---

### 三、IEEE 754 双精度的存储结构

JS 的 `Number` 都是 **64 位双精度浮点数**：

```
┌─────────┬──────────────┬─────────────────────────────────────┐
│ 符号位 1 │  指数位 11    │              尾数位 52              │
└─────────┴──────────────┴─────────────────────────────────────┘
         ↑              ↑                                     ↑
        63             62                                     0
```

- **1 位符号位 (sign)**：0 = 正，1 = 负
- **11 位指数位 (exponent)**：偏移 1023 编码
- **52 位尾数位 (mantissa / fraction)**：有效位，配合隐式的 "1." 前缀

表示形式：

```
(-1)^符号 × 1.尾数 × 2^(指数 - 1023)
```

#### `0.1` 在内存中的真实值

由于尾数只有 52 位，`0.0001100110011...` 必须被截断 + 四舍五入。最终存储的实际值是：

```
0.1000000000000000055511151231257827021181583404541015625
                  ↑
              并不是真正的 0.1，而是一个非常接近的值
```

`0.2` 同理：

```
0.200000000000000011102230246251565404236316680908203125
```

---

### 四、为什么 `0.1 + 0.2` 不等于 `0.3`

#### 1. 实际相加的值

```
0.1 的真实值: 0.1000000000000000055511151231257827...
+
0.2 的真实值: 0.2000000000000000111022302462515654...
=
            0.3000000000000000166533453693773481...
```

#### 2. 这个和在二进制中如何存储

`0.3000000000000000166...` 经过 IEEE 754 编码后，**最接近的可表示值**是：

```
0.30000000000000004440892098500626...
```

JS 打印数字时使用"恰好能唯一标识这个二进制浮点数的最短十进制串"，于是就显示：

```
0.30000000000000004
```

#### 3. 而 `0.3` 在内存中是什么

直接写 `0.3` 也会经历类似截断：

```
0.3 的真实值: 0.29999999999999998889776975374843...
```

显示出来还是 `0.3`（因为它是唯一能映射回这个二进制值的最短十进制串）。

#### 4. 关键对比

| 表达式 | 内存中实际值 |
|--------|------------|
| `0.1 + 0.2` | `0.30000000000000004440...` |
| `0.3` | `0.29999999999999998889...` |

两个值**根本不是同一个二进制串**，所以 `===` 返回 false。

---

### 四.5、澄清：浮点加法不是"补码相加"

很多人会误以为 `0.1 + 0.2` 的过程是：

> 十进制 → 二进制原码 → 补码 → 相加 → 转回原码 → 转回十进制

这是 **整数补码加法的逻辑**——浮点数完全不是这套流程。浮点数走的是 **IEEE 754 浮点加法**，**没有补码这一步**。

#### 1. 为什么整数用补码，浮点数不用

| 类型 | 编码方式 | 加法流程 |
|------|---------|---------|
| **整数**（C 中 `int32` 等） | **补码**（two's complement） | 直接二进制相加，溢出位丢弃 |
| **JS 整数 ≤ 2^53-1** | 仍存在 IEEE 754 浮点格式中（能精确表示） | 走浮点加法 |
| **JS 浮点数**（0.1 / 0.2 等） | **IEEE 754 双精度浮点** | 对阶 → 尾数相加 → 规格化 → 舍入 |
| **BigInt** | 任意精度有符号整数 | 专门的大数算法 |

补码的目的是把"减法"也变成"加法"，简化硬件——**浮点数有独立的符号位（首位 1 bit），根本不需要补码这套机制**。

#### 2. 整数补码加法（先复习对照）

以 8 位整数 `5 + (-3)` 为例：

```
  5 的原码：00000101
 -3 的原码：10000011
 -3 的反码：11111100
 -3 的补码：11111101    （反码 +1）

  补码相加：
   00000101
 + 11111101
 ──────────
  100000010   ← 第 9 位溢出，丢弃
   00000010   ← 结果 = +2 ✅
```

整数加法**直接按补码规则解读，不需要"转回原码再转十进制"**。

#### 3. IEEE 754 浮点加法的真实流程

`0.1 + 0.2` 的完整过程分 5 步：**编码 → 对阶 → 尾数相加 → 规格化 → 舍入**。

##### Step 0：把 0.1 和 0.2 编码成 IEEE 754

回顾结构：`(-1)^符号 × 1.尾数 × 2^(指数-1023)`

**0.1**：二进制 `0.000110011001100110011...0011 0011...`（0011 无限循环）。规格化为：

```
0.1 = 1.1001100110011001100110011001100110011001100110011010 × 2^-4
                                                            ↑
                                              截到 52 位 + 最近偶数舍入
```

| 字段 | 值 |
|------|-----|
| 符号位 | `0` |
| 指数 | `-4 + 1023 = 1019` → `01111111011` |
| 尾数 | `1001100110011001100110011001100110011001100110011010` |

**0.2** = 2 × 0.1，指数加 1：

```
0.2 = 1.1001100110011001100110011001100110011001100110011010 × 2^-3
```

| 字段 | 值 |
|------|-----|
| 符号位 | `0` |
| 指数 | `-3 + 1023 = 1020` → `01111111100` |
| 尾数 | 同 0.1 的尾数 |

##### Step 1：对阶（exponent alignment）

两数指数不同（`-4` vs `-3`），不能直接相加。**让小指数对齐到大指数**——把 0.1 的指数提到 `-3`，对应地把它的尾数**右移 1 位**：

```
0.1 对阶后: 0.11001100110011001100110011001100110011001100110011010 (× 2^-3)
0.2 原始:   1.10011001100110011001100110011001100110011001100110100 (× 2^-3)
              ↑
              注意：0.2 也有"末尾补 0"用于后续保留 guard bit
```

##### Step 2：尾数相加

**这里是普通二进制加法，不是补码加法**——两个数都是正数，符号位独立处理：

```
  0.11001100110011001100110011001100110011001100110011010
+ 1.10011001100110011001100110011001100110011001100110100
─────────────────────────────────────────────────────────
 10.01100110011001100110011001100110011001100110011001110
  ↑
  整数部分变成 2，需要规格化
```

##### Step 3：规格化

结果 `10.0110...` 不符合 `1.x × 2^指数` 的规范。**整体右移 1 位，同时指数 +1**：

```
10.01100110011001100110011001100110011001100110011001110 × 2^-3
↓ 右移 1
1.001100110011001100110011001100110011001100110011001110 × 2^-2
                                                         ↑
                                                   被挤出，参与舍入
```

##### Step 4：舍入（最近偶数舍入 round half to even）

规格化后尾数仍超 52 位，需要截断。被挤出的低位是 `10`：

```
保留 52 位:  0011001100110011001100110011001100110011001100110011
被挤出:      100
```

按 "最近偶数舍入"：

- 被挤出 `100` 恰好 0.5 → **向偶数舍入**
- 保留位最低位是 `1`（奇数）→ **进位**

```
0011...0011 + 1 = 0011...0100
```

##### Step 5：解码回十进制

```
(-1)^0 × 1.0011001100110011001100110011001100110011001100110100 × 2^-2
= 0.30000000000000004440892098500626161694526672363281250
```

JS 显示为最短可逆十进制串：

```
0.30000000000000004
```

而真正的 `0.3` 编码后是另一个二进制串（尾数末尾 `0011` 而非 `0100`），解码回去显示为 `0.3` —— 两者根本不相等。

#### 4. 整数加法 vs 浮点加法对比图

```
整数加法（C 中的 int32）              浮点加法（JS 的 Number）
──────────────────────────────       ─────────────────────────────
1. 十进制 → 二进制原码                  1. 十进制 → IEEE 754 编码
                                          (符号位/指数/尾数)
2. 原码 → 反码 → 补码                   2. 不需要补码！
                                          浮点有独立符号位
3. 补码直接相加（含负数）                 3. 对阶（指数对齐）
4. 溢出位丢弃                            4. 尾数相加（正数为普通加法）
5. 结果解读（按补码规则）                 5. 规格化 + 舍入
                                       6. 解码回十进制（带误差）
```

#### 5. 误差产生于流程的哪几步

| 阶段 | 误差来源 |
|------|---------|
| **编码阶段** | 0.1 二进制无限循环 → 截断成 52 位尾数 → **第一次舍入** |
| **对阶阶段** | 尾数右移时挤出低位 → 信息损失（用 guard / round / sticky bit 部分缓解） |
| **规格化舍入** | 相加结果超 52 位 → 再截断 → **第二次舍入** |

三处舍入叠加，使得最终二进制串与"直接编码 0.3"的二进制串不同。

#### 6. 一句话总结

> **0.1 + 0.2 不走"原码 → 补码 → 相加 → 原码 → 十进制"那一套**（那是整数补码加法）。
> 它走的是 **IEEE 754 浮点加法**：**编码 → 对阶 → 尾数相加（正数普通加法）→ 规格化 → 舍入 → 解码**。
> 整数加法用补码是为了把减法变加法；浮点数有独立符号位，**根本用不上补码**。误差产生于编码截断、对阶右移挤出、规格化舍入这三处。

---

### 五、可视化：从十进制到二进制的过程

#### 把 0.1 转成二进制（无限循环演示）

用"乘 2 取整法"：

```
0.1 × 2 = 0.2  → 取整 0
0.2 × 2 = 0.4  → 取整 0
0.4 × 2 = 0.8  → 取整 0
0.8 × 2 = 1.6  → 取整 1，保留 0.6
0.6 × 2 = 1.2  → 取整 1，保留 0.2 ← 出现循环！
0.2 × 2 = 0.4  → 0
0.4 × 2 = 0.8  → 0
0.8 × 2 = 1.6  → 1
0.6 × 2 = 1.2  → 1
... 0011 0011 0011 ... 无限循环
```

所以 `0.1` 的二进制：`0.000110011001100110011...`，**永远没有终止**。

#### 截断到 52 位尾数

IEEE 754 规范化后取最近的 52 位尾数，发生**最近偶数舍入（round half to even）**——这个微小的舍入误差就是后续所有问题的根源。

---

### 六、解决方案

#### 1. `toFixed` + 转回数字（最简单）

```javascript
const sum = 0.1 + 0.2
parseFloat(sum.toFixed(10))   // 0.3 ✅

// 但 toFixed 本身返回字符串
(0.1 + 0.2).toFixed(2)        // "0.30"
```

⚠️ 注意 `toFixed` 在某些值上也有舍入怪异：

```javascript
(1.005).toFixed(2)   // "1.00" 而不是 "1.01"！
// 因为 1.005 实际存的是 1.0049999...
```

##### 深入：`toFixed` 真的是"四舍五入"吗？为什么返回字符串？

###### 1) `toFixed` 的舍入规则不是"严格四舍五入"

很多人把 `toFixed` 当作"四舍五入"来用，但实际行为更复杂：

- **规范定义**：ECMAScript 规定 `toFixed` 使用"**round half away from zero**"（远离零的舍入，俗称"五入"）—— `1.5 → 2`、`-1.5 → -2`
- **看起来像四舍五入**，但**底层操作的是 IEEE 754 二进制浮点数，不是十进制数**——所以会出现一系列"反直觉"的结果

###### 2) "反直觉"案例集

```javascript
(1.005).toFixed(2)   // "1.00"   ❌ 期望 "1.01"
(1.015).toFixed(2)   // "1.01"   ❌ 期望 "1.02"
(1.025).toFixed(2)   // "1.03"   ✅ 期望 "1.03"
(1.035).toFixed(2)   // "1.04"   ✅ 期望 "1.04"
(1.045).toFixed(2)   // "1.04"   ❌ 期望 "1.05"
(1.055).toFixed(2)   // "1.05"   ❌ 期望 "1.06"

(2.5).toFixed(0)     // "3"
(-2.5).toFixed(0)    // "-3"     ← 远离零
```

为什么时对时错？因为这些十进制小数**在 IEEE 754 中的实际值不是它们看起来的样子**：

| 你写的 | 内存中实际值 | 舍入后 |
|--------|------------|--------|
| `1.005` | `1.00499999999999989...` | `1.00`（实际值的小数第三位是 4，不到 5） |
| `1.015` | `1.01499999999999968...` | `1.01` |
| `1.025` | `1.02500000000000035...` | `1.03` ✅（这次实际值就是大于 5） |
| `1.045` | `1.04499999999999992...` | `1.04` |

**结论**：`toFixed` 看起来是"按十进制四舍五入"，实际是"对存储的二进制近似值做远离零舍入"。两者偶尔吻合，偶尔不吻合——**完全取决于这个十进制小数在 IEEE 754 中是恰好近似偏大还是偏小**。

###### 3) 为什么 `toFixed` 返回字符串而不是数字

字符串 `"0.30"` 不能用数字保存——Number 类型存的是二进制浮点数，**没有"小数位数"这个概念**：

```javascript
const n = 0.30
console.log(n)         // 0.3 （末尾的 0 丢了）
0.30 === 0.3          // true，根本是同一个值
```

如果 `toFixed` 返回数字，所有"末尾的 0"都会消失，**那加这个函数干什么呢**？需求场景就是"我要显示成两位小数"——数字类型表达不了这个，**只能用字符串**。

##### 三大本质原因

| 原因 | 解释 |
|------|------|
| ① **保留末尾零** | `Number(0.30) === Number(0.3)`，数字无法区分；字符串 `"0.30"` 能保留 |
| ② **避免二次精度问题** | 即使返回数字，存的也是 IEEE 754 最近值——再次显示又会变成 `0.3000000...`，前一次的舍入白做 |
| ③ **典型用途是显示** | 金额、百分比、报表等场景**最终都要显示给用户**，字符串直接拼接更自然 |

举个对比：

```javascript
// 假想：如果 toFixed 返回数字
(0.1 + 0.2).toFixed(2)  →  0.30
// JS 把 0.30 在内存中存为 0.3
// 显示 → 0.3（末尾零没了！）
// 等于白做

// 实际：toFixed 返回字符串
(0.1 + 0.2).toFixed(2)  →  "0.30"
// 字符串原样保留，UI 显示就是 "0.30"
```

##### 想拿数字结果：手动转回

```javascript
const s = (0.1 + 0.2).toFixed(2)   // "0.30"
const n = Number(s)                 // 0.3
const m = parseFloat(s)             // 0.3
const k = +s                        // 0.3
```

但要清楚：**一旦转回数字，末尾的 0 会丢，精度也可能再变**——只在"算完了不需要再显示"的场景这么做。

##### 替代方案

| 需求 | 推荐方案 |
|------|---------|
| 严格四舍五入（按十进制） | 自己实现：`Math.round(x * 100) / 100`（但仍有浮点风险） |
| 银行家舍入（half to even） | 自己实现或用 decimal.js |
| 金融场景 | **`decimal.js` / `big.js` / `bignumber.js`**，不要靠 `toFixed` |
| 格式化显示（带千分位、货币） | `Intl.NumberFormat`：`new Intl.NumberFormat('zh-CN', { minimumFractionDigits: 2 }).format(0.1+0.2)` → `"0.30"` |

**`Intl.NumberFormat` 是更现代、更国际化、更专业的格式化方案**，比 `toFixed` 强大很多——它能处理千分位、本地化（如 `1,234.56` vs `1.234,56`）、货币符号、单位等。

##### 一句话总结

> `toFixed(n)` **不是严格的十进制四舍五入**，而是"对 IEEE 754 中那个二进制近似值做远离零舍入"——所以 `(1.005).toFixed(2) === "1.00"` 这种反直觉结果是正常的，根源在浮点存储本身。
> 它**返回字符串**有三大原因：① 数字类型无法保留末尾零、② 避免二次精度截断把舍入白做、③ 典型用途是显示——字符串最自然。
> 真要严肃做金融运算，请用 `decimal.js` 等专业库；要做格式化展示，用 `Intl.NumberFormat`。

#### 2. `Number.EPSILON` 做容差比较

```javascript
function nearlyEqual(a, b, eps = Number.EPSILON) {
  return Math.abs(a - b) < eps
}

nearlyEqual(0.1 + 0.2, 0.3)   // true ✅
```

`Number.EPSILON` 是 `2 ** -52`，约 `2.22e-16`，可以理解为"两个相邻可表示浮点数之间的最小间距"。

#### 3. 转整数运算

最稳的方法是**把小数变成整数算**，最后再除回去：

```javascript
function add(a, b) {
  const factor = 100
  return (a * factor + b * factor) / factor
}

add(0.1, 0.2)   // 0.3 ✅
```

更通用版本（自动确定放大倍数）：

```javascript
function add(a, b) {
  const ra = (a.toString().split('.')[1] || '').length
  const rb = (b.toString().split('.')[1] || '').length
  const m = Math.pow(10, Math.max(ra, rb))
  return (a * m + b * m) / m
}
```

#### 4. 用专业库

- **decimal.js**：任意精度十进制运算
- **bignumber.js**：大数 + 高精度小数
- **big.js**：轻量级，金融场景常用

```javascript
import Decimal from 'decimal.js'
new Decimal(0.1).plus(0.2).toString()   // '0.3'
```

**金融、电商订单**等对精度敏感的场景**强烈建议**用专业库，不要靠 `toFixed` 凑合。

---

### 七、相关精度坑

#### 1. 数据范围：`Number.MAX_SAFE_INTEGER`

IEEE 754 双精度的**整数安全范围**是 `±(2^53 - 1)`：

```javascript
Number.MAX_SAFE_INTEGER         // 9007199254740991 = 2^53 - 1
Number.MAX_SAFE_INTEGER + 1     // 9007199254740992
Number.MAX_SAFE_INTEGER + 2     // 9007199254740992 ★ 加 2 还是同一个数！
```

超出这个范围的整数运算会失真。解决方案是 ES2020 的 **`BigInt`**：

```javascript
9007199254740993n + 1n          // 9007199254740994n ✅
```

#### 2. JSON 中超长 ID 字段

后端传来的订单号 / 用户 ID 如果超过 `2^53 - 1`，`JSON.parse` 时会被截断：

```javascript
JSON.parse('{"id": 9007199254740993}').id   // 9007199254740992 ❌
```

解决方案：让后端把 ID 序列化为字符串。

#### 3. 比较运算

```javascript
0.1 + 0.2 > 0.3         // true（因为 0.30000...004 > 0.29999...998）
0.1 + 0.2 < 0.3         // false
```

涉及大小判断时，同样要用容差。

---

### 八、面试速答

**Q1：为什么 `0.1 + 0.2 !== 0.3`？**
因为 IEEE 754 双精度浮点数无法精确表示 0.1、0.2、0.3（它们的二进制都是无限循环），存储时各自被截断成近似值。两个近似值相加 + 再截断后，得到的二进制串与"0.3 直接存储的二进制串"不是同一个。

**Q2：怎么解决？**
- 容差比较：`Math.abs(a - b) < Number.EPSILON`
- 转整数运算：先乘 10^n 变整数再算
- 用 decimal.js 等专业库（金融场景必备）

**Q3：JS 中整数有精度问题吗？**
有。安全整数范围是 `2^53 - 1`（`Number.MAX_SAFE_INTEGER`），超出后整数运算会失真。需要用 `BigInt`。

**Q4：`Number.EPSILON` 是什么？**
约 `2.22e-16`（即 `2 ** -52`），表示"两个相邻可表示浮点数的最小间距"。用作浮点数相等比较的容差阈值。

### 九、一句话总结

> `0.1 + 0.2 = 0.30000000000000004` 不是 JS 的 bug，是**所有遵循 IEEE 754 双精度的语言通病**。
> 根本原因：十进制小数 0.1 / 0.2 / 0.3 在二进制中都是**无限循环**，必须截断成近似值存储；两个近似值相加再截断后，与"0.3 直接存储"不是同一个二进制串。
> 实际开发中：判等用容差、整数化运算、或直接上 decimal 库。

---

---

## 箭头函数为什么没有 `arguments`

### 一、先看现象

```javascript
// 普通函数：有自己的 arguments
function normal() {
  console.log(arguments)   // Arguments [1, 2, 3]
}
normal(1, 2, 3)

// 箭头函数：访问的是外层的 arguments
const arrow = () => {
  console.log(arguments)   // ReferenceError 或者外层的 arguments
}
arrow(1, 2, 3)
```

全局直接 `arrow(1, 2, 3)` → **`ReferenceError: arguments is not defined`**（全局没有 arguments）。

但在函数内部嵌套时：

```javascript
function outer() {
  const arrow = () => {
    console.log(arguments)   // ✅ 输出 outer 的 arguments
  }
  arrow('x', 'y')
}
outer(1, 2, 3)
// 输出: Arguments [1, 2, 3]   ← 是 outer 的，不是 arrow 的！
```

箭头函数没有自己的 `arguments`——它穿透到了外层的普通函数那里。

---

### 二、根本原因：箭头函数刻意不建立这些"函数环境绑定"

#### 1. 普通函数的"函数环境记录"

每次调用普通函数时，JS 引擎会创建一个**函数环境记录（Function Environment Record）**，里面包含：

| 绑定 | 含义 |
|------|------|
| `this` | 调用时的 this 值（取决于调用方式） |
| `arguments` | 类数组对象，保存全部实参 |
| `new.target` | `new` 调用时为构造函数本身，否则 undefined |
| `super` | 派生类中指向父类原型 |

这是"普通函数"的标配。

#### 2. 箭头函数 `[[ThisMode]] = "lexical"`

箭头函数创建函数环境记录时，**故意不分配 `this` / `arguments` / `new.target` / `super`**。当代码里访问这些标识符时，按**作用域链向上查找**——找到最近的"普通函数"上下文里的同名绑定。

也就是说，**`arguments` 在箭头函数里就是一个普通标识符**，跟你访问外层的局部变量没有本质区别。

#### 3. 引擎层伪代码示意

```
普通函数 fn(a, b) {
  EnvRec = {
    this: ...,
    arguments: [a, b, ...],     ← 自动注入
    new.target: ...,
    bindings: { a, b, 其它局部变量 }
  }
}

箭头函数 () => {
  EnvRec = {
    // ❌ 没有 this、arguments、new.target、super
    bindings: { 局部变量 }
  }
  // 当代码访问 arguments → 沿作用域链找外层
}
```

---

### 三、设计动机

#### 1. 解决"回调里 this 丢失"的历史痛点

ES5 时代经典写法：

```javascript
function Counter() {
  this.n = 0
  setInterval(function () {
    this.n++          // ❌ this 是 window，不是 Counter
  }, 1000)
}
```

##### 补：为什么 `setInterval` 回调里 `this === window`？

`setInterval(fn, 1000)` 在到点时由**计时器机制**调用 `fn`——本质上就是 `fn()` 这种**裸调用**（没有 owner，没有 `obj.fn()`，没有 `call/apply/bind`，没有 `new`）。
裸调用的普通函数在**非严格模式**下，`this` 被默认绑定为**全局对象**（浏览器是 `window`，Node.js 是 `global`）；**严格模式**下是 `undefined`。

下面系统说明这套规则。

---

##### 普通函数 `this` 的 4 条绑定规则

`this` 不是声明时就确定的，而是**调用时**根据"怎么调用"决定。优先级从高到低：

```
new 绑定  >  显式绑定 (call/apply/bind)  >  隐式绑定 (obj.fn())  >  默认绑定
```

###### 1) 默认绑定（裸调用）

```javascript
function fn() {
  console.log(this)
}
fn()                 // 非严格：window / global   严格："undefined"
```

- 非严格模式：`this` = 全局对象（`window` / `global`）
- 严格模式：`this` = `undefined`

**`setInterval` / `setTimeout` 的回调、Promise 回调、forEach 回调（不传第二参数时）等都属于这种"裸调用"** —— 计时器/Promise 引擎拿到你的函数后**直接 `fn()`**，没经过任何 `obj.fn()` 的形式。

###### 2) 隐式绑定（作为对象方法调用）

```javascript
const obj = {
  n: 1,
  show() { console.log(this.n) }
}
obj.show()           // this = obj，输出 1
```

调用时**点号左边的对象**就是 `this`。

**陷阱：方法被"摘出来"赋值后变成裸调用**：

```javascript
const fn = obj.show
fn()                 // ❌ 裸调用，this 退化为默认绑定（window/undefined）
```

###### 3) 显式绑定（`call` / `apply` / `bind`）

```javascript
function fn() { console.log(this.name) }
const ctx = { name: 'Tom' }

fn.call(ctx)         // Tom
fn.apply(ctx)        // Tom
const bound = fn.bind(ctx)
bound()              // Tom，且无论后续怎么调用都是 ctx
```

- `call(ctx, a, b)` 立即调用，参数逐个传
- `apply(ctx, [a, b])` 立即调用，参数数组传
- `bind(ctx)` 返回一个**永久绑定** `this` 的新函数（且不能被再次 `call/bind` 覆盖）

###### 4) `new` 绑定（构造函数调用）

```javascript
function Person(name) {
  this.name = name   // this 是新创建的对象
}
const p = new Person('Tom')
console.log(p.name)  // Tom
```

`new` 内部做了 4 件事：

1. 创建一个新对象 `obj`
2. 把 `obj.__proto__` 指向 `Person.prototype`
3. 把 `this` 绑定到 `obj`，执行构造函数
4. 如果构造函数返回的是对象就用之，否则用 `obj`

---

##### 优先级 demo

```javascript
function fn() { console.log(this.name) }
const a = { name: 'A', fn }
const b = { name: 'B', fn }

a.fn()                 // 'A'  ← 隐式绑定
a.fn.call(b)           // 'B'  ← 显式 > 隐式
const bound = fn.bind(a)
bound.call(b)          // 'A'  ← bind 不可被覆盖，bind > call
new bound()            // ★ 这里 this 是新对象，不是 a
                       //   ← new > bind（ES6 规范明确写了 new 能穿透 bind）
```

---

##### 严格模式 vs 非严格模式

```javascript
'use strict'
function fn() { console.log(this) }
fn()                   // undefined ← 严格模式不再默认到 window
```

ES5 引入严格模式后，**默认绑定从"全局对象"改为 `undefined`**——避免无意中污染全局。这也是为什么 ES6 之后的 class 内部默认严格模式，类方法被"摘出来"后 this 是 undefined。

---

##### 常见陷阱场景

###### 1) 回调里的 `this` 丢失（开头例子的根源）

```javascript
function Counter() {
  this.n = 0
  setInterval(function () {
    this.n++   // setInterval 内部 callback() 裸调用
               // 非严格 → this = window，window.n 是 NaN
               // 严格 → this = undefined，报 TypeError
  }, 1000)
}
```

修复方案：

```javascript
// ① ES5: 缓存 this
function Counter() {
  const self = this
  setInterval(function () { self.n++ }, 1000)
}

// ② .bind(this)
function Counter() {
  setInterval(function () { this.n++ }.bind(this), 1000)
}

// ③ ES6 箭头函数（最推荐）
function Counter() {
  setInterval(() => this.n++, 1000)
}
```

###### 2) 对象方法摘出来传参

```javascript
const obj = { n: 1, show() { console.log(this.n) } }

[obj.show].forEach(fn => fn())   // undefined，因为 forEach 回调里裸调用 fn()
```

###### 3) DOM 事件回调

```javascript
button.addEventListener('click', function () {
  console.log(this)   // ← this 是 button（DOM 触发时显式绑定为元素）
})

button.addEventListener('click', () => {
  console.log(this)   // ← 箭头函数：this 是外层（可能 window）
})
```

###### 4) 链式调用中的 this

```javascript
const obj = {
  name: 'Tom',
  greet() { return this },
  hi() { console.log(this.name) }
}
obj.greet().hi()      // Tom，因为 greet 返回 obj，hi 仍按 obj.hi() 隐式绑定
```

---

##### 全部规则速记表

| 调用形式 | this 是谁 |
|---------|----------|
| `fn()` 裸调用 | 非严格→全局，严格→undefined |
| `obj.fn()` 方法调用 | obj |
| `fn.call(ctx)` / `fn.apply(ctx)` | ctx |
| `fn.bind(ctx)()` | ctx（永久绑定） |
| `new Fn()` | 新创建的对象 |
| 箭头函数 `() => {}` | 不绑定，沿作用域链找外层 |
| DOM 事件 listener（普通函数） | 触发事件的元素 |
| setTimeout/setInterval 回调（普通函数） | 全局/undefined（裸调用） |

---

只能用 `var self = this` 或 `.bind(this)` 修补。箭头函数从根本上让内层访问 this 直接拿到外层：

```javascript
function Counter() {
  this.n = 0
  setInterval(() => {
    this.n++          // ✅ this 就是 Counter
  }, 1000)
}
```

`arguments` 跟 `this` 是一对的——既然要让 `this` 穿透，那 `arguments` 也一样穿透才一致。**统一规则比"this 穿透但 arguments 不穿透"清晰**。

#### 2. 箭头函数定位是"轻量回调"

ES6 把箭头函数定位为"**短小、表达式风格、用作回调或函数式编程**"——这类场景里：

- 很少需要构造（所以禁用 `new`）
- 几乎不关心 arguments（参数明确写出来或用 rest）
- 主要痛点是 this 错位

砍掉 `arguments` 让箭头函数：
- 更轻量（少创建一个对象）
- 语义更纯粹（"只是一个表达式，不带函数包袱"）
- 避免与外层混淆

#### 3. 与 `rest` 参数自然搭配

ES6 同时引入了 `...rest`，**它是真正的数组**（不是类数组），功能上完全覆盖 `arguments`，还更好用：

```javascript
const arrow = (...args) => {
  console.log(args)         // 真数组
  args.map(x => x * 2)      // 直接用数组方法 ✅
}
arrow(1, 2, 3)
```

对比 `arguments`：

```javascript
function fn() {
  arguments.map(...)        // ❌ TypeError，不是真数组
  Array.from(arguments)     // 要先转换
}
```

既然有了更好用的 `...args`，**`arguments` 在箭头函数里就没必要保留**。

---

### 四、其他被砍掉的"绑定"

箭头函数同时缺失这 4 个：

| 缺失绑定 | 表现 |
|---------|------|
| `this` | 外层的 this（词法绑定） |
| `arguments` | 外层的 arguments |
| `new.target` | 外层的 new.target |
| `super` | 外层的 super |

附加限制：

- ❌ 不能用 `new` 调用（`new arrow()` → TypeError）
- ❌ 没有 `prototype` 属性（因为不能当构造函数）
- ❌ 不能用作 generator（写不出 `*` 标记）

---

### 五、举一反三：何时该用箭头函数

#### 适合

- 回调函数（数组方法、定时器、Promise 链等）
- 需要保留外层 this 的场景（class 方法的内层函数）
- 短小的纯函数

#### 不适合

- **对象方法**（除非你真的不想用对象本身的 this）

  ```javascript
  const obj = {
    n: 1,
    bad: () => console.log(this.n)   // ❌ this 是外层（可能 undefined）
  }
  ```

- **需要 `arguments` 的可变参数函数**（用 `function` 或 rest）
- **构造函数**（不允许 new）
- **原型方法**（也会丢 this）

---

### 六、用 rest 替代 arguments 的对照

```javascript
// 旧（普通函数）
function sum() {
  return Array.from(arguments).reduce((a, b) => a + b, 0)
}

// 新（箭头函数 + rest）
const sum = (...nums) => nums.reduce((a, b) => a + b, 0)
```

更短、更直观、拿到的是**真数组**——这是 ES6 想推广的写法。

---

### 七、面试速答

**Q1：箭头函数为什么没有 arguments？**
ES6 设计箭头函数时，**故意不建立 `this` / `arguments` / `new.target` / `super` 这四个函数环境绑定**——访问时按词法作用域链向上找。目的：让 this 穿透解决回调 this 错位问题，arguments 跟着一起穿透才一致；同时 ES6 已经有更好用的 `...rest`（真数组）替代。

**Q2：箭头函数里要拿参数怎么办？**
用 `...args` rest 参数——返回真数组，可直接 `.map / .reduce / .filter`。

**Q3：箭头函数还缺什么？**
- 没有自己的 `this`（词法绑定）
- 没有 `arguments`
- 没有 `new.target`
- 没有 `super`
- 不能 `new`
- 没有 `prototype`
- 不能写成 generator

**Q4：什么场景不该用箭头函数？**
对象方法、原型方法、构造函数、需要 `arguments` 的可变参数函数。

### 八、一句话总结

> **箭头函数没有 `arguments`**，是因为它在引擎层故意**不建立 `this` / `arguments` / `new.target` / `super` 这四个绑定**——所有这些访问都会沿作用域链穿透到外层的普通函数。
> 设计动机：① 让 `this` 词法绑定解决回调里 this 错位的历史痛点；② 把箭头函数定位为轻量回调，砍掉用不上的包袱；③ ES6 同期引入了 `...rest`，是 `arguments` 更好的替代品（真数组，可直接用 `.map / .reduce`）。

---

---

## `isNaN` 与 `Number.isNaN` 的区别

### 一、先看核心区别

| 维度 | `isNaN(x)` | `Number.isNaN(x)` |
|------|-----------|------------------|
| 引入版本 | ES1（最早就有，全局函数） | ES6（`Number` 命名空间下） |
| **是否做类型转换** | ✅ 先 `Number(x)` 再判断 | ❌ 不做转换 |
| 判定规则 | "转成数字后是不是 NaN" | "**值本身**是不是 NaN" |
| 是否安全 | ❌ 有"误判"风险 | ✅ 严格判断 |

**一句话**：`isNaN` = "**不是数字吗？**"（容易把 `'abc'`/`{}` 也判成 true）；`Number.isNaN` = "**就是 NaN 这个值吗？**"

---

### 二、为什么 `isNaN` 会"误判"

#### 1. 行为推演

```javascript
isNaN(NaN)         // true   ✅
isNaN(123)         // false  ✅
isNaN('abc')       // true   ⚠️ ← '?' 不是数字，但它本身又不是 NaN
isNaN('123')       // false  ← '123' 会被转成数字 123
isNaN(undefined)   // true   ⚠️ ← Number(undefined) === NaN
isNaN({})          // true   ⚠️ ← Number({}) === NaN
isNaN([])          // false  ← Number([]) === 0
isNaN([1])         // false  ← Number([1]) === 1
isNaN([1, 2])      // true   ← Number([1, 2]) === NaN
isNaN(true)        // false  ← Number(true) === 1
isNaN(null)        // false  ← Number(null) === 0
```

`isNaN` 的等价实现：

```javascript
function isNaN(x) {
  return Number.isNaN(Number(x))   // ★ 先做类型转换
}
```

类型转换才是麻烦的源头——只要 `Number(x)` 转出来是 NaN，就返回 true，**根本不在乎 x 自己是不是真的 NaN**。

#### 2. 真正的"陷阱"

```javascript
isNaN('hello')   // true
// 但 'hello' 是字符串，明显不是 NaN！
// 你想表达"它是 NaN"，但 isNaN 告诉你"它转成数字后是 NaN"——语义偏差
```

如果代码是这样：

```javascript
const v = userInput()       // 来自表单 / API，可能是任何东西
if (isNaN(v)) {
  // ⚠️ 这里你以为 v 是 NaN，其实可能是 'hello' / {} / undefined
  // 业务分支可能走错
}
```

---

### 三、`Number.isNaN` 的精确语义

```javascript
Number.isNaN(NaN)        // true   ✅
Number.isNaN(123)        // false
Number.isNaN('abc')      // false  ← 严格：'abc' 不是 NaN
Number.isNaN(undefined)  // false  ← 严格：undefined 不是 NaN
Number.isNaN({})         // false
Number.isNaN('NaN')      // false  ← 是字符串，不是 NaN 值
```

**等价实现**：

```javascript
Number.isNaN = function (x) {
  return typeof x === 'number' && x !== x
  //                              ↑ NaN 的独门特征：NaN !== NaN
}
```

#### 为什么用 `x !== x`

NaN 是 JavaScript 中**唯一一个不等于自身的值**：

```javascript
NaN === NaN   // false ★
NaN == NaN    // false ★
```

这是 IEEE 754 规定的——它表示"无意义的数学结果"，两个无意义结果当然不能算"相等"。所以 `x !== x` 是判定 NaN 最简洁可靠的写法。

---

### 四、对照速记表

| 输入 | `isNaN(x)` | `Number.isNaN(x)` |
|------|-----------|------------------|
| `NaN` | ✅ true | ✅ true |
| `123` | false | false |
| `'123'` | false | false |
| `'abc'` | ⚠️ **true** | false |
| `undefined` | ⚠️ **true** | false |
| `null` | false | false |
| `true` | false | false |
| `false` | false | false |
| `{}` | ⚠️ **true** | false |
| `[]` | false | false |
| `[1]` | false | false |
| `[1, 2]` | ⚠️ **true** | false |
| `''`（空串） | false | false |
| `'  '`（空白） | false | false |
| `Symbol()` | TypeError | false |

⚠️ 标记的就是 `isNaN` 的"误判"——这些输入并不是 NaN，但被判成 true。

---

### 五、什么时候用哪个

#### 1. 判断"值是否是 NaN" → **永远用 `Number.isNaN`**

```javascript
const result = 0 / 0
if (Number.isNaN(result)) {
  // ✅ 严格判定
}
```

#### 2. 判断"一个值是否不能被转成有效数字" → 用 `isNaN`，但更推荐 `!Number.isFinite()`

```javascript
// 旧写法
if (isNaN(userInput)) {
  // 不能解析为数字
}

// 更明确的现代写法
if (!Number.isFinite(Number(userInput))) {
  // 不是有限数字（含 NaN / Infinity / -Infinity）
}
```

#### 3. 表单/接口数字校验场景

```javascript
function isValidNumber(v) {
  // 一行解决：能否被解析为有限数字
  return typeof v === 'number'
    ? Number.isFinite(v)
    : !isNaN(parseFloat(v)) && Number.isFinite(Number(v))
}
```

---

### 六、相关 API 一并对比

| API | 判定标准 | 类型转换 |
|-----|---------|---------|
| `isNaN(x)` | 转成数字后是 NaN | ✅ |
| `Number.isNaN(x)` | x 本身就是 NaN | ❌ |
| `isFinite(x)` | 转成数字后是有限数字 | ✅ |
| `Number.isFinite(x)` | x 本身是有限的 number | ❌ |
| `Number.isInteger(x)` | x 是整数 number | ❌ |
| `Number.isSafeInteger(x)` | x 是 `±(2^53-1)` 内的安全整数 | ❌ |

ES6 给 Number 加的这些方法**都不做类型转换**，行为更严格、可预测——**生产代码优先用 `Number.xxx` 系列**。

---

### 七、常见面试题

**Q1：`isNaN` 和 `Number.isNaN` 区别？**
`isNaN` 会先 `Number(x)` 再判断，所以 `'abc'` / `undefined` / `{}` 也会返回 true（被"误判"）；`Number.isNaN` 不做转换，**只有 `x` 本身就是 NaN 这个值**才返回 true。

**Q2：如何手写 `Number.isNaN`？**

```javascript
function myIsNaN(x) {
  return typeof x === 'number' && x !== x
}
```

**Q3：为什么 `NaN === NaN` 是 false？**
IEEE 754 规定 NaN 表示"无意义的数学结果"，两个无意义结果不能算相等。这也让 `x !== x` 成为最简洁的 NaN 判定方法。

**Q4：怎么判断"一个值能否被解析为有效数字"？**
推荐 `Number.isFinite(Number(x))` —— 既排除 NaN，也排除 ±Infinity。

### 八、一句话总结

> **`isNaN(x)`** = `Number.isNaN(Number(x))`，先转换再判断——会把 `'abc' / undefined / {} / [1,2]` 这些"转成数字是 NaN"的值也判成 true。
> **`Number.isNaN(x)`** 不做转换，只在 `x` 真正是 NaN 这个值时返回 true，更严格更安全。
> **生产代码优先用 `Number.isNaN`** 和它的 `Number.isFinite / isInteger / isSafeInteger` 兄弟们，避免隐式类型转换的坑。

---

---

## 手写 `call`、`apply`、`bind`（含详细注解）

### 一、三者关系与本质

`call`、`apply`、`bind` 的核心作用相同：**改变函数的 `this` 指向**。区别在于调用时机和传参方式：

| | 调用时机 | 传参方式 | 返回值 |
|-------|---------|---------|--------|
| `fn.call(ctx, a, b)` | **立即调用** | 逐个传参 | 函数返回值 |
| `fn.apply(ctx, [a, b])` | **立即调用** | 数组传参 | 函数返回值 |
| `fn.bind(ctx, a, b)` | **返回新函数**，调用时才执行 | 可分批传参（柯里化） | 新函数 |

**本质**：三者都是把函数**临时挂到** `ctx` 对象上，作为对象的方法来调用——利用 `obj.fn()` 的隐式绑定规则让 `this` 指向 `ctx`。

---

### 二、手写 `call`

```javascript
/**
 * 手写 call
 *
 * 核心思路：
 *   1. 把 fn 临时设为 ctx 的一个属性（方法）
 *   2. 用 ctx.fn(...args) 调用 —— 此时 fn 内部的 this 自然指向 ctx
 *   3. 调用完删掉这个临时属性，不污染原对象
 *   4. 返回 fn 的执行结果
 *
 * @param {any}    ctx  - 要绑定的 this 值
 * @param {...any} args - 逐个传入的参数
 * @return {any}         fn 执行后的返回值
 */
Function.prototype.myCall = function (ctx, ...args) {
  // ========== Step 1: 处理 ctx 的边界情况 ==========

  // ① 如果没传 ctx 或传了 null/undefined → this 绑定到全局对象
  //    浏览器中是 window，Node 中是 global
  //    严格模式下 this 应该是 undefined，但这里用 globalThis 做兜底
  if (ctx == null) {
    ctx = typeof globalThis !== 'undefined' ? globalThis : window
  }
  //    ↑ == null 会同时匹配 null 和 undefined（类型强制转换）

  // ② 如果 ctx 是原始值（字符串、数字、布尔值等），需要包装成对象
  //    因为原始值没有属性，不能在上面挂方法
  //    Object(ctx) 会把原始值转成对应的包装对象：
  //      'hello' → String{'hello'}
  //      123     → Number{123}
  //      true    → Boolean{true}
  //    对于已经是对象的 ctx，Object(ctx) 直接返回它自身
  ctx = Object(ctx)

  // ========== Step 2: 把 fn 挂到 ctx 上 ==========

  // 为什么要用 Symbol？
  //   如果直接用 'fn' 或 '__fn__' 之类的字符串做 key，
  //   可能跟 ctx 上已有的属性重名——把原有属性覆盖了
  //   Symbol 是唯一的，永远不会冲突
  const fnSymbol = Symbol('fn')

  // this 就是调用 myCall 的函数，即要被改变 this 的那个 fn
  // 例：foo.myCall(obj, 1, 2) → myCall 内部的 this 就是 foo
  ctx[fnSymbol] = this

  // ========== Step 3: 通过 ctx.xxx() 调用 ==========

  // 关键：ctx[fnSymbol](...args) 这种调用形式，
  //       fn 内部的 this 会被 JS 引擎按"隐式绑定规则"设为 ctx
  const result = ctx[fnSymbol](...args)

  // ========== Step 4: 清理 & 返回 ==========

  // 用完就删，不要污染 ctx
  delete ctx[fnSymbol]

  // 返回 fn 执行的结果（如果 fn 没有 return，这里就是 undefined）
  return result
}
```

**验证**：

```javascript
function greet(greeting, punctuation) {
  return `${greeting}, ${this.name}${punctuation}`
}

const person = { name: 'Tom' }

greet.myCall(person, 'Hello', '!')   // "Hello, Tom!"
greet.myCall(null, 'Hi', '.')        // "Hi, undefined." （this 指向全局）
greet.myCall('world', 'Hi', '!')     // "Hi, undefined!"  ('world' 被 Object() 包装，但没有 name 属性)
```

---

### 三、手写 `apply`

```javascript
/**
 * 手写 apply
 *
 * 与 call 的区别只有一点：参数以数组形式传入
 *
 * @param {any}    ctx   - 要绑定的 this 值
 * @param {Array}  args  - 以数组形式传入的参数（或类数组）
 * @return {any}           fn 执行后的返回值
 */
Function.prototype.myApply = function (ctx, args) {
  // ========== Step 1: 处理 ctx 的边界情况 ==========

  if (ctx == null) {
    ctx = typeof globalThis !== 'undefined' ? globalThis : window
  }
  ctx = Object(ctx)

  // ========== Step 2: 处理 args ==========

  // 兼容没有传参数数组的情况
  // 例：fn.myApply(obj)  →  args 为 undefined
  if (args == null) {
    args = []
  }

  // 规范要求 args 必须是类数组对象（有 length 属性）
  // 如果不是，抛出 TypeError（这里做简化处理，直接用展开）
  // 真正的 apply 在 ES3 时代只接受数组和 arguments，
  // ES5+ 接受所有类数组对象
  if (typeof args !== 'object' || typeof args.length !== 'number') {
    throw new TypeError('CreateListFromArrayLike called on non-object')
  }

  // ========== Step 3: 挂载 + 调用 + 清理 ==========

  const fnSymbol = Symbol('fn')
  ctx[fnSymbol] = this

  // ★ 和 call 的唯一区别：用 ... 展开数组参数
  const result = ctx[fnSymbol](...args)

  delete ctx[fnSymbol]
  return result
}
```

**call 和 apply 的重叠**：

```javascript
// call 和 apply 本质上可以互相实现

// 用 call 模拟 apply：
fn.call(ctx, ...argsArray)

// 用 apply 模拟 call：
fn.apply(ctx, [a, b, c])    // 等价于 fn.call(ctx, a, b, c)
```

**验证**：

```javascript
const nums = [5, 6, 2, 3, 7]

Math.max.myApply(null, nums)   // 7
// Math.max 不依赖 this，所以传 null

// 等价于
Math.max(...nums)              // 7  (ES6 展开后就不太需要 apply 了)
```

---

### 四、手写 `bind`

```javascript
/**
 * 手写 bind
 *
 * 与 call/apply 的关键不同：
 *   - call/apply 是"借来用一次"，立即执行
 *   - bind 是"永久绑定"，返回一个绑死了 this 的新函数
 *
 * bind 有四个核心特性需要实现：
 *   ① 绑定 this
 *   ② 支持预填充参数（柯里化 / 偏函数）
 *   ③ 返回的新函数可以被 new 调用（此时 this 绑定失效，以 new 的实例为准）
 *   ④ 返回的新函数要维护原型链
 *
 * @param {any}    ctx     - 要绑定的 this 值
 * @param {...any} preArgs - 预填充的参数
 * @return {Function}        绑定了 this 和预填充参数的新函数
 */
Function.prototype.myBind = function (ctx, ...preArgs) {
  // ========== Step 1: 类型校验 ==========

  // bind 只能由函数调用
  // 例：({}).myBind() → TypeError，因为 {} 不是函数
  if (typeof this !== 'function') {
    throw new TypeError('Function.prototype.bind - what is trying to be bound is not callable')
  }

  // 保存原始函数的引用
  // this = 调用 myBind 的那个函数
  const originalFn = this

  // ========== Step 2: 定义返回的绑定函数 ==========

  /**
   * boundFn —— 对外返回的新函数
   *
   * 它有两种调用方式：
   *   ① 普通调用  boundFn(args)       → this = ctx
   *   ② new 调用   new boundFn(args)   → this = 新创建的实例对象
   */
  function boundFn(...callArgs) {
    // 合并参数：预填充的 preArgs + 调用时传入的 callArgs
    const allArgs = [...preArgs, ...callArgs]

    // ========== Step 3: 判断调用方式是普通调用还是 new 调用 ==========

    // 判断依据：this instanceof boundFn
    //
    //   - 普通调用时 boundFn()：
    //       this 不是 boundFn 的实例（指向全局或 undefined）
    //       → 使用绑定的 ctx
    //
    //   - new 调用时 new boundFn()：
    //       new 操作符创建了一个新对象，该对象的 __proto__ 指向 boundFn.prototype
    //       → this 就是这个新对象，this instanceof boundFn === true
    //       → 忽略绑定的 ctx，让 this 指向 new 创建的新对象
    //       （这是 ES6 规范规定的：new 的优先级 > bind）
    //
    const useNew = this instanceof boundFn

    // apply 的第二个参数是数组，所以把 allArgs 传进去
    return originalFn.apply(useNew ? this : ctx, allArgs)
  }

  // ========== Step 4: 维护原型链 ==========

  // 为什么要维护原型链？
  //   如果 originalFn.prototype 上有方法，new boundFn() 产生的实例
  //   应该能通过原型链访问到这些方法
  //
  // 方式：让 boundFn.prototype 继承 originalFn.prototype
  //   用一个中间空函数做桥接，避免 boundFn.prototype 和 originalFn.prototype
  //   指向同一个对象（那样修改 boundFn.prototype 会污染 originalFn.prototype）

  function Bridge() {}
  Bridge.prototype = originalFn.prototype
  boundFn.prototype = new Bridge()

  // 修正 constructor 指向
  // new Bridge() 产生的实例的 constructor 会沿原型链指向 originalFn
  // 但 boundFn.prototype.constructor 应该指向 boundFn 自身
  boundFn.prototype.constructor = boundFn

  // ========== Step 5: 返回绑定函数 ==========

  return boundFn
}
```

**逐层拆解原型链维护**：

```
不维护原型链时：
  new boundFn() → boundFn.prototype → Object.prototype → null
  原函数的 prototype 挂不上去 → 原型方法丢失

维护原型链后：
  new boundFn()
    → boundFn.prototype（中间实例）
      → Bridge.prototype === originalFn.prototype
        → originalFn 的原型方法全在这里
          → Object.prototype → null
```

**验证**：

```javascript
// === 基础绑定 ===
function multiply(a, b) {
  return a * b * this.rate
}
const obj = { rate: 2 }
const boundMultiply = multiply.myBind(obj)

boundMultiply(3, 5)  // 30  (3 * 5 * 2)

// === 柯里化（预填充参数） ===
const double = multiply.myBind(obj, 2)   // 预填充第一个参数 a = 2
double(5)  // 20  (2 * 5 * 2)  → 调用时只传了 b = 5

// === new 调用（this 绑定的 ctx 失效） ===
function Person(name, age) {
  this.name = name
  this.age = age
}
Person.prototype.sayHi = function () {
  return `Hi, I'm ${this.name}`
}

const BoundPerson = Person.myBind({ name: 'ignored' }, 'Tom')
// 即使 bind 了 ctx，new 调用时 this 还是指向新实例:
const p = new BoundPerson(25)
console.log(p.name)     // 'Tom'   ← 不是 'ignored'
console.log(p.age)      // 25
console.log(p.sayHi())  // "Hi, I'm Tom"  ← 原型方法可用

// === this instanceof boundFn 原理验证 ===
// 普通调用:  boundFn()     → 内部的 this = window/undefined → this instanceof boundFn = false
// new 调用:   new boundFn() → 内部的 this = 新对象 → 新对象的 __proto__ = boundFn.prototype → true
```

---

### 五、三者的关键区别速查

| 特性 | call | apply | bind |
|------|------|-------|------|
| 调用时机 | 立即 | 立即 | 返回新函数，延后调用 |
| 传参 | 逐个传 `(ctx, a, b, c)` | 数组传 `(ctx, [a, b, c])` | 分批传（柯里化） |
| this 绑定 | 一次性 | 一次性 | **永久绑定**（不可被 call/apply 再次覆盖） |
| new 调用 | N/A | N/A | new 时 this 绑定失效，以实例为准 |
| 原型链 | N/A | N/A | 需要维护 |
| 返回值 | fn 的执行结果 | fn 的执行结果 | 一个新函数 |

### 六、`bind` 的不可覆盖特性

```javascript
function fn() {
  return this.name
}

const a = { name: 'A' }
const b = { name: 'B' }

const bound = fn.bind(a)

bound()           // 'A'
bound.call(b)     // 仍是 'A'！← call 无法覆盖 bind 的 this
bound.apply(b)    // 仍是 'A'
bound.bind(b)()   // 仍是 'A'
```

原因：`bind` 返回的 `boundFn` 内部用的是 `originalFn.apply(ctx, args)`，其中 `ctx` 是闭包捕获的变量——外部无论如何调用 `boundFn`，内部的 `ctx` 都不变。这就是"永久绑定"的底层原理。

### 七、面试速答

**Q1：`call` 和 `apply` 的区别？**
只有传参方式不同。`call(ctx, a, b, c)` 逐个传，`apply(ctx, [a, b, c])` 数组传。内部实现完全一样，就是传参不同。

**Q2：`bind` 和 `call/apply` 的核心区别？**
`call/apply` **立即调用**，一次性绑定；`bind` **返回新函数**，永久绑定（不可被后续 call/apply 覆盖），且支持柯里化（分批传参）。

**Q3：`bind` 返回的函数被 `new` 调用时 this 是谁？**
**以 `new` 创建的实例为准**，`bind` 时绑定的 `ctx` 失效。ES6 规范明确规定 `new` 的优先级高于 `bind`。实现中通过 `this instanceof boundFn` 来判断调用方式。

**Q4：为什么要用 Symbol 而不是字符串做临时属性名？**
防止跟 `ctx` 上已有的同名属性冲突。`Symbol('fn')` 每次创建都是唯一的。

**Q5：`ctx` 为什么要 `Object(ctx)` 包装？**
原始值（字符串/数字/布尔）没有属性，不能在上面挂方法。`Object()` 把原始值转成包装对象后才可以用作临时属性宿主。

---

---

## `Symbol()` 和 `new Symbol()` 的区别

### 一、先看结论

- `Symbol()`：**可以正常调用**
- `new Symbol()`：**会直接报错**

```javascript
const s1 = Symbol('id')
console.log(typeof s1) // "symbol"

const s2 = new Symbol('id') // TypeError: Symbol is not a constructor
```

---

### 二、为什么 `new Symbol()` 会报错

`Symbol` 的设计目标是：**创建一个唯一的原始值**。  
它不是普通构造函数，因此不能配合 `new` 使用。

也就是说：

- `Symbol()` 返回的是 **symbol 原始值**
- 不是“某个 Symbol 实例对象”

这和 `String`、`Number`、`Boolean` 不一样。

---

### 三、和 `String` / `Number` / `Boolean` 的对比

这些内置类型既可以当普通函数调用，也可以当构造函数调用：

```javascript
String(123)       // "123"
new String(123)   // String 包装对象

Number('12')      // 12
new Number('12')  // Number 包装对象

Boolean(1)        // true
new Boolean(1)    // Boolean 包装对象
```

但 `Symbol` 不行：

```javascript
Symbol('id')      // 合法，返回 symbol 原始值
new Symbol('id')  // 非法，直接报错
```

原因就在于：`Symbol` **没有提供构造器语义**。

---

### 四、那 Symbol 有没有“对象形态”

有，但不是通过 `new Symbol()` 得到的，而是通过 `Object()` 包装：

```javascript
const s = Symbol('id')
const obj = Object(s)

console.log(typeof s)   // "symbol"
console.log(typeof obj) // "object"
```

此时：

```javascript
obj instanceof Symbol // true
```

这里的 `obj` 是一个 **Symbol 包装对象**，本质和：

- `Object('abc')`
- `Object(123)`

类似，都是把原始值装箱成对象。

---

### 五、为什么一般不需要包装对象

日常开发里，通常只需要 `symbol` 原始值本身：

```javascript
const key = Symbol('key')

const obj = {
  [key]: 'secret'
}
```

这样已经足够。

包装对象反而容易增加理解成本，而且大多数场景没有必要。

---

### 六、一个容易混淆的点

下面这段是合法的：

```javascript
const s = Symbol('id')
console.log(Object(s))
```

但这段不合法：

```javascript
new Symbol('id')
```

两者差别在于：

- `Object(s)`：把一个已有的 symbol 原始值包装成对象
- `new Symbol()`：试图把 `Symbol` 当构造函数调用

而 `Symbol` 根本不是构造函数。

---

### 七、面试速答

**Q1：`Symbol()` 和 `new Symbol()` 的区别？**  
`Symbol()` 返回一个唯一的 symbol 原始值；`new Symbol()` 会报错，因为 `Symbol` 不是构造函数。

**Q2：为什么 `Symbol` 不能 `new`？**  
因为它的设计目标是创建原始值，不是创建实例对象。

**Q3：那 `obj instanceof Symbol` 为什么可能是 `true`？**  
因为那通常是 `Object(symbolValue)` 得到的 Symbol 包装对象，不是 `new Symbol()` 创建出来的。

---

### 八、一句话总结

`Symbol()` 用来创建唯一的 `symbol` 原始值；`new Symbol()` 不能用，因为 `Symbol` **不是构造函数**，如果真要对象形态，只能对已有的 symbol 值做 `Object()` 包装。

---

---

## `fn.length` 返回的是形参数目还是实参数目

### 一、先看结论

`fn.length` 返回的是：**函数定义时的形参数目**，不是调用时传入的实参数目。

```javascript
function foo(a, b, c) {}

console.log(foo.length) // 3
```

这里的 `3` 来自函数声明里的 `a、b、c`，也就是形参。

---

### 二、不是实参数目

```javascript
function foo(a, b) {}

foo(1)
foo(1, 2, 3)

console.log(foo.length) // 2
```

不管你调用时传 1 个、2 个还是 3 个参数，`foo.length` 都不会变。  
因为它统计的是**定义阶段的参数个数**，不是运行时实际传参个数。

---

### 三、和 `arguments.length` 的区别

这个点非常容易混淆：

```javascript
function foo(a, b, c) {
  console.log(foo.length)       // 3
  console.log(arguments.length) // 实际传入几个，就是几
}

foo(1)          // 3, 1
foo(1, 2, 3, 4) // 3, 4
```

区别如下：

- `fn.length`：看**形参数量**
- `arguments.length`：看**实参数量**

---

### 四、默认参数会影响 `length`

`length` 只统计：**第一个带默认值参数之前**的形参。

```javascript
function fn(a, b = 1, c) {}

console.log(fn.length) // 1
```

虽然写了 `a、b、c` 三个形参，但因为 `b` 已经有默认值了，所以从 `b` 开始，后面的参数都不计入 `length`。

再看几个例子：

```javascript
function a(x, y, z) {}
console.log(a.length) // 3

function b(x, y = 1, z) {}
console.log(b.length) // 1

function c(x = 1, y, z) {}
console.log(c.length) // 0
```

---

### 五、剩余参数 `...rest` 不计入 `length`

```javascript
function fn(a, b, ...rest) {}

console.log(fn.length) // 2
```

原因是剩余参数表示“收集剩下所有参数”，它本身不算普通定长形参。

---

### 六、解构参数也要注意

解构参数本质上仍然算一个形参：

```javascript
function fn({ a, b }, [x, y], c) {}

console.log(fn.length) // 3
```

但如果解构参数带默认值，规则仍然一样：

```javascript
function fn({ a, b } = {}, c) {}

console.log(fn.length) // 0
```

因为第一个参数已经有默认值了，所以后面的 `c` 也不计入。

---

### 七、箭头函数也有 `length`

```javascript
const sum = (a, b) => a + b
console.log(sum.length) // 2

const fn = (a, b = 1, ...rest) => {}
console.log(fn.length) // 1
```

箭头函数同样遵守这套规则。

---

### 八、这个属性有什么用

`fn.length` 在日常业务里不算高频，但在这些场景有意义：

1. 判断函数“期望接收多少参数”
2. 函数式编程中的柯里化实现
3. 某些框架/库根据函数参数长度做兼容处理

例如一个简单柯里化实现会依赖它：

```javascript
function curry(fn, ...args) {
  if (args.length >= fn.length) {
    return fn(...args)
  }
  return (...rest) => curry(fn, ...args, ...rest)
}
```

---

### 九、面试速答

**Q1：`fn.length` 返回的是形参数目还是实参数目？**  
返回形参数目，不是实参数目。

**Q2：`fn.length` 和 `arguments.length` 的区别？**  
`fn.length` 是函数定义时的参数个数；`arguments.length` 是调用时实际传入的参数个数。

**Q3：默认参数为什么会影响 `fn.length`？**  
因为规范规定：`length` 只统计第一个带默认值参数之前的形参。

**Q4：`...rest` 算进 `fn.length` 吗？**  
不算。

---

### 十、一句话总结

`fn.length` 看的是**函数声明时的形参结构**，不是调用时的实参数量；其中默认参数会截断统计，剩余参数 `...rest` 不计入。

---

---

## 函数参数默认值和 `??` 在什么情况下生效

### 一、先看结论

这两个机制最容易混淆，但触发条件不一样：

1. **函数参数默认值**：只在参数值是 `undefined` 时生效
2. **`??` 空值合并运算符**：只在左侧是 `null` 或 `undefined` 时生效

也就是说：

- 默认参数只认 `undefined`
- `??` 认 `null` 和 `undefined`

---

### 二、函数参数默认值什么时候生效

```javascript
function foo(x = 10) {
  console.log(x)
}
```

下面这些情况会触发默认值：

```javascript
foo()            // 10
foo(undefined)   // 10
```

下面这些情况**不会**触发默认值：

```javascript
foo(null)        // null
foo(0)           // 0
foo(false)       // false
foo('')          // ''
foo(NaN)         // NaN
```

#### 为什么

因为函数参数默认值的判断规则本质上是：

```javascript
if (x === undefined) {
  x = 10
}
```

它不是按“假值”判断的，也不是按“空值”判断的，而是**严格只看是不是 `undefined`**。

---

### 三、哪些场景下参数会变成 `undefined`

最常见的有两种：

#### 1. 调用时没传这个参数

```javascript
function foo(x = 10) {
  console.log(x)
}

foo() // 10
```

因为没传，形参 `x` 的值就是 `undefined`。

#### 2. 显式传了 `undefined`

```javascript
foo(undefined) // 10
```

这等价于告诉函数：

> “这个位置我就是要走默认值逻辑”

---

### 四、参数默认值和 `null` 的区别

这个点特别高频。

```javascript
function foo(x = 10) {
  console.log(x)
}

foo(null) // null
```

很多人以为这里会输出 `10`，其实不会。  
因为 `null !== undefined`，所以默认参数不会生效。

#### 一句话理解

- `undefined`：通常表示“没给值”
- `null`：通常表示“有意给了一个空值”

默认参数只把前者当成“该走默认值”。

---

### 五、`??` 在什么情况下生效

`??` 是“空值合并运算符”（nullish coalescing operator）。

```javascript
const result = a ?? b
```

它的规则是：

- 如果 `a` 是 `null` 或 `undefined`，结果取 `b`
- 否则结果取 `a`

例如：

```javascript
undefined ?? 100 // 100
null ?? 100      // 100

0 ?? 100         // 0
false ?? 100     // false
'' ?? 100        // ''
NaN ?? 100       // NaN
```

可以看到，`??` 也**不会**因为 `0 / false / ''` 这些值而触发右侧。

---

### 六、为什么 `??` 经常和 `||` 搞混

因为很多人以前习惯这样写默认值：

```javascript
const value = input || 100
```

但 `||` 的规则是：

> 左侧只要是“假值”（falsy），就取右侧

所以这些都会触发：

```javascript
0 || 100        // 100
false || 100    // 100
'' || 100       // 100
NaN || 100      // 100
```

这在很多业务里其实是错的，因为：

- `0` 可能是合法值
- `false` 可能是合法值
- 空字符串也可能是合法值

而 `??` 更精确，它只把：

- `null`
- `undefined`

当成“需要兜底”的情况。

---

### 七、参数默认值 vs `??` 的本质区别

看起来两者都像“给默认值”，但它们工作的层面不同。

#### 参数默认值

发生在**函数入参绑定阶段**：

```javascript
function foo(x = 10) {
  console.log(x)
}
```

意思是：

> “如果这个形参最终拿到的是 `undefined`，就用 `10`”

#### `??`

发生在**表达式求值阶段**：

```javascript
const x = value ?? 10
```

意思是：

> “如果左侧表达式结果是 `null` 或 `undefined`，就用右侧”

---

### 八、两个放在一起对比看

```javascript
function foo(x = 10) {
  console.log('x =', x)
  console.log('x ?? 20 =', x ?? 20)
}

foo()           // x = 10,   x ?? 20 = 10
foo(undefined)  // x = 10,   x ?? 20 = 10
foo(null)       // x = null, x ?? 20 = 20
foo(0)          // x = 0,    x ?? 20 = 0
```

这四次调用非常适合记忆差异：

1. `foo()`：参数默认值生效
2. `foo(undefined)`：参数默认值生效
3. `foo(null)`：参数默认值不生效，但 `??` 生效
4. `foo(0)`：两者都不生效

---

### 九、解构默认值也遵守同样规则

```javascript
function foo({ x = 1 } = {}) {
  console.log(x)
}

foo()               // 1
foo(undefined)      // 1
foo({})             // 1
foo({ x: undefined }) // 1
foo({ x: null })    // null
```

这里仍然遵守：

- 默认值只对 `undefined` 生效
- `null` 不会触发默认值

---

### 十、实战建议

#### 1. 只想让“没传参数”时走默认值

用函数默认参数：

```javascript
function request(timeout = 5000) {}
```

#### 2. 想让 `null` 和 `undefined` 都走兜底值

用 `??`：

```javascript
const title = data.title ?? '未命名'
```

#### 3. 不想让 `0 / false / ''` 被误伤

优先用 `??`，少用 `||`。

---

### 十一、面试速答

**Q1：函数参数默认值在什么情况下生效？**  
只在该参数的值是 `undefined` 时生效，包括“没传”和“显式传 `undefined`”两种情况。

**Q2：`null` 会触发函数参数默认值吗？**  
不会，因为默认参数只判断 `=== undefined`。

**Q3：`??` 在什么情况下生效？**  
当左侧是 `null` 或 `undefined` 时生效。

**Q4：为什么很多时候 `??` 比 `||` 更适合做默认值？**  
因为 `??` 不会把 `0`、`false`、`''` 这些合法值误判成“需要兜底”。

---

### 十二、一句话总结

函数参数默认值只对 `undefined` 生效；`??` 只对 `null` 和 `undefined` 生效；如果你要保留 `0 / false / ''` 这些合法值，就优先用 `??`，不要随手用 `||`。

---

---

## `Symbol()` 的内部实现思路

### 一、先说结论

`Symbol()` 的核心不是“返回一个字符串”，也不是“返回一个普通对象”，而是：

> **创建一个新的、唯一的、不可与其它值冲突的原始值。**

哪怕描述相同：

```javascript
const a = Symbol('id')
const b = Symbol('id')

console.log(a === b) // false
```

它们也永远不相等。

---

### 二、从语言层面看，`Symbol()` 大致做了什么

可以把它近似理解成下面这种“伪代码”：

```javascript
function Symbol(description) {
  const descString =
    description === undefined ? undefined : String(description)

  return createNewUniqueSymbolValue(descString)
}
```

这里最关键的不是 `description`，而是：

```javascript
createNewUniqueSymbolValue(...)
```

也就是说，每次调用 `Symbol()`，引擎都会创建一个**全新的内部符号值**。

#### `description` 是干什么的

`description` 只是一个调试辅助信息：

```javascript
const s = Symbol('token')
console.log(s) // Symbol(token)
```

它方便你打印和排查，但**不参与唯一性判断**。

所以：

```javascript
Symbol('x') === Symbol('x') // false
```

---

### 三、唯一性是怎么保证的

从实现思路上，你可以把每个 Symbol 想成：

> 引擎在内部生成的一张永不重复的“身份卡”

它不是靠字符串相等来判断，而是靠**内部身份标识**。

可以把概念近似想成：

```javascript
Symbol('id')  ->  { [[Type]]: 'Symbol', [[Id]]: 101, [[Description]]: 'id' }
Symbol('id')  ->  { [[Type]]: 'Symbol', [[Id]]: 102, [[Description]]: 'id' }
```

注意：

- 这不是 JS 里真的能看到的对象结构
- 只是帮助理解的伪模型

真正比较时，比的是那个内部唯一标识，而不是描述字符串。

所以：

```javascript
101 !== 102
```

也就意味着两个 Symbol 不相等。

---

### 四、为什么 `Symbol()` 不是字符串

如果 Symbol 只是字符串，那它就不能真正避免命名冲突。

例如：

```javascript
const obj = {
  id: 1
}
```

如果很多库都往对象上挂字符串键：

```javascript
obj.id = ...
obj.id = ...
```

就会互相覆盖。

而 Symbol 的意义就在于：

```javascript
const key1 = Symbol('id')
const key2 = Symbol('id')

const obj = {
  [key1]: 'A',
  [key2]: 'B'
}
```

虽然描述都叫 `'id'`，但它们内部身份不同，所以不会冲突。

---

### 五、为什么它适合做对象属性键

对象属性键在规范层面并不只有字符串一种。  
更准确地说，属性键（Property Key）可以是：

1. String
2. Symbol

所以：

```javascript
const key = Symbol('secret')
const obj = {
  [key]: 123
}
```

引擎内部不会把这个键简单当成 `'Symbol(secret)'` 字符串存进去，  
而是把它当成一个**真正的 Symbol 类型键**。

这也是为什么：

```javascript
Object.keys(obj) // []
```

因为 `Object.keys` 只取**可枚举的字符串键**，不取 Symbol 键。

如果要拿 Symbol 键，要用：

```javascript
Object.getOwnPropertySymbols(obj)
Reflect.ownKeys(obj)
```

---

### 六、为什么 `new Symbol()` 会报错

前面已经讲过：

```javascript
new Symbol() // TypeError
```

从内部设计角度看，这是因为 Symbol 的目标是：

> **生产一个原始值**

而不是像普通构造函数那样：

> “创建一个 this 对象实例，再把属性挂上去”

可以类比理解：

- `new String('a')`：创建包装对象
- `new Number(1)`：创建包装对象
- `Symbol('x')`：直接生成原始符号值

所以规范直接禁止把它当构造函数使用。

---

### 七、`Object(Symbol())` 做了什么

虽然 `new Symbol()` 不允许，但：

```javascript
const s = Symbol('id')
const obj = Object(s)
```

是允许的。

这一步并不是“重新创建一个 Symbol”，而是：

> **把一个已经存在的 symbol 原始值装箱成包装对象**

可以近似理解成：

```javascript
{
  [[SymbolData]]: s
}
```

所以：

```javascript
typeof s   // "symbol"
typeof obj // "object"
```

这里的 `obj` 只是一个外层壳，内部仍然包着那个原始 symbol 值。

---

### 八、`Symbol.for()` 为什么又能“相等”

普通 `Symbol()` 每次都创建新值：

```javascript
Symbol('x') === Symbol('x') // false
```

但：

```javascript
Symbol.for('x') === Symbol.for('x') // true
```

这是因为 `Symbol.for()` 不是“无条件创建新 Symbol”，而是走了**全局符号注册表**思路。

你可以把它近似理解成：

```javascript
globalSymbolRegistry = {
  x: someSharedSymbol
}
```

执行：

```javascript
Symbol.for('x')
```

时，引擎会做类似：

1. 先查全局注册表里有没有 key 为 `'x'` 的 Symbol
2. 有就直接返回已有的那个
3. 没有才创建新的，并登记进去

所以 `Symbol.for()` 的重点不是“唯一新建”，而是“**按 key 复用共享 Symbol**”。

---

### 九、引擎实现上大致会关心什么

如果再往底层想一层，引擎大致会为 Symbol 维护这些信息：

1. 这是一个独立的原始类型
2. 每个值有唯一身份标识
3. 可选的 description 仅用于调试显示
4. 作为属性键时，要和字符串键分开处理
5. `Symbol.for()` 要额外查全局注册表

也就是说，Symbol 的难点不是“语法看起来特殊”，而是：

> 引擎需要把它当成一种真正独立的 primitive，并在对象属性系统里给它专门的位置。

---

### 十、为什么前端需要理解这一层

理解 Symbol 的内部思路后，很多行为就不再是死记硬背：

#### 1. 为什么同描述也不相等

因为比较的是内部身份，不是 description。

#### 2. 为什么适合做私有/半私有键

因为不会和字符串键冲突，也不容易被普通枚举拿到。

#### 3. 为什么 `Object.keys()` 拿不到

因为它本来就不是字符串属性键。

#### 4. 为什么 `Symbol.for()` 和 `Symbol()` 行为不同

一个是“每次新建”，一个是“注册表复用”。

---

### 十一、面试速答

**Q1：`Symbol()` 内部为什么能保证唯一？**  
因为每次调用都会创建一个新的内部符号值，比较时看的是内部身份标识，不是 description。

**Q2：`description` 参与相等性判断吗？**  
不参与，它主要用于调试显示。

**Q3：为什么 Symbol 能当对象 key 但不和字符串冲突？**  
因为属性键在规范里既可以是 String，也可以是 Symbol；引擎内部会把这两类键分开处理。

**Q4：`Symbol.for()` 和 `Symbol()` 的本质区别？**  
`Symbol()` 每次创建新值；`Symbol.for()` 先查全局符号注册表，相同 key 会复用同一个 Symbol。

---

### 十二、一句话总结

`Symbol()` 的内部本质不是“生成一段特殊字符串”，而是**创建一个带唯一身份标识的原始值**；`description` 只负责可读性，真正的唯一性来自引擎内部的 symbol identity。

#### 补充：这里说的“原始值”该怎么理解

这里的“原始值”（primitive）含义是：

> **它不是对象，不是引用类型，而是 JavaScript 语言层面最基础的值单位。**

JavaScript 的原始值包括：

1. `undefined`
2. `null`
3. `boolean`
4. `number`
5. `string`
6. `bigint`
7. `symbol`

所以从“值分类”上说，`symbol` 和：

- `string`
- `number`
- `boolean`

确实是同一大类，都是 primitive。

---

#### 1. 它和 `string` / `number` / `boolean` 的共同点

例如：

```javascript
typeof 'abc'        // "string"
typeof 123          // "number"
typeof true         // "boolean"
typeof Symbol('x')  // "symbol"
```

这些值的共同点是：

- 都不是普通对象
- 都可以被装箱成对象，但本体仍然是原始值
- 都不靠“对象属性集合”来描述自己

例如：

```javascript
const s = Symbol('x')
const obj = Object(s)

console.log(typeof s)   // "symbol"
console.log(typeof obj) // "object"
```

这里 `s` 是原始值，`obj` 才是包装对象。

---

#### 2. 真正不一样的地方：`symbol` 是“身份型原始值”

`string`、`number`、`boolean` 这些 primitive，更像是**内容型值**。

例如：

```javascript
'a' === 'a'   // true
1 === 1       // true
true === true // true
```

它们是否相等，取决于：

- 字符串内容是否相同
- 数值是否相同
- 布尔值是否相同

但 `symbol` 不一样。

```javascript
Symbol('x') === Symbol('x') // false
```

这里两个 Symbol 的 `description` 都是 `'x'`，  
但每次调用 `Symbol()` 都会得到一个**新的 symbol 原始值**。

所以 `symbol` 的“值”不是那段描述文字，而是：

> **这个 symbol 自己那份独一无二的身份**

---

#### 3. 可以把它理解成“带唯一身份的 primitive”

这就是 `symbol` 最特殊的地方：

- 它和 `string` / `number` / `boolean` 一样，属于原始值
- 但它的值语义不是“内容”，而是“身份”

可以这样对比理解：

- `string` 的值更像“文本内容”
- `number` 的值更像“数值大小”
- `boolean` 的值更像“真或假”
- `symbol` 的值更像“唯一令牌”

所以前面那句“创建一个带唯一身份标识的原始值”，重点不在“原始值”三个字，而在：

> **这个 primitive 的值本身就是 identity，而不是可重复的内容。**

---

#### 4. 它和对象的“唯一性”也不是一回事

对象也有身份，例如：

```javascript
{} === {} // false
```

但对象是**引用类型**，而 `symbol` 不是对象。

所以 `symbol` 很特别：

> **它是 primitive，但又像对象一样具有“唯一身份语义”。**

这也是为什么很多人第一次学 Symbol 会觉得它“既像基本类型，又像引用类型”。

更准确地说：

- 从类型分类上，它是 primitive
- 从相等性语义上，它又带有很强的 identity 特征

---

#### 5. 一句话把这个点说透

`symbol` 和 `string` / `number` / `boolean` 一样，都属于原始值；不同的是，前几者的值更像“内容”，而 `symbol` 的值本身就是一个**独一无二的身份令牌**。
