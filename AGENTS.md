# HarmonyOS NEXT 开发核心规则与最佳实践

本文档基于 Huawei 开发者官方文档及社区最佳实践整理，适用于 HarmonyOS NEXT (API 12+) 开发。

## 1. ArkTS 语言规范 (强制)

ArkTS 是 HarmonyOS NEXT 的主力开发语言，基于 TypeScript 扩展，但在运行时有更严格的限制以提升性能。

### 1.1 严格类型安全
- **禁止使用 `any` 和 `unknown`**：必须显式声明变量和函数返回值的类型。
- **禁止运行时动态特性**：不支持动态添加属性、删除属性等 JS 动态操作。
- **空安全**：启用严格空检查 (`strictNullChecks`)，并在代码中显式处理 `null` 和 `undefined`。
- **ESObject**：仅在与 JS 库交互或跨语言调用时使用 `ESObject`，并在使用完毕后尽快转换为具体的 ArkTS 类型。

### 1.2 语法限制
- **类定义**：必须在声明时初始化字段，或在构造函数中初始化。
- **模块化**：使用 ES6 模块标准 (`import`/`export`)，禁止使用 CommonJS (`require`).
- **并发模型**：ArkTS 采用 Actor 模型，内存隔离。线程间通信需通过 `TaskPool` 或 `Worker`，数据传递通常是深拷贝或 Transferable 对象。

## 2. ArkUI 开发规范

### 2.1 组件化设计
- **`@Component`**：UI 组件必须使用 `@Component` 装饰。
- **`@Entry`**：页面入口组件使用 `@Entry` 装饰。
- **`@Builder` / `@BuilderParam`**：轻量级 UI 复用，优先于自定义组件，减少组件实例开销。
- **组件拆分**：将复杂页面拆分为多个子组件，保持代码清晰，每个组件文件不超过 500 行。

### 2.2 状态管理
- **原则**：最小化状态共享范围，避免全局状态滥用。
- **装饰器选择**：
  - `@State`：组件内部私有状态。
  - `@Prop`：父子单向同步（父 -> 子）。
  - `@Link`：父子双向同步（父 <-> 子）。
  - `@Provide`/`@Consume`：跨组件层级同步。
  - `AppStorage`/`LocalStorage`：全局或页面级状态共享。
- **更新机制**：状态变量必须通过赋值更新，不要直接修改对象属性（除非使用 `@Observed` 和 `@ObjectLink` 处理嵌套对象）。

### 2.3 布局与样式
- **单位**：统一使用 `vp` (虚拟像素) 和 `fp` (字体像素)，禁止硬编码 `px`。
- **布局性能**：
  - 减少布局嵌套层级（特别是 `Stack` 和 `Flex` 的深层嵌套）。
  - 优先使用 `RelativeContainer` 替代复杂的嵌套布局。
  - 列表渲染必须使用 `LazyForEach`，并提供唯一的 `keyGenerator`，避免全量重绘。
- **自适应**：使用断点 (`GridRow`/`GridCol`) 和媒体查询适配多设备屏幕。

## 3. 性能优化指南

### 3.1 渲染性能
- **LazyForEach**：长列表数据必须使用 `LazyForEach` 加载，配合 `cachedCount` 预加载。
- **条件渲染**：频繁切换显隐建议使用 `visibility` 属性控制，而非 `if/else`（后者会触发生命周期）。
- **图片优化**：加载大图时使用 `Image` 组件的 `sourceSize` 属性进行解码尺寸裁剪，避免内存浪费。

### 3.2 并发与异步
- **主线程减负**：耗时操作（IO、复杂计算、网络请求）必须移至后台线程。
- **TaskPool**：优先使用 `TaskPool` 处理短时任务，系统会自动管理线程生命周期。
- **Worker**：适用于长时间运行的后台任务。
- **Promise**：异步操作统一使用 Promise 或 async/await，避免回调地狱。

### 3.3 内存管理
- **资源释放**：组件销毁时 (`aboutToDisappear`) 及时注销事件监听、定时器和后台任务。
- **上下文泄漏**：避免在长生命周期对象中持有 AbilityContext 或 UI 组件引用。

## 4. 项目架构与工程规范

### 4.1 目录结构
```text
entry/src/main/ets/
├── pages/          # 页面入口 (@Entry)
├── components/     # 公共 UI 组件
├── model/          # 数据模型 (Class/Interface)
├── utils/          # 工具类
├── service/        # 业务逻辑服务 (API, Database)
├── common/         # 全局常量、枚举
└── resources/      # 静态资源
```

### 4.2 命名规范
- **类/接口/组件**：PascalCase (e.g., `UserComponent`, `DataService`)
- **变量/函数/方法**：camelCase (e.g., `fetchUserData`, `isOpen`)
- **常量/枚举值**：UPPER_SNAKE_CASE (e.g., `MAX_RETRY_COUNT`)
- **文件命名**：与主要导出内容一致，组件文件通常 PascalCase，工具文件 camelCase。

### 4.3 Kit 使用
- 优先使用 HarmonyOS 内置 Kit (如 `ArkData` 用于数据库, `NetworkKit` 用于网络, `ArkUI` 用于界面)。
- 引入第三方库前需确认其是否支持 HarmonyOS NEXT (ArkTS 兼容性)。

## 5. 安全与隐私

- **权限最小化**：仅申请业务必须的权限 (`module.json5`)。
- **用户授权**：运行时敏感权限必须向用户动态申请。
- **数据安全**：
  - 敏感数据（Token、密码）存储使用 `WebDavCrypto` 或系统级 `KeyStore`。
  - 本地数据库优先使用 `RdbStore` 或 `Preferences` 并加密。
