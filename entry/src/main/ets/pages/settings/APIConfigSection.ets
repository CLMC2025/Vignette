// =====================================================
// APIConfigSection.ets
// API Provider, Base URL, Key, Model selection
// =====================================================

import { DesignTokens } from '../../model/DesignTokens';
import { SelectOption, formatError } from './SettingsCommon';
import { DictionaryManager } from '../../manager/DictionaryManager';

/**
 * Preset API providers
 */
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

/**
 * Available API providers - 国内主流AI厂商
 * 自定义选项可用于国外API或其他兼容OpenAI格式的服务
 */
export const API_PROVIDERS: APIProvider[] = [
  // 深度求索
  new APIProvider('深度求索', 'https://api.deepseek.com', ['deepseek-chat', 'deepseek-coder', 'deepseek-reasoner']),
  // 硅基流动
  new APIProvider('硅基流动', 'https://api.siliconflow.cn', ['deepseek-ai/DeepSeek-V3', 'deepseek-ai/DeepSeek-R1', 'Qwen/Qwen2.5-72B-Instruct']),
  // 火山引擎(字节跳动)
  new APIProvider('火山引擎', 'https://ark.cn-beijing.volces.com/api/v3', ['doubao-pro-32k', 'doubao-lite-32k', 'deepseek-r1-250120']),
  // 阿里云百炼
  new APIProvider('阿里云百炼', 'https://dashscope.aliyuncs.com/compatible-mode/v1', ['qwen-turbo', 'qwen-plus', 'qwen-max']),
  // 百度千帆
  new APIProvider('百度千帆', 'https://qianfan.baidubce.com/v2', ['ernie-speed-128k', 'ernie-lite-8k', 'deepseek-v3']),
  // 智谱AI
  new APIProvider('智谱AI', 'https://open.bigmodel.cn/api/paas/v4', ['glm-4-flash', 'glm-4-air', 'glm-4-plus']),
  // 讯飞星火
  new APIProvider('讯飞星火', 'https://spark-api-open.xf-yun.com/v1', ['lite', 'pro', 'max']),
  // 腾讯混元
  new APIProvider('腾讯混元', 'https://hunyuan.tencentcloudapi.com/v1', ['hunyuan-lite', 'hunyuan-standard', 'hunyuan-pro']),
  // 自定义(可用于国外API如OpenAI、Claude等)
  new APIProvider('自定义', '', [])
];

@Component
export struct APIConfigSection {
  @Link selectedProviderIndex: number;
  @Link apiBaseUrl: string;
  @Link apiKey: string;
  @Link selectedModel: string;
  @Link showApiKey: boolean;
  
  // Test state local to this component? 
  // Parent might need to know if test passed to allow save? 
  // But SettingsPage logic was: test, then if success, save.
  // We can keep test logic here and maybe expose a callback or just update local state.
  @State isTesting: boolean = false;
  @State testResult: string = '';
  @State testSuccess: boolean = false;

  // Callback to trigger save from parent
  onSave: () => void = () => {};

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
      // We assume context preferences are set elsewhere or defaults used for test
      // dictManager.setContextPreferences(...) 
      
      const result = await dictManager.lookup('test', '');

      if (result.success) {
        this.testResult = '✅ 连接成功！';
        this.testSuccess = true;
        this.onSave(); // Auto save on success
      } else {
        let errorMsg = result.error;
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

        this.testResult = `❌ ${errorMsg}${suggestion}`;
        this.testSuccess = false;
      }
    } catch (e) {
      const errMsg = formatError(e);
      let suggestion = '';

      if (errMsg.includes('network') || errMsg.includes('Network')) {
        suggestion = ' 网络错误，请检查网络连接';
      } else if (errMsg.includes('invalid') || errMsg.includes('Invalid')) {
        suggestion = ' 请检查API配置是否正确';
      }

      this.testResult = `❌ 连接失败: ${errMsg}${suggestion}`;
      this.testSuccess = false;
    } finally {
      this.isTesting = false;
    }
  }

  private onProviderChange(index: number): void {
    this.selectedProviderIndex = index;
    const provider = API_PROVIDERS[index];

    if (provider.name !== 'Custom') {
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
  private showModelSuggestions() {
    Row() {
      Text('推荐: ')
        .fontSize(12)
        .fontColor('#999999')

      if (API_PROVIDERS[this.selectedProviderIndex].models[0]) {
        Text(API_PROVIDERS[this.selectedProviderIndex].models[0])
          .fontSize(12)
          .fontColor('#2196F3')
          .margin({ left: 8 })
          .onClick(() => {
            this.selectedModel = API_PROVIDERS[this.selectedProviderIndex].models[0];
          })
      }

      if (API_PROVIDERS[this.selectedProviderIndex].models[1]) {
        Text(API_PROVIDERS[this.selectedProviderIndex].models[1])
          .fontSize(12)
          .fontColor('#2196F3')
          .margin({ left: 8 })
          .onClick(() => {
            this.selectedModel = API_PROVIDERS[this.selectedProviderIndex].models[1];
          })
      }

      if (API_PROVIDERS[this.selectedProviderIndex].models[2]) {
        Text(API_PROVIDERS[this.selectedProviderIndex].models[2])
          .fontSize(12)
          .fontColor('#2196F3')
          .margin({ left: 8 })
          .onClick(() => {
            this.selectedModel = API_PROVIDERS[this.selectedProviderIndex].models[2];
          })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
    .margin({ top: 4 })
  }

  build() {
    Column() {
      Text('API配置')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')
        .margin({ top: DesignTokens.Spacing.XXL, bottom: DesignTokens.Spacing.MD })

      Column() {
        // Provider Selection
        Column() {
          Row() {
            Text('提供商')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(DesignTokens.Colors.GRAY_700)

            Blank()

            Select(this.getProviderOptions())
              .selected(this.selectedProviderIndex)
              .value(API_PROVIDERS[this.selectedProviderIndex].name)
              .font({ size: DesignTokens.Typography.FONT_SIZE_BASE })
              .fontColor(DesignTokens.Colors.GRAY_700)
              .selectedOptionFont({ size: DesignTokens.Typography.FONT_SIZE_BASE })
              .optionFont({ size: DesignTokens.Typography.FONT_SIZE_BASE })
              .onSelect((index: number) => {
                this.onProviderChange(index);
              })
          }
          .width('100%')
          .height(56)
          .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
          .alignItems(VerticalAlign.Center)

          Divider().color(DesignTokens.Colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG })
        }

        // Base URL
        Column() {
          Row() {
            Text('基础URL')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(DesignTokens.Colors.GRAY_700)

            Blank()

            if (this.selectedProviderIndex === API_PROVIDERS.length - 1) {
              TextInput({ text: this.apiBaseUrl, placeholder: 'https://api.example.com' })
                .width(200)
                .height(40)
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .textAlign(TextAlign.End)
                .backgroundColor(DesignTokens.Colors.GRAY_100)
                .borderRadius(DesignTokens.BorderRadius.MD)
                .padding({ left: DesignTokens.Spacing.SM, right: DesignTokens.Spacing.SM })
                .onChange((value: string) => {
                  this.apiBaseUrl = value;
                })
            } else {
              Text(this.apiBaseUrl)
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .fontColor(DesignTokens.Colors.GRAY_600)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .constraintSize({ maxWidth: 200 })
            }
          }
          .width('100%')
          .height(56)
          .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
          .alignItems(VerticalAlign.Center)

          Divider().color(DesignTokens.Colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG })
        }

        // API Key
        Column() {
          Row() {
            Text('API密钥')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(DesignTokens.Colors.GRAY_700)

            Blank()

            Row() {
              TextInput({ text: this.apiKey, placeholder: '输入您的API密钥' })
                .width(180)
                .height(40)
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .type(this.showApiKey ? InputType.Normal : InputType.Password)
                .textAlign(TextAlign.End)
                .backgroundColor(DesignTokens.Colors.GRAY_100)
                .borderRadius(DesignTokens.BorderRadius.MD)
                .padding({ left: DesignTokens.Spacing.SM, right: DesignTokens.Spacing.SM })
                .onChange((value: string) => {
                  this.apiKey = value;
                  this.testResult = '';
                })

              Text(this.showApiKey ? '👁' : '👁‍🗨')
                .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
                .margin({ left: DesignTokens.Spacing.SM })
                .onClick(() => {
                  this.showApiKey = !this.showApiKey;
                })
            }
          }
          .width('100%')
          .height(56)
          .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
          .alignItems(VerticalAlign.Center)

          Divider().color(DesignTokens.Colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG })
        }

        // Model Selection
        Column() {
          Row() {
            Text('模型')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(DesignTokens.Colors.GRAY_700)

            Blank()

            Column() {
              TextInput({ text: this.selectedModel, placeholder: '模型名称' })
                .width(180)
                .height(40)
                .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
                .textAlign(TextAlign.End)
                .backgroundColor(DesignTokens.Colors.GRAY_100)
                .borderRadius(DesignTokens.BorderRadius.MD)
                .padding({ left: DesignTokens.Spacing.SM, right: DesignTokens.Spacing.SM })
                .onChange((value: string) => {
                  this.selectedModel = value;
                })

              this.showModelSuggestions()
            }
          }
          .width('100%')
          .height(56)
          .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
          .alignItems(VerticalAlign.Center)

          Divider().color(DesignTokens.Colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG })
        }

        // Test Connection Button
        Column() {
          Button(this.isTesting ? '测试中...' : '测试连接')
            .width('100%')
            .height(48)
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.WHITE)
            .backgroundColor(this.isTesting ? DesignTokens.Colors.GRAY_400 : DesignTokens.Colors.SUCCESS)
            .borderRadius(DesignTokens.BorderRadius.LG)
            .enabled(!this.isTesting)
            .margin({ top: DesignTokens.Spacing.SM })
            .onClick(() => {
              this.testConnection();
            })

          if (this.testResult.length > 0) {
            Text(this.testResult)
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(this.testSuccess ? DesignTokens.Colors.SUCCESS : DesignTokens.Colors.ERROR)
              .margin({ top: DesignTokens.Spacing.SM })
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG, bottom: DesignTokens.Spacing.LG })
      }
      .width('100%')
      .backgroundColor(DesignTokens.Colors.WHITE)
      .borderRadius(DesignTokens.BorderRadius.LG)
      .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
    }
    .width('100%')
  }
}
