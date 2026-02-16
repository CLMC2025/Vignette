// =====================================================
// APIConfigSection.ets
// API Provider, Base URL, Key, Model selection
// =====================================================

import { DesignTokens } from '../../model/DesignTokens';
import { ColorsInterface } from '../../model/TokenInterfaces';
import { ThemeManager } from '../../manager/ThemeManager';
import { SelectOption, formatError } from './SettingsCommon';
import { DictionaryManager } from '../../manager/DictionaryManager';

export class APIProvider {
  name: string;
  baseUrl: string;
  models: string[];

  constructor(name: string, baseUrl: string, models: string[]) {
    this.name = name;
    this.baseUrl = baseUrl;
    this.models = models;
  }
}

export const API_PROVIDERS: APIProvider[] = [
  new APIProvider('深度求索', 'https://api.deepseek.com', ['deepseek-chat', 'deepseek-coder', 'deepseek-reasoner']),
  new APIProvider('硅基流动', 'https://api.siliconflow.cn', ['deepseek-ai/DeepSeek-V3', 'deepseek-ai/DeepSeek-R1', 'Qwen/Qwen2.5-72B-Instruct']),
  new APIProvider('火山引擎', 'https://ark.cn-beijing.volces.com/api/v3', ['doubao-pro-32k', 'doubao-lite-32k', 'deepseek-r1-250120']),
  new APIProvider('阿里云百炼', 'https://dashscope.aliyuncs.com/compatible-mode/v1', ['qwen-turbo', 'qwen-plus', 'qwen-max']),
  new APIProvider('百度千帆', 'https://qianfan.baidubce.com/v2', ['ernie-speed-128k', 'ernie-lite-8k', 'deepseek-v3']),
  new APIProvider('智谱AI', 'https://open.bigmodel.cn/api/paas/v4', ['glm-4-flash', 'glm-4-air', 'glm-4-plus']),
  new APIProvider('讯飞星火', 'https://spark-api-open.xf-yun.com/v1', ['lite', 'pro', 'max']),
  new APIProvider('腾讯混元', 'https://hunyuan.tencentcloudapi.com/v1', ['hunyuan-lite', 'hunyuan-standard', 'hunyuan-pro']),
  new APIProvider('自定义', '', [])
];

@Component
export struct APIConfigSection {
  @Link selectedProviderIndex: number;
  @Link apiBaseUrl: string;
  @Link apiKey: string;
  @Link selectedModel: string;
  @Link showApiKey: boolean;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  @State isTesting: boolean = false;
  @State testResult: string = '';
  @State testSuccess: boolean = false;

  onSave: () => void = () => {};

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private async testConnection(): Promise<void> {
    if (this.apiKey.length === 0) {
      this.testResult = '❌ 请先输入API密钥';
      this.testSuccess = false;
      return;
    }

    this.isTesting = true;
    this.testResult = '正在测试连接...';

    try {
      const dictManager = DictionaryManager.getInstance();
      dictManager.configure(this.apiBaseUrl, this.apiKey, this.selectedModel);
      const result = await dictManager.lookup('test', '');

      if (result.success) {
        this.testResult = '✅ 连接成功！';
        this.testSuccess = true;
        this.onSave();
      } else {
        this.testResult = this.formatErrorMessage(result.error);
        this.testSuccess = false;
      }
    } catch (e) {
      this.testResult = this.formatErrorMessage(formatError(e));
      this.testSuccess = false;
    } finally {
      this.isTesting = false;
    }
  }

  private formatErrorMessage(errorMsg: string): string {
    let suggestion = '';
    if (errorMsg.includes('401') || errorMsg.includes('Unauthorized')) {
      suggestion = ' 请检查API密钥是否正确';
    } else if (errorMsg.includes('404') || errorMsg.includes('Not Found')) {
      suggestion = ' 请检查API地址是否正确';
    } else if (errorMsg.includes('timeout') || errorMsg.includes('Timeout')) {
      suggestion = ' 连接超时，请检查网络连接或稍后重试';
    } else if (errorMsg.includes('network') || errorMsg.includes('Network')) {
      suggestion = ' 网络错误，请检查网络连接';
    }
    return `❌ ${errorMsg}${suggestion}`;
  }

  private onProviderChange(index: number): void {
    this.selectedProviderIndex = index;
    const provider = API_PROVIDERS[index];

    if (provider.name !== '自定义') {
      this.apiBaseUrl = provider.baseUrl;
      if (provider.models.length > 0 && !provider.models.includes(this.selectedModel)) {
        this.selectedModel = provider.models[0];
      }
    }
    this.testResult = '';
  }

  private getProviderOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (const provider of API_PROVIDERS) {
      options.push({ value: provider.name });
    }
    return options;
  }

  @Builder
  private buildProviderCard() {
    Column() {
      Text('提供商配置')
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(this.colors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: DesignTokens.Spacing.MD })

      Row() {
        Text('提供商')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(this.colors.GRAY_700)

        Blank()

        Select(this.getProviderOptions())
          .selected(this.selectedProviderIndex)
          .value(API_PROVIDERS[this.selectedProviderIndex].name)
          .font({ size: DesignTokens.Typography.FONT_SIZE_BASE })
          .fontColor(this.colors.GRAY_700)
          .onSelect((index: number) => this.onProviderChange(index))
      }
      .width('100%')
      .height(56)
      .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

      if (this.selectedProviderIndex === API_PROVIDERS.length - 1) {
        Divider().color(this.colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

        Row() {
          Text('基础URL')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(this.colors.GRAY_700)

          Blank()

          TextInput({ text: this.apiBaseUrl, placeholder: 'https://api.example.com' })
            .width(200)
            .height(40)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .textAlign(TextAlign.End)
            .backgroundColor(this.colors.GRAY_100)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .padding({ left: DesignTokens.Spacing.SM, right: DesignTokens.Spacing.SM })
            .onChange((value: string) => this.apiBaseUrl = value)
        }
        .width('100%')
        .height(56)
        .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
      } else {
        Row() {
          Text('基础URL')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(this.colors.GRAY_700)

          Blank()

          Text(this.apiBaseUrl)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(this.colors.GRAY_500)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height(44)
        .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
      }
    }
    .width('100%')
    .padding({ top: DesignTokens.Spacing.LG, bottom: DesignTokens.Spacing.LG })
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
  }

  @Builder
  private buildKeyAndModelCard() {
    Column() {
      Text('密钥与模型')
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(this.colors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: DesignTokens.Spacing.MD })

      Row() {
        Text('API密钥')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(this.colors.GRAY_700)

        Blank()

        Row() {
          TextInput({ text: this.apiKey, placeholder: '输入您的API密钥' })
            .width(180)
            .height(40)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .type(this.showApiKey ? InputType.Normal : InputType.Password)
            .textAlign(TextAlign.End)
            .backgroundColor(this.colors.GRAY_100)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .padding({ left: DesignTokens.Spacing.SM, right: DesignTokens.Spacing.SM })
            .onChange((value: string) => {
              this.apiKey = value;
              this.testResult = '';
            })

          Button(this.showApiKey ? '隐藏' : '显示')
            .margin({ left: DesignTokens.Spacing.SM })
            .height(36)
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(this.colors.GRAY_700)
            .backgroundColor(this.colors.GRAY_200)
            .borderRadius(DesignTokens.BorderRadius.MD)
            .onClick(() => this.showApiKey = !this.showApiKey)
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

      Divider().color(this.colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

      Row() {
        Text('模型')
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(this.colors.GRAY_700)

        Blank()

        TextInput({ text: this.selectedModel, placeholder: '模型名称' })
          .width(180)
          .height(40)
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .textAlign(TextAlign.End)
          .backgroundColor(this.colors.GRAY_100)
          .borderRadius(DesignTokens.BorderRadius.MD)
          .padding({ left: DesignTokens.Spacing.SM, right: DesignTokens.Spacing.SM })
          .onChange((value: string) => this.selectedModel = value)
      }
      .width('100%')
      .height(56)
      .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

      this.buildModelSuggestions()
    }
    .width('100%')
    .padding({ top: DesignTokens.Spacing.LG, bottom: DesignTokens.Spacing.LG })
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .margin({ top: DesignTokens.Spacing.MD })
  }

  @Builder
  private buildModelSuggestions() {
    Row() {
      Text('推荐模型:')
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(this.colors.TEXT_TERTIARY)

      Scroll() {
        Row() {
          ForEach(API_PROVIDERS[this.selectedProviderIndex].models, (model: string) => {
            Text(model)
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(this.colors.PRIMARY)
              .backgroundColor(this.colors.PRIMARY_LIGHTEST)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .borderRadius(DesignTokens.BorderRadius.FULL)
              .margin({ right: 8 })
              .onClick(() => this.selectedModel = model)
          }, (model: string) => model)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG, top: DesignTokens.Spacing.SM })
  }

  @Builder
  private buildTestCard() {
    Column() {
      Text('连接测试')
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(this.colors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: DesignTokens.Spacing.MD })

      Button(this.isTesting ? '测试中...' : '测试连接')
        .width('100%')
        .height(48)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(this.colors.WHITE)
        .backgroundColor(this.isTesting ? this.colors.GRAY_400 : this.colors.SUCCESS)
        .borderRadius(DesignTokens.BorderRadius.MD)
        .enabled(!this.isTesting)
        .onClick(() => this.testConnection())

      if (this.testResult.length > 0) {
        Text(this.testResult)
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(this.testSuccess ? this.colors.SUCCESS : this.colors.ERROR)
          .margin({ top: DesignTokens.Spacing.SM })
          .textAlign(TextAlign.Center)
          .width('100%')
      }
    }
    .width('100%')
    .padding({ top: DesignTokens.Spacing.LG, bottom: DesignTokens.Spacing.LG })
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .margin({ top: DesignTokens.Spacing.MD })
  }

  build() {
    Column() {
      Text('API配置')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: DesignTokens.Spacing.MD })

      this.buildProviderCard()
      this.buildKeyAndModelCard()
      this.buildTestCard()
    }
    .width('100%')
    .padding(DesignTokens.Spacing.MD)
  }
}
