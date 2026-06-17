# 微信小程序架构设计详解

## 一、概述

微信小程序(WeChat Mini Program)是一种不需要下载安装即可使用的应用,它实现了应用"触手可及"的梦想,用户扫一扫或搜一下即可打开应用。微信小程序的架构设计体现了"快速、安全、跨平台"的核心理念,采用了一套独特的双线程模型架构。

---

## 二、整体架构:双线程模型

微信小程序的核心架构是 **双线程模型(Dual-Thread Model)**,由 **渲染层(View)** 和 **逻辑层(AppService)** 两个线程构成,通过微信客户端(Native)作为桥梁进行通信。

```
┌─────────────────────────────────────────────────────┐
│                    微信客户端 (Native)               │
│  ┌─────────────────────────────────────────────┐   │
│  │              JSBridge 通信桥                 │   │
│  └─────────────────────────────────────────────┘   │
│         ↑                            ↑              │
│         │                            │              │
│  ┌──────┴──────┐              ┌──────┴──────┐      │
│  │   渲染层     │              │   逻辑层     │      │
│  │  (View)     │  ←─事件/数据→ │ (AppService)│      │
│  │ WebView/    │              │ JsCore/     │      │
│  │ Skyline     │              │ V8/JSCore   │      │
│  │ WXML+WXSS   │              │ JavaScript  │      │
│  └─────────────┘              └─────────────┘      │
└─────────────────────────────────────────────────────┘
```

### 2.1 渲染层 (View Thread)

- **职责**:负责页面渲染,即 WXML 模板和 WXSS 样式的解析与展示
- **运行环境**:
  - iOS:WKWebView
  - Android:旧版使用 X5(基于 Chrome 53)内核,新版使用 XWeb(基于 Chrome 86+)
  - 开发工具:Chromium 内核
- **特点**:每个小程序页面对应一个独立的 WebView,因此一个小程序可能同时存在多个渲染层线程

### 2.2 逻辑层 (AppService Thread)

- **职责**:负责执行 JavaScript 业务逻辑、数据处理、API 调用、生命周期管理
- **运行环境**:
  - iOS:JavaScriptCore
  - Android:旧版 V8 引擎,新版 V8(XWeb 提供)
  - 开发工具:NW.js (基于 V8)
- **特点**:整个小程序只有一个逻辑层线程,所有页面共享

### 2.3 双线程通信机制

渲染层和逻辑层无法直接通信,所有交互必须经过 **微信客户端(Native)** 中转:

1. **数据传递**:逻辑层通过 `setData` 将数据传给渲染层,数据先序列化为字符串,经 Native 转发后再反序列化
2. **事件传递**:用户在视图上的操作(点击等)由渲染层捕获,经 Native 转发到逻辑层
3. **API 调用**:逻辑层调用的微信 API 由 Native 执行后返回结果

> ⚠️ **性能关键点**:`setData` 数据需经过序列化/反序列化和跨线程传递,所以频繁、大数据量的 setData 会成为性能瓶颈。

---

## 三、WebView 详解

### 3.1 什么是 WebView

**WebView** 是一种**嵌入在原生应用(Native App)中的浏览器内核组件**,它能让原生应用在内部加载并渲染网页内容(HTML/CSS/JS)。可以简单理解为:

> **WebView ≈ 没有地址栏、前进后退按钮等 UI 的浏览器,被宿主原生 App 完全控制。**

宿主 App 决定它加载什么内容、何时销毁、如何与原生层通信,因此 WebView 是 Native 与 Web 技术之间的"桥梁组件"。

### 3.2 WebView 在各平台的实现

| 运行平台              | WebView 实现        | 内核引擎                          |
|-----------------------|---------------------|-----------------------------------|
| iOS                   | **WKWebView**       | Apple WebKit                      |
| iOS (旧版,已废弃)    | UIWebView           | WebKit(性能较差)                 |
| Android(旧版微信)   | **X5 内核**         | 腾讯自研,基于 Chromium 53        |
| Android(新版微信)   | **XWeb**            | 腾讯升级,基于 Chromium 86+       |
| 微信开发者工具        | Chromium WebView    | Google Chrome 内核                |

> 微信在 Android 端没有直接使用系统 WebView,是因为不同厂商的系统 WebView 版本碎片化严重(从 Android 4.4 的 Chromium 30 到最新的 100+),为保证一致性,微信选择内置统一的 X5 / XWeb 内核。

### 3.3 WebView 在小程序中的角色

在小程序的双线程架构中,WebView 承担**渲染层(View)** 的工作:

- 加载小程序的**渲染层基础库**(`WAWebview.js`)
- 解析 WXML 编译生成的**虚拟 DOM 描述**(JSON 数据结构)
- 解析 WXSS 编译生成的**样式规则**(经过 rpx 等处理后的 CSS)
- 执行渲染指令,将界面绘制到屏幕
- 捕获用户事件(点击、滚动、输入等)并通过 JSBridge 转发到逻辑层

```
┌──────────────────────────────────────────────────┐
│                  WebView 实例                     │
│  ┌────────────────────────────────────────────┐  │
│  │  WAWebview.js (微信渲染层基础库)            │  │
│  │  - Exparser/glass-easel 组件系统           │  │
│  │  - 虚拟 DOM diff 算法                       │  │
│  │  - 事件冒泡 & 捕获机制                      │  │
│  └────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────┐  │
│  │  开发者编写的 WXML / WXSS (编译产物)        │  │
│  └────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────┐  │
│  │  浏览器内核 (WebKit / XWeb / Chromium)      │  │
│  │  - 布局、绘制、合成                         │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
            ↕ JSBridge
       与逻辑层通信
```

### 3.4 WebView 中被禁用的能力

相比浏览器,小程序中的 WebView **大幅裁剪了 Web API**,以保证安全与可控:

| 被禁用的能力               | 原因                                         |
|----------------------------|----------------------------------------------|
| `window`、`document`       | 防止直接操作 DOM、规避数据驱动模型           |
| `localStorage`、`cookie`   | 防止越权存储、数据应通过 wx API 管理         |
| `<script>` 动态加载外部 JS | 防止开发者绕过审核加载未知代码               |
| `<a href>` 跳转外链        | 防止跳转钓鱼/外部站点,杜绝逃逸              |
| `alert`、`confirm`         | 统一交互体验,使用 `wx.showModal` 替代       |
| 部分 CSS 选择器(如 `*`)  | 性能与兼容性考虑                             |

### 3.5 一个页面 = 一个 WebView 实例

- 用户每打开一个新页面,微信会**新建一个 WebView 实例**来承载它
- 因此小程序在运行时可能同时存在**多个 WebView**(与页面栈对应,上限 10 层)
- 这也是小程序内存占用偏高的原因之一
- 而逻辑层(AppService)在整个小程序生命周期中**只有一个**

### 3.6 同层渲染(Same Layer Rendering)

由于 `<video>`、`<map>`、`<canvas type="2d">` 等**原生组件**由客户端直接渲染,默认层级最高,会**遮挡 WebView 中的普通 DOM 元素**,带来层级错乱问题。

为此微信引入了**同层渲染**机制:

- 将原生组件**嵌入到 WebView 的渲染流中**,与普通 DOM 元素同处一个渲染层
- 支持 CSS `position`、`z-index`、`transform`、动画等
- **iOS**:基于 WKWebView 的 WKChildScrollView 实现
- **Android**:基于 XWeb 的 Surface 同层渲染机制

启用同层渲染后,不再需要 `cover-view`/`cover-image` 等覆盖组件即可在原生组件之上叠加普通元素。

### 3.7 WebView ≠ `<web-view>` 组件

注意区分两个**容易混淆**的概念:

| 概念                  | 含义                                                                |
|-----------------------|---------------------------------------------------------------------|
| **WebView (架构层)**  | 渲染层的运行容器,**开发者不可感知**,微信底层实现                  |
| **`<web-view>` 组件** | 小程序提供的**业务组件**,用于嵌入加载企业自有的 H5 页面            |

`<web-view>` 组件使用要点:
- **仅企业类型小程序可用**(个人号不能用)
- 加载的页面**域名必须配置**在管理后台的"业务域名"中
- H5 页面可通过 `wx.miniProgram.postMessage` 与小程序通信
- 不能在分享卡片中使用

### 3.8 WebView 架构的性能瓶颈

WebView 虽然兼容性好,但存在天然性能限制,这也是微信推出 **Skyline 引擎**(详见第七章)的根本动机:

1. **`setData` 跨线程通信开销**:数据需序列化 → Native 转发 → 反序列化,大数据量 setData 易卡顿
2. **DOM 渲染性能上限**:复杂列表、大量节点会引起重排重绘,低端机表现明显下滑
3. **CSS 动画性能不稳定**:特别在复杂层叠场景下容易掉帧
4. **首屏耗时**:WebView 启动 + 基础库注入 + WXML 解析存在可观察的白屏时间
5. **内存占用高**:多个 WebView 实例 + 内核常驻,小程序占用内存往往超过同类原生页面

---

## 四、为什么采用双线程架构

### 4.1 安全性考虑
- 通过隔离 JS 执行环境和渲染环境,**禁止开发者直接操作 DOM**,防止 XSS 攻击
- 禁用了如 `window`、`document`、`localStorage` 等浏览器 API,杜绝跳转外链、操作 DOM 等不可控行为
- 防止开发者通过脚本动态修改页面跳转到外部站点

### 4.2 性能与可控性
- 逻辑层与渲染层并行执行,逻辑处理不会阻塞 UI 渲染
- 微信能够对小程序的能力和性能进行统一管控
- 提供原生级别的组件(Native Component),如 `<video>`、`<map>`、`<canvas>` 等,直接由客户端渲染

### 4.3 跨平台一致性
- 通过抽象层屏蔽 iOS、Android 平台差异
- 统一的 API 和组件规范

---

## 五、文件结构与项目组成

一个典型的小程序项目结构:

```
miniprogram/
├── app.js              # 全局逻辑入口
├── app.json            # 全局配置(页面路由、窗口、tabBar 等)
├── app.wxss            # 全局样式
├── project.config.json # 项目配置(开发者工具相关)
├── sitemap.json        # 搜索索引配置
└── pages/
    └── index/
        ├── index.js    # 页面逻辑
        ├── index.json  # 页面配置
        ├── index.wxml  # 页面结构(类似 HTML)
        └── index.wxss  # 页面样式(类似 CSS)
```

### 5.1 四种核心文件类型

| 文件类型 | 作用                | 对应 Web 类比       |
|----------|---------------------|---------------------|
| WXML     | 页面结构模板        | HTML                |
| WXSS     | 页面样式            | CSS(增加 rpx 单位) |
| JS       | 页面/全局逻辑       | JavaScript          |
| JSON     | 页面/全局配置       | JSON 配置文件        |

---

## 六、运行时框架

### 6.1 启动流程

```
用户打开小程序
    ↓
微信客户端下载小程序代码包(首次)或读取缓存
    ↓
注入运行环境(WebView + JsCore)
    ↓
执行 app.js 中的 App() 生命周期
    ↓
加载首页对应的 WXML/WXSS/JS
    ↓
执行 Page() 生命周期 (onLoad → onShow → onReady)
    ↓
页面渲染完成
```

### 6.2 生命周期

**App 级生命周期**:`onLaunch` → `onShow` → `onHide` → `onError`

**Page 级生命周期**:`onLoad` → `onShow` → `onReady` → `onHide` → `onUnload`

**Component 级生命周期**:`created` → `attached` → `ready` → `moved` → `detached`

### 6.3 页面栈机制

- 小程序维护一个页面栈,栈中最多保留 **10 层** 页面
- 页面跳转 API:`navigateTo`(入栈)、`redirectTo`(替换栈顶)、`navigateBack`(出栈)、`switchTab`(切换 tab)、`reLaunch`(重启)

---

## 七、新一代渲染引擎:Skyline

为了突破 WebView 的性能限制,微信推出了自研渲染引擎 **Skyline**:

- **架构**:逻辑层与渲染层合并,共用 JS 引擎,渲染由 Skyline 原生渲染
- **优势**:
  - 渲染性能接近原生
  - 内存占用更低
  - 支持手势系统、Worklet 动画、Snapshot 等高级特性
  - 不再受 WebView 的限制
- **使用**:通过在 `app.json` 中配置 `renderer: "skyline"` 启用

```json
{
  "renderer": "skyline",
  "componentFramework": "glass-easel",
  "lazyCodeLoading": "requiredComponents"
}
```

---

## 八、网络与数据存储

### 8.1 网络通信
- 提供 `wx.request`、`wx.uploadFile`、`wx.downloadFile`、`wx.connectSocket` 等 API
- 所有网络请求域名必须在管理后台预先配置(HTTPS / WSS)
- 单个小程序同时最多 10 个 `request` 并发请求

### 8.2 本地存储
- `wx.setStorage` / `wx.getStorage`:单 key 上限 1MB,总上限 10MB
- 数据隔离:不同小程序间数据完全隔离

---

## 九、原生组件(Native Component)

部分组件由客户端直接渲染,而非 WebView:

- `<video>`、`<live-player>`、`<camera>`、`<map>`、`<canvas type="2d">`、`<input>`(部分情况)

**特点**:
- 渲染性能高
- 层级最高,普通组件无法覆盖(需用 `cover-view`/`cover-image`)
- 不支持部分 CSS 属性

---

## 十、分包加载机制

为优化首屏启动速度,小程序代码包有大小限制:

- 单个分包/主包大小不超过 **2MB**
- 整个小程序所有分包大小不超过 **20MB**

**分包类型**:
1. **普通分包**:用户访问对应页面时下载
2. **独立分包**:可独立运行,不依赖主包
3. **分包预下载**:进入特定页面后台预下载其它分包
4. **分包异步化**:跨分包引用组件/JS,按需异步加载

---

## 十一、与 Web 开发的对比

| 维度         | Web 开发              | 小程序开发                    |
|--------------|-----------------------|-------------------------------|
| 运行环境     | 浏览器                 | 微信客户端                     |
| DOM 操作     | 直接操作               | 禁止,通过 setData 数据驱动    |
| 路由         | URL                    | 页面栈管理                     |
| 多线程       | 单线程(主线程渲染)   | 双线程(逻辑/渲染分离)         |
| 组件         | HTML 标签              | 内置组件 + 自定义组件          |
| 样式单位     | px、rem、em            | rpx(响应式像素)+ 常规单位     |
| 权限管控     | 浏览器同源策略         | 域名白名单 + 平台审核          |

---

## 十二、架构演进

1. **早期(2017)**:经典 WebView + JsCore 双线程架构
2. **2020**:推出自定义组件框架升级(基于 exparser)
3. **2022**:推出 Skyline 渲染引擎预览
4. **2023+**:Skyline 正式发布、glass-easel 组件框架开源
5. **持续演进**:同层渲染优化、WebAssembly 支持、Worklet 等

---

## 十三、参考资料链接

### 官方文档
- [微信小程序官方文档(首页)](https://developers.weixin.qq.com/miniprogram/dev/framework/)
- [小程序框架 - 框架接口](https://developers.weixin.qq.com/miniprogram/dev/reference/)
- [小程序运行机制](https://developers.weixin.qq.com/miniprogram/dev/framework/runtime/)
- [小程序代码构成](https://developers.weixin.qq.com/miniprogram/dev/framework/quickstart/code.html)
- [Skyline 渲染引擎介绍](https://developers.weixin.qq.com/miniprogram/dev/framework/runtime/skyline/introduction.html)
- [自定义组件 - glass-easel](https://developers.weixin.qq.com/miniprogram/dev/framework/custom-component/)
- [分包加载](https://developers.weixin.qq.com/miniprogram/dev/framework/subpackages.html)
- [小程序性能优化](https://developers.weixin.qq.com/miniprogram/dev/framework/performance/)

### 官方技术博客 / 社区
- [微信开放社区](https://developers.weixin.qq.com/community/develop/article)
- [小程序架构演进文章合集](https://developers.weixin.qq.com/community/develop/article/doc/000aaa547987880d3c2a76ec851813)

### 开源项目
- [glass-easel(微信小程序组件框架,已开源)](https://github.com/wechat-miniprogram/glass-easel)
- [WeUI(微信官方设计组件库)](https://github.com/Tencent/weui-wxss)

### 优质技术解读文章
- [《微信小程序架构剖析》(掘金)](https://juejin.cn/post/6844903879570423821)
- [《小程序底层实现原理及一些思考》(知乎)](https://zhuanlan.zhihu.com/p/81775922)
- [《一文读懂小程序双线程架构》(InfoQ)](https://www.infoq.cn/article/wechat-miniprogram-architecture)

### 工具链
- [微信开发者工具下载](https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html)
- [小程序云开发](https://developers.weixin.qq.com/miniprogram/dev/wxcloud/basis/getting-started.html)

---

## 十四、总结

微信小程序的架构设计本质上是 **以安全为前提、以性能为目标、以跨平台一致性为基础** 的工程实践:

- **双线程模型** 解决了安全与可控性问题,代价是引入了通信开销
- **Native 组件** 弥补了 WebView 在富媒体场景下的性能短板
- **Skyline 渲染引擎** 标志着小程序从"Web 体验"向"原生体验"的跃迁
- **分包加载** 和 **按需注入** 持续优化启动性能

理解小程序的双线程架构,是写出高性能小程序的关键,尤其是要注意 `setData` 的调用频率和数据量,这是绝大多数小程序性能问题的根源。
