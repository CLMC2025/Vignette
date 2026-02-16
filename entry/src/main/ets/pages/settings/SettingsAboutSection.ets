import promptAction from '@ohos.promptAction';
import { DesignTokens } from '../../model/DesignTokens';
import { ColorsInterface } from '../../model/TokenInterfaces';
import { ThemeManager } from '../../manager/ThemeManager';

@Component
export struct SettingsAboutSection {
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  onShowPrivacy: () => void = () => {};
  onOpenOnboarding: () => void = () => {};

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private getLicenseText(): string {
    return [
      'GNU Affero General Public License v3.0',
      '',
      'Copyright (C) 2026 CLMC2025',
      '',
      'This program is free software: you can redistribute it and/or modify',
      'it under the terms of the GNU Affero General Public License as published',
      'by the Free Software Foundation, either version 3 of the License, or',
      '(at your option) any later version.',
      '',
      'This program is distributed in the hope that it will be useful,',
      'but WITHOUT ANY WARRANTY; without even the implied warranty of',
      'MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the',
      'GNU Affero General Public License for more details.',
      '',
      'You should have received a copy of the GNU Affero General Public License',
      'along with this program. If not, see <https://www.gnu.org/licenses/>.',
      '',
      '---',
      'Key Points:',
      '- Copyleft: Derivative works must be open source under AGPL v3',
      '- Network Use: Users interacting with the software over a network',
      '  are entitled to receive the source code',
      '- No Warranty: Provided "as is" without warranty of any kind'
    ].join('\n');
  }

  private getOpenSourceText(): string {
    return [
      '开源鸣谢 / Open Source Acknowledgment',
      '',
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
      'FSRS Algorithm',
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
      'Free Spaced Repetition Scheduler',
      'Author: Jarrett Ye',
      'License: MIT License',
      'https://github.com/open-spaced-repetition/fsrs4anki',
      '',
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
      'Anki',
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
      'Smart spaced repetition flashcard program',
      'Author: Ankitects',
      'License: AGPL v3',
      'https://github.com/ankitects/anki',
      '',
      '感谢开源社区的贡献！',
      'Thanks to the open source community!'
    ].join('\n');
  }

  private async openLicenseDialog(): Promise<void> {
    await promptAction.showDialog({
      title: $r('app.string.license_title'),
      message: this.getLicenseText(),
      buttons: [{ text: $r('app.string.license_close'), color: String(this.colors.TEXT_SECONDARY) }]
    });
  }

  private async openOpenSourceDialog(): Promise<void> {
    await promptAction.showDialog({
      title: '开源鸣谢',
      message: this.getOpenSourceText(),
      buttons: [{ text: '关闭', color: String(this.colors.TEXT_SECONDARY) }]
    });
  }

  @Builder
  private buildAppInfoCard() {
    Column() {
      Text($r('app.string.about_version'))
        .fontSize(DesignTokens.Typography.FONT_SIZE_XL)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors.TEXT_PRIMARY)

      Text($r('app.string.about_slogan'))
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(this.colors.TEXT_SECONDARY)
        .margin({ top: DesignTokens.Spacing.XS, bottom: DesignTokens.Spacing.LG })

      Column() {
        Row() {
          Text('新手引导')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(this.colors.PRIMARY)
            .onClick(() => this.onOpenOnboarding())

          Divider().vertical(true).height(16).color(this.colors.GRAY_300).margin({ left: 16, right: 16 })

          Text('隐私政策')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(this.colors.PRIMARY)
            .onClick(() => this.onShowPrivacy())
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        Row() {
          Text('开源许可')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(this.colors.PRIMARY)
            .onClick(() => this.openLicenseDialog())

          Divider().vertical(true).height(16).color(this.colors.GRAY_300).margin({ left: 16, right: 16 })

          Text('开源鸣谢')
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(this.colors.PRIMARY)
            .onClick(() => this.openOpenSourceDialog())
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: DesignTokens.Spacing.SM })
      }
      .width('100%')
    }
    .width('100%')
    .padding(DesignTokens.Spacing.LG)
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildContactRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
        .fontColor(this.colors.TEXT_SECONDARY)
        .width(80)

      Text(value)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(this.colors.TEXT_PRIMARY)
        .layoutWeight(1)
    }
    .width('100%')
    .height(56)
    .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
  }

  @Builder
  private buildContactCard() {
    Column() {
      Text('联系我们')
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .fontColor(this.colors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: DesignTokens.Spacing.MD })

      this.buildContactRow('项目地址', 'github.com/CLMC2025/Vignette')

      Divider().color(this.colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

      this.buildContactRow('反馈邮箱', 'c_k1@foxmail.com')

      Divider().color(this.colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

      this.buildContactRow('QQ群', '1077476965')
    }
    .width('100%')
    .padding({ top: DesignTokens.Spacing.LG, bottom: DesignTokens.Spacing.LG })
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
    .margin({ top: DesignTokens.Spacing.MD })
  }

  build() {
    Column() {
      Text('关于')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: DesignTokens.Spacing.MD })

      this.buildAppInfoCard()
      this.buildContactCard()
    }
    .width('100%')
  }
}
