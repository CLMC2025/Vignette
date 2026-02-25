import { DesignTokens } from '../../model/DesignTokens';
import { ThemeManager } from '../../manager/ThemeManager';
import { ColorsInterface } from '../../model/TokenInterfaces';

@Component
export struct OptionButton {
  @Prop label: string = '';
  @Prop isSelected: boolean = false;
  onButtonClick: () => void = () => {};
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  build() {
    Text(this.label)
      .fontSize(DesignTokens.Typography.FONT_SIZE_SM)
      .fontColor(this.isSelected ? this.colors.WHITE : this.colors.TEXT_PRIMARY)
      .fontWeight(this.isSelected ? DesignTokens.Typography.FONT_WEIGHT_MEDIUM : DesignTokens.Typography.FONT_WEIGHT_REGULAR)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.isSelected ? this.colors.PRIMARY : this.colors.GRAY_100)
      .borderRadius(DesignTokens.BorderRadius.MD)
      .onClick(this.onButtonClick)
  }
}
