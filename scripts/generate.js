#!/usr/bin/env node
/**
 * ArkTS 开发辅助脚本
 * 用于快速生成组件、页面、视图等模板代码
 */

const fs = require('fs');
const path = require('path');

// 获取命令行参数
const [,, action, name, ...args] = process.argv;

// 项目源目录
const SRC_DIR = path.join(__dirname, '..', 'entry', 'src', 'main', 'ets');

/**
 * 创建页面组件
 */
function createPage(pageName) {
  const pagePath = path.join(SRC_DIR, 'pages', `${pageName}.ets`);
  
  const content = `import router from '@ohos.router';

/**
 * ${pageName} 页面
 * @description TODO: 添加页面描述
 */
@Entry
@Component
struct ${capitalize(pageName)} {
  @State message: string = 'Hello ${pageName}'

  aboutToAppear(): void {
    // TODO: 页面加载时的初始化
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button() {
          Image($r('sys.media.ohos_ic_public_back'))
            .width(24)
            .height(24)
        }
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back()
        })

        Text('${formatPageName(pageName)}')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .flexGrow(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 48 })

        // 右侧占位，保持标题居中
        Blank()
          .width(48)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#007DFF')

      // 页面内容
      Scroll() {
        Column() {
          Text(this.message)
            .fontSize(24)
            .margin(20)

          // TODO: 添加页面内容
        }
        .width('100%')
        .padding(16)
      }
      .scrollable(ScrollDirection.Vertical)
      .width('100%')
      .flexGrow(1)
    }
    .width('100%')
    .height('100%')
  }
}

/**
 * 格式化页面名称
 */
function formatPageName(name: string): string {
  return name.replace(/([A-Z])/g, ' $1').trim()
}

function capitalize(str: string): string {
  return str.charAt(0).toUpperCase() + str.slice(1)
}
`;

  ensureDir(path.dirname(pagePath));
  fs.writeFileSync(pagePath, convertToArkTS(content), 'utf-8');
  console.log(`✓ 页面已创建：${pagePath}`);
}

/**
 * 创建自定义组件
 */
function createComponent(componentName) {
  const componentPath = path.join(SRC_DIR, 'components', `${componentName}.ets`);
  
  const content = `/**
 * ${componentName} 组件
 * @description TODO: 添加组件描述
 */
@Component
export struct ${capitalize(componentName)} {
  // TODO: 定义输入属性
  // @Prop title: string = ''
  
  // TODO: 定义输出事件
  // onClick?: () => void = () => {}

  build() {
    // TODO: 实现组件 UI
    Column() {
      Text('${formatComponentName(componentName)}')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding(16)
  }
}

function formatComponentName(name: string): string {
  return name.replace(/([A-Z])/g, ' $1').trim()
}

function capitalize(str: string): string {
  return str.charAt(0).toUpperCase() + str.slice(1)
}
`;

  ensureDir(path.dirname(componentPath));
  fs.writeFileSync(componentPath, convertToArkTS(content), 'utf-8');
  console.log(`✓ 组件已创建：${componentPath}`);
}

/**
 * 创建数据模型
 */
function createModel(modelName) {
  const modelPath = path.join(SRC_DIR, 'models', `${modelName}.ts`);
  
  const content = `/**
 * ${modelName} 数据模型
 * @description TODO: 添加模型描述
 */
export interface ${capitalize(modelName)} {
  // TODO: 定义属性
  id: string
  createdAt: number
  updatedAt: number
}

/**
 * 创建 ${modelName} 实例
 */
export function create${capitalize(modelName)}(data: Partial<${capitalize(modelName)}>): ${capitalize(modelName)} {
  return {
    id: data.id || '',
    createdAt: data.createdAt || Date.now(),
    updatedAt: data.updatedAt || Date.now(),
    ...data
  } as ${capitalize(modelName)}
}
`;

  ensureDir(path.dirname(modelPath));
  fs.writeFileSync(modelPath, content, 'utf-8');
  console.log(`✓ 模型已创建：${modelPath}`);
}

/**
 * 创建 API 服务
 */
function createApi(serviceName) {
  const apiPath = path.join(SRC_DIR, 'apis', `${serviceName}.ts`);
  
  const content = `import http from '@ohos.net.http'
import { Logger } from '../utils/Logger'

const TAG = '${capitalize(serviceName)}Api'
const BASE_URL = 'https://api.example.com' // TODO: 配置实际 API 地址

/**
 * ${serviceName} API 服务
 */
export class ${capitalize(serviceName)}Api {
  
  /**
   * GET 请求
   */
  static async get<T>(endpoint: string, params?: Record<string, string>): Promise<T> {
    const url = params 
      ? \`\${BASE_URL}\${endpoint}?\${new URLSearchParams(params)}\`
      : \`\${BASE_URL}\${endpoint}\`
    
    Logger.info(TAG, \`GET \${url}\`)
    
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp()
      httpRequest.request(
        url,
        {
          method: http.RequestMethod.GET,
          header: {
            'Content-Type': 'application/json'
          },
          expectDataType: http.HttpDataType.JSON
        },
        (err: Error, response: http.HttpResponse) => {
          if (err) {
            Logger.error(TAG, 'Request failed', err)
            reject(err)
          } else if (response.responseCode === 200) {
            resolve(response.result as T)
          } else {
            reject(new Error(\`HTTP \${response.responseCode}\`))
          }
          httpRequest.destroy()
        }
      )
    })
  }

  /**
   * POST 请求
   */
  static async post<T>(endpoint: string, data?: any): Promise<T> {
    const url = \`\${BASE_URL}\${endpoint}\`
    Logger.info(TAG, \`POST \${url}\`)
    
    return new Promise((resolve, reject) => {
      const httpRequest = http.createHttp()
      httpRequest.request(
        url,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify(data),
          expectDataType: http.HttpDataType.JSON
        },
        (err: Error, response: http.HttpResponse) => {
          if (err) {
            Logger.error(TAG, 'Request failed', err)
            reject(err)
          } else if (response.responseCode === 200 || response.responseCode === 201) {
            resolve(response.result as T)
          } else {
            reject(new Error(\`HTTP \${response.responseCode}\`))
          }
          httpRequest.destroy()
        }
      )
    })
  }

  // TODO: 添加具体的 API 方法
}
`;

  ensureDir(path.dirname(apiPath));
  fs.writeFileSync(apiPath, convertToArkTS(content), 'utf-8');
  console.log(`✓ API 服务已创建：${apiPath}`);
}

/**
 * 创建工具类
 */
function createUtil(utilName) {
  const utilPath = path.join(SRC_DIR, 'utils', `${utilName}.ts`);
  
  const content = `/**
 * ${utilName} 工具类
 * @description TODO: 添加工具类描述
 */
export class ${capitalize(utilName)} {
  
  /**
   * TODO: 添加方法描述
   */
  static doSomething(): void {
    // TODO: 实现功能
  }
}
`;

  ensureDir(path.dirname(utilPath));
  fs.writeFileSync(utilPath, content, 'utf-8');
  console.log(`✓ 工具类已创建：${utilPath}`);
}

// 辅助函数
function capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function convertToArkTS(content) {
  // 这里可以进行一些简单的转换，将 TypeScript 转换为更符合 ArkTS 规范的代码
  return content;
}

function formatPageName(name) {
  return name.replace(/([A-Z])/g, ' $1').trim();
}

function formatComponentName(name) {
  return name.replace(/([A-Z])/g, ' $1').trim();
}

// 主逻辑
function main() {
  if (!action || !name) {
    console.log(`
ArkTS 代码生成器

用法：
  node scripts/generate.js <类型> <名称>

类型:
  page      - 创建页面组件
  component - 创建自定义组件
  model     - 创建数据模型
  api       - 创建 API 服务
  util      - 创建工具类

示例:
  node scripts/generate.js page Detail
  node scripts/generate.js component LoadingView
  node scripts/generate.js model User
  node scripts/generate.js api Word
  node scripts/generate.js util Storage
`);
    process.exit(1);
  }

  try {
    switch (action) {
      case 'page':
        createPage(name);
        break;
      case 'component':
        createComponent(name);
        break;
      case 'model':
        createModel(name);
        break;
      case 'api':
        createApi(name);
        break;
      case 'util':
        createUtil(name);
        break;
      default:
        console.error(`未知类型：${action}`);
        process.exit(1);
    }
  } catch (error) {
    console.error('生成失败:', error);
    process.exit(1);
  }
}

main();
