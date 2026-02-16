import { DesignTokens } from '../../model/DesignTokens';
import { ColorsInterface } from '../../model/TokenInterfaces';
import { ThemeManager } from '../../manager/ThemeManager';

interface DictOption {
  name: string;
  template: string;
}

const DICT_OPTIONS: DictOption[] = [
  { name: '有道词典', template: 'https://www.youdao.com/result?word={word}&lang=en' },
  { name: '剑桥词典', template: 'https://dictionary.cambridge.org/dictionary/english/{word}' },
  { name: '欧路词典', template: 'https://www.eudic.net/v4/en/app/eudic?word={word}' }
];

@Component
export struct ExternalDictionarySection {
  @Link externalDictEnabled: boolean;
  @Link externalDictUrlTemplate: string;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  @State private selectedIndex: number = 0;

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  aboutToAppear(): void {
    this.selectedIndex = this.findSelectedIndex();
  }

  private findSelectedIndex(): number {
    const index = DICT_OPTIONS.findIndex(opt => opt.template === this.externalDictUrlTemplate);
    return index >= 0 ? index : 0;
  }

  private selectDictionary(index: number): void {
    this.selectedIndex = index;
    this.externalDictUrlTemplate = DICT_OPTIONS[index].template;
  }

  @Builder
  private buildDictItem(item: DictOption, index: number) {
    Row() {
      Text(item.name)
        .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
        .fontColor(this.colors.TEXT_PRIMARY)
        .layoutWeight(1)

      if (this.selectedIndex === index) {
        Text('✓')
          .fontSize(18)
          .fontColor(this.colors.PRIMARY)
          .fontWeight(FontWeight.Bold)
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
    .backgroundColor(this.selectedIndex === index ? this.colors.PRIMARY_LIGHTEST : Color.Transparent)
    .onClick(() => this.selectDictionary(index))
  }

  build() {
    Column() {
      Text('外部词典')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors.TEXT_PRIMARY)
        .width('100%')
        .margin({ bottom: DesignTokens.Spacing.MD })

      Column() {
        Row() {
          Column() {
            Text('启用外部词典')
              .fontSize(DesignTokens.Typography.FONT_SIZE_BASE)
              .fontColor(this.colors.GRAY_700)
            Text('在单词详情页显示外部词典入口')
              .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
              .fontColor(this.colors.GRAY_500)
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Toggle({ type: ToggleType.Switch, isOn: this.externalDictEnabled })
            .selectedColor(this.colors.PRIMARY)
            .switchPointColor(this.colors.WHITE)
            .onChange((v: boolean) => {
              this.externalDictEnabled = v;
            })
        }
        .width('100%')
        .height(64)
        .padding({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

        if (this.externalDictEnabled) {
          Divider().color(this.colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })

          Text('选择词典')
            .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
            .fontColor(this.colors.GRAY_600)
            .width('100%')
            .padding({ left: DesignTokens.Spacing.LG, top: DesignTokens.Spacing.MD, bottom: DesignTokens.Spacing.SM })

          Column() {
            ForEach(DICT_OPTIONS, (item: DictOption, index: number) => {
              this.buildDictItem(item, index)
              if (index < DICT_OPTIONS.length - 1) {
                Divider().color(this.colors.GRAY_200).margin({ left: DesignTokens.Spacing.LG, right: DesignTokens.Spacing.LG })
              }
            }, (item: DictOption) => item.name)
          }
          .width('100%')
          .padding({ bottom: DesignTokens.Spacing.MD })
        }
      }
      .width('100%')
      .backgroundColor(this.colors.SURFACE_PRIMARY)
      .borderRadius(DesignTokens.BorderRadius.LG)
    }
    .width('100%')
    .padding(DesignTokens.Spacing.MD)
  }
}
