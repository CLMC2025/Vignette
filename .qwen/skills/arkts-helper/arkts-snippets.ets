// ============================================
// ArkTS 常用代码片段模板
// ============================================

// 1. 基础组件模板
// --------------------------------------------

// 基础页面结构
@Component
struct PageName {
  @State message: string = 'Hello World'

  build() {
    Column() {
      Text(this.message)
        .fontSize(50)
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

// 2. 状态管理模板
// --------------------------------------------

// @State - 组件内状态
@Component
struct Counter {
  @State count: number = 0

  build() {
    Column() {
      Text(`Count: ${this.count}`)
      Button('Increment')
        .onClick(() => {
          this.count++
        })
    }
  }
}

// @Link - 父子组件双向绑定
@Component
struct ChildComponent {
  @Link value: number

  build() {
    Button(`Child: ${this.value}`)
      .onClick(() => {
        this.value++
      })
  }
}

@Component
struct ParentComponent {
  @State childValue: number = 0

  build() {
    Column() {
      Text(`Parent: ${this.childValue}`)
      ChildComponent({ value: this.childValue })
    }
  }
}

// @Prop - 父子组件单向同步
@Component
struct PropChild {
  @Prop title: string = ''

  build() {
    Text(this.title)
  }
}

// @Watch - 状态变化监听
@Component
struct WatchExample {
  @State @Watch('onCountChanged') count: number = 0

  onCountChanged(): void {
    console.info(`Count changed to: ${this.count}`)
  }

  build() {
    Button('Click')
      .onClick(() => {
        this.count++
      })
  }
}

// @Observed + @ObjectLink - 对象属性观察
@Observed
class Person {
  name: string
  age: number

  constructor(name: string, age: number) {
    this.name = name
    this.age = age
  }
}

@Component
struct ObservedExample {
  @State @Observed person: Person = new Person('Alice', 25)

  build() {
    Column() {
      Text(`${this.person.name} - ${this.person.age}`)
      Button('Birthday')
        .onClick(() => {
          this.person.age++
        })
    }
  }
}

// 3. 列表组件模板
// --------------------------------------------

// List 基础用法
@Component
struct ListExample {
  @State items: string[] = ['Item 1', 'Item 2', 'Item 3']

  build() {
    List() {
      ForEach(this.items, (item: string, index: number) => {
        ListItem() {
          Text(item)
            .padding(10)
            .width('100%')
        }
      }, (item: string, index: number) => `${item}_${index}`)
    }
    .width('100%')
  }
}

// Grid 网格布局
@Component
struct GridExample {
  @State items: number[] = [1, 2, 3, 4, 5, 6]

  build() {
    Grid() {
      ForEach(this.items, (item: number) => {
        GridItem() {
          Text(`Item ${item}`)
            .fontSize(20)
        }
        .width(100)
        .height(100)
        .backgroundColor('#007DFF')
        .margin(5)
      })
    }
    .columnsTemplate(this.gridColumns())
    .rowsGap(10)
    .columnsGap(10)
    .padding(10)
  }

  @Builder gridColumns() {
    GridRowSize(1fr, 1fr, 1fr)
  }
}

// 4. 动画模板
// --------------------------------------------

// 属性动画
@Component
struct AnimationExample {
  @State scale: number = 1
  @State rotate: number = 0

  build() {
    Button('Animate')
      .scale({ x: this.scale, y: this.scale })
      .rotate({ angle: this.rotate })
      .animation({
        duration: 1000,
        curve: Curve.EaseInOut,
        iterations: 1,
        fillMode: AnimationFillMode.Forwards
      })
      .onClick(() => {
        this.scale = 1.2
        this.rotate = 360
      })
  }
}

// 显式动画
@Component
struct ExplicitAnimation {
  @State offset: number = 0

  build() {
    Button('Move')
      .offset({ x: this.offset })
      .onClick(() => {
        animateTo({
          duration: 1000,
          curve: Curve.EaseOut
        }, () => {
          this.offset = 100
        })
      })
  }
}

// 5. 手势处理模板
// --------------------------------------------

@Component
struct GestureExample {
  @State scale: number = 1
  @State offset: Offset = { dx: 0, dy: 0 }

  build() {
    Button('Drag & Zoom')
      .scale({ x: this.scale, y: this.scale })
      .offset(this.offset)
      .gesture(
        GestureGroup(GestureMode.Exclusive, [
          PinchGesture()
            .onAction((event: PinchEvent) => {
              this.scale = event.scale
            }),
          PanGesture()
            .onAction((event: PanEvent) => {
              this.offset = { dx: event.offsetX, dy: event.offsetY }
            })
        ])
      )
  }
}

// 6. 网络请求模板
// --------------------------------------------

// HTTP 请求封装
import http from '@ohos.net.http'

async function httpGet(url: string): Promise<any> {
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
          reject(err)
        } else {
          resolve(response.result)
        }
        httpRequest.destroy()
      }
    )
  })
}

async function httpPost(url: string, data: any): Promise<any> {
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
          reject(err)
        } else {
          resolve(response.result)
        }
        httpRequest.destroy()
      }
    )
  })
}

// 7. 数据持久化模板
// --------------------------------------------

// Preferences 首选项存储
import dataPreferences from '@ohos.data.preferences'

class PreferencesHelper {
  private preferences: dataPreferences.Preferences | null = null
  private readonly fileName: string = 'app_data'

  async init(context: Context): Promise<void> {
    this.preferences = await dataPreferences.getPreferences(context, this.fileName)
  }

  async set(key: string, value: string | number | boolean): Promise<void> {
    if (!this.preferences) return
    await this.preferences.put(key, value)
    await this.preferences.flush()
  }

  async get<T>(key: string, defaultValue: T): Promise<T> {
    if (!this.preferences) return defaultValue
    return await this.preferences.get(key, defaultValue) as T
  }

  async remove(key: string): Promise<void> {
    if (!this.preferences) return
    await this.preferences.delete(key)
    await this.preferences.flush()
  }
}

// 8. 路由导航模板
// --------------------------------------------

// 页面路由
import router from '@ohos.router'

// 跳转到新页面
function navigateTo(url: string, params?: Object) {
  router.pushUrl({
    url: url,
    params: params
  })
}

// 返回上一页
function navigateBack(result?: any) {
  router.back({
    result: result
  })
}

// 替换当前页面
function replaceUrl(url: string, params?: Object) {
  router.replaceUrl({
    url: url,
    params: params
  })
}

// 9. 自定义组件模板
// --------------------------------------------

// 可复用组件
interface CustomButtonOptions {
  text: string
  onClick?: () => void
  backgroundColor?: string
  fontSize?: number
}

@Component
export struct CustomButton {
  @Prop text: string = 'Button'
  @Prop backgroundColor: string = '#007DFF'
  @Prop fontSize: number = 16
  onClick?: () => void = () => {}

  build() {
    Button(this.text)
      .backgroundColor(this.backgroundColor)
      .fontSize(this.fontSize)
      .borderRadius(8)
      .padding({ left: 20, right: 20, top: 10, bottom: 10 })
      .onClick(this.onClick)
  }
}

// 10. 加载状态组件
// --------------------------------------------

@Component
struct LoadingView {
  @Prop isLoading: boolean = false
  @Prop message: string = '加载中...'

  @Builder loadingBuilder() {
    Column() {
      LoadingProgress()
        .width(40)
        .height(40)
      Text(this.message)
        .fontSize(14)
        .margin({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    if (this.isLoading) {
      this.loadingBuilder()
    }
  }
}

// 11. 空状态组件
// --------------------------------------------

@Component
struct EmptyView {
  @Prop message: string = '暂无数据'
  @Prop icon: Resource = $r('app.media.empty')
  onRetry?: () => void = () => {}

  @Builder emptyBuilder() {
    Column() {
      Image(this.icon)
        .width(100)
        .height(100)
      Text(this.message)
        .fontSize(16)
        .fontColor('#666666')
        .margin({ top: 16 })
      Button('重试')
        .margin({ top: 20 })
        .onClick(this.onRetry)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    this.emptyBuilder()
  }
}

// 12. 搜索框组件
// --------------------------------------------

@Component
struct SearchBarComponent {
  @Link searchText: string
  onSearch?: (text: string) => void
  onCancel?: () => void

  build() {
    Row() {
      TextInput({ placeholder: '搜索...', text: this.searchText })
        .flexGrow(1)
        .onChange((value: string) => {
          this.searchText = value
        })
      Button('搜索')
        .onClick(() => {
          this.onSearch?.(this.searchText)
        })
    }
    .padding(10)
    .backgroundColor('#F5F5F5')
    .borderRadius(8)
  }
}
