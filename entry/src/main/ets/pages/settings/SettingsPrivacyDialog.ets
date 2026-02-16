import type common from '@ohos.app.ability.common';
import { DesignTokens } from '../../model/DesignTokens';
import { ColorsInterface } from '../../model/TokenInterfaces';
import { ThemeManager } from '../../manager/ThemeManager';
import resourceManager from '@ohos.resourceManager';
import { Base64Util } from '../../sync/webdav/Base64Util';

@Component
export struct SettingsPrivacyDialog {
  @Link visible: boolean;
  @State privacyLines: string[] = [];
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private resourceMgr: resourceManager.ResourceManager | null = null;
  private privacyLoaded: boolean = false;
  private readonly PRIVACY_HEADINGS: string[] = [
    '引言', '信息收集', '我们收集的信息', '我们不收集的信息', '数据使用',
    '数据安全', '用户权利', '第三方 AI 服务', '第三方服务', '儿童隐私',
    '政策更新', '联系我们', '同意声明'
  ];

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  aboutToAppear(): void {
    void this.loadPrivacyPolicy();
  }

  private getPrivacyPolicyLines(): string[] {
    if (this.privacyLines.length > 0) {
      return this.privacyLines;
    }
    return this.getPrivacyPolicyFallback();
  }

  private getPrivacyPolicyFallback(): string[] {
    return [
      '最后更新日期：2026年2月',
      '引言',
      '微语单词（以下简称“本应用”）尊重并保护所有用户的隐私权。本隐私政策旨在向您说明我们如何收集、使用和保护您的个人信息。请您在使用本应用前仔细阅读本政策。',
      '信息收集',
      '我们收集的信息',
      '1. 学习数据：单词学习进度、复习记录、学习统计数据，所有数据仅存储在您的设备本地。',
      '2. 用户设置：API 配置（Base URL、模型名称）、学习偏好设置、词书选择，API Key 使用系统安全存储加密保存。',
      '我们不收集的信息',
      '不收集个人身份信息（姓名、电话、邮箱等）、设备标识符、位置信息、用户行为分析数据、崩溃日志（除非您主动反馈）。',
      '数据使用',
      '本地存储：所有学习数据存储在您的设备本地数据库中，我们不会上传到任何服务器。',
      'AI 服务：使用 AI 语境生成功能时，单词信息会发送到您配置的服务商，数据传输遵循各服务商隐私政策，我们不会在中间服务器存储任何请求数据。',
      'WebDAV 同步：使用您自有的 WebDAV 存储空间，数据加密后传输和存储，我们无权访问您的 WebDAV 内容。',
      '数据安全',
      'API Key 使用 HarmonyOS 系统安全存储；WebDAV 同步支持 AES 加密；本地数据存储于应用私有目录并由系统权限保护。',
      '用户权利',
      '可随时导出学习数据为 JSON；卸载应用即可完全删除所有数据；完全控制是否启用 WebDAV 同步；随时更换或删除 API Key。',
      '第三方 AI 服务',
      '单词信息将发送到您配置的 AI 服务商，数据传输遵循该服务商隐私政策。',
      '儿童隐私',
      '本应用不面向 13 岁以下儿童。',
      '政策更新',
      '我们可能会不时更新本隐私政策，更新后的政策将在本页面公布，重大变更会另行通知。',
      '联系我们',
      '项目地址：https://github.com/CLMC2025/Vignette',
      '邮箱：c_k1@foxmail.com',
      'QQ反馈群：1077476965',
      '同意声明',
      '使用本应用即表示您同意本隐私政策的所有条款。如果您不同意，请停止使用本应用。'
    ];
  }

  private async loadPrivacyPolicy(): Promise<void> {
    if (this.privacyLoaded) {
      return;
    }
    try {
      if (this.resourceMgr === null) {
        const context = getContext(this) as common.UIAbilityContext;
        this.resourceMgr = context.resourceManager;
      }
      if (this.resourceMgr === null) {
        return;
      }
      const data = await this.resourceMgr.getRawFileContent('privacy.md');
      const content = this.uint8ArrayToString(data);
      const lines = this.parsePrivacyMarkdown(content);
      if (lines.length > 0) {
        this.privacyLines = lines;
      }
      this.privacyLoaded = true;
    } catch (e) {
      this.privacyLoaded = true;
    }
  }

  private parsePrivacyMarkdown(content: string): string[] {
    const lines: string[] = [];
    const raw = content.split(/\r?\n/);
    for (let i = 0; i < raw.length; i += 1) {
      const rawLine = raw[i];
      const trimmed = rawLine.trim();
      if (trimmed.length === 0) {
        continue;
      }
      if (trimmed === '---') {
        continue;
      }
      lines.push(rawLine);
    }
    return lines;
  }

  private uint8ArrayToString(data: Uint8Array): string {
    return Base64Util.utf8Decode(data);
  }

  private isPrivacyHeading(text: string): boolean {
    const trimmed = text.trim();
    if (trimmed.startsWith('## ') || trimmed.startsWith('### ') || trimmed.startsWith('# ')) {
      return true;
    }
    if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
      return true;
    }
    return this.PRIVACY_HEADINGS.indexOf(this.normalizePrivacyLine(trimmed)) >= 0;
  }

  private normalizePrivacyLine(text: string): string {
    const trimmed = text.trim();
    if (trimmed.startsWith('### ')) {
      return trimmed.slice(4).replace(/\*\*/g, '');
    }
    if (trimmed.startsWith('## ')) {
      return trimmed.slice(3).replace(/\*\*/g, '');
    }
    if (trimmed.startsWith('# ')) {
      return trimmed.slice(2).replace(/\*\*/g, '');
    }
    if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
      return trimmed.slice(2, trimmed.length - 2);
    }
    return trimmed.replace(/\*\*/g, '');
  }

  private buildPrivacyDisplayLine(text: string): string {
    const unordered = /^(\s*)[-*]\s+(.+)$/.exec(text);
    if (unordered !== null) {
      const level = Math.min(2, Math.floor(unordered[1].length / 2));
      const marker = level === 0 ? '• ' : level === 1 ? '◦ ' : '▪ ';
      return `${marker}${this.normalizePrivacyLine(unordered[2])}`;
    }
    const ordered = /^(\s*)(\d+)\.\s+(.+)$/.exec(text);
    if (ordered !== null) {
      return `${ordered[2]}. ${this.normalizePrivacyLine(ordered[3])}`;
    }
    return this.normalizePrivacyLine(text);
  }

  build() {
    if (this.visible) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.colors.BLACK)
          .opacity(0.5)
          .onClick(() => {
            this.visible = false;
          })

        Column() {
          Column() {
            Text('隐私政策')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.colors.TEXT_PRIMARY)
              .margin({ bottom: 8 })

            Scroll() {
              Column() {
                ForEach(this.getPrivacyPolicyLines(), (line: string) => {
                  if (this.isPrivacyHeading(line)) {
                    Text(this.normalizePrivacyLine(line))
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.colors.TEXT_PRIMARY)
                      .textAlign(TextAlign.Start)
                      .width('100%')
                      .margin({ top: 10, bottom: 4 })
                  } else {
                    Text(this.buildPrivacyDisplayLine(line))
                      .fontSize(12)
                      .fontColor(this.colors.TEXT_SECONDARY)
                      .textAlign(TextAlign.Start)
                      .width('100%')
                      .margin({ top: 4 })
                  }
                }, (line: string, index?: number) => `${index ?? 0}_${line}`)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            .height(320)
            .scrollBar(BarState.On)
            .margin({ bottom: 16 })

            Button('关闭')
              .width('100%')
              .height(44)
              .fontSize(16)
              .fontColor(this.colors.WHITE)
              .backgroundColor(this.colors.GRAY_700)
              .borderRadius(22)
              .onClick(() => {
                this.visible = false;
              })
          }
          .width('90%')
          .padding(24)
          .backgroundColor(this.colors.SURFACE_PRIMARY)
          .borderRadius(16)
          .shadow({
            color: this.colors.SHADOW_LIGHT,
            radius: 8,
            offsetX: 0,
            offsetY: 4
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .zIndex(999)
    }
  }
}
