# ArkTS/ETS 核心编码规范
1.  仅限 **ArkTS + ArkUI(ETS)** 技术栈，禁用React/Vue/Node/DOM相关范式。仅导入IDE可解析的符号（支持跳转至定义），禁止臆测导出内容。
2.  UI组件语法（Column/Row/Text/Stack等）**仅限**写在`@Entry @Component struct ... { build() { ... } }`内，其他文件均为纯ArkTS逻辑代码（类/接口/函数），不得在管理器/算法/模型中编写UI DSL。
3.  禁用解构赋值/声明及参数解构（如`const {a}=obj`、`[x,y]=arr`、`fn({a})`）；禁止使用`any`/`unknown`类型；所有函数参数和返回值类型必须显式声明。
4.  禁止内联对象类型或无类型对象字面量，必须先声明`interface`或`class`，再基于该类型赋值/返回（示例：`const x: Foo = { a: 1 }`）；`map()`返回对象时，需通过显式接口/类指定类型。
5.  对象属性名必须为合法标识符，禁用带引号或非标识符形式（如`{'a-b': 1}`）。
6.  禁止直接将`Set<string>`传入需`string`类型的参数，需先转换（如`Array.from(set).join(',')`或显式选取单个元素）。
7.  仅限使用已验证的ArkUI动画API（`animateTo`/`transition`/`animation`）及IDE确认存在的曲线/枚举；未验证可用性前，禁用`Curve.EaseOutBack`/`Curve.Spring`；避免在组件属性上链式调用`onFinish`，改用`animateTo`回调或Promise包装。
8. 代码生成仅修改指定文件；新增文件需列明精确路径及用途。输出需遵循“简短变更说明+分文件代码”结构，且保证代码可编译。
禁止用any和unknown类型，所有函数参数和返回值类型必须显式声明。