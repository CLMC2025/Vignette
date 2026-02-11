import promptAction from '@ohos.promptAction';
import { DesignTokens } from '../../model/DesignTokens';
import { LogStats } from '../../utils/Logger';
import { LoggerSection } from './LoggerSection';

@Component
export struct SettingsAboutSection {
  @Link logStats: LogStats;
  onShowPrivacy: () => void = () => {};

  private getLicenseText(): string {
    return [
      'MIT License',
      '',
      'Copyright (c) 2026 CLMC2025',
      '',
      'Permission is hereby granted, free of charge, to any person obtaining a copy',
      'of this software and associated documentation files (the \"Software\"), to deal',
      'in the Software without restriction, including without limitation the rights',
      'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell',
      'copies of the Software, and to permit persons to whom the Software is',
      'furnished to do so, subject to the following conditions:',
      '',
      'The above copyright notice and this permission notice shall be included in all',
      'copies or substantial portions of the Software.',
      '',
      'THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR',
      'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,',
      'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE',
      'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER',
      'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,',
      'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE',
      'SOFTWARE.'
    ].join('\n');
  }

  private async openLicenseDialog(): Promise<void> {
    await promptAction.showDialog({
      title: $r('app.string.license_title'),
      message: this.getLicenseText(),
      buttons: [{ text: $r('app.string.license_close'), color: '#666666' }]
    });
  }

  build() {
    Column() {
      // Logger Section
      LoggerSection({ logStats: $logStats })

      // About Info
      Text($r('app.string.about_title'))
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontColor(DesignTokens.Colors.GRAY_900)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_MEDIUM)
        .width('100%')
        .margin({ top: DesignTokens.Spacing.XXL, bottom: DesignTokens.Spacing.MD })

      Column() {
        Text($r('app.string.about_version'))
          .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
          .fontColor(DesignTokens.Colors.GRAY_700)
          .margin({
            top: DesignTokens.Spacing.LG,
            bottom: DesignTokens.Spacing.XS
          })

        Text($r('app.string.about_slogan'))
          .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
          .fontColor(DesignTokens.Colors.GRAY_600)
          .margin({
            bottom: DesignTokens.Spacing.LG
          })
          
        Row() {
          Text($r('app.string.about_privacy'))
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.PRIMARY)
            .onClick(() => {
              this.onShowPrivacy();
            })
          
          Divider().vertical(true).height(16).color(DesignTokens.Colors.GRAY_400).margin({ left: 16, right: 16 })
          
          Text($r('app.string.about_license'))
            .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
            .fontColor(DesignTokens.Colors.PRIMARY)
            .onClick(() => {
              this.openLicenseDialog();
            })
        }
        .margin({ bottom: DesignTokens.Spacing.LG })
        
        Text($r('app.string.about_project'))
            .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
            .fontColor(DesignTokens.Colors.GRAY_500)
            .margin({ bottom: DesignTokens.Spacing.XS })
            
        Text($r('app.string.about_email'))
            .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
            .fontColor(DesignTokens.Colors.GRAY_500)
            .margin({ bottom: DesignTokens.Spacing.XS })

        Text($r('app.string.about_qq'))
            .fontSize(DesignTokens.Typography.FONT_SIZE_XS)
            .fontColor(DesignTokens.Colors.GRAY_500)
            .margin({ bottom: DesignTokens.Spacing.LG })

      }
      .width('100%')
      .backgroundColor(DesignTokens.Colors.WHITE)
      .borderRadius(DesignTokens.BorderRadius.LG)
      .shadow(DesignTokens.Shadows.CARD_ELEVATION_1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
  }
}
