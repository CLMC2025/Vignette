import { DesignTokens } from '../model/DesignTokens';

@Component
export struct ImportGuideDialog {
  @Prop visible: boolean = false;
  onDismiss: (() => void) | undefined = undefined;
  onGoToSettings: (() => void) | undefined = undefined;

  private dismiss(): void {
    if (this.onDismiss !== undefined) {
      this.onDismiss();
    }
  }

  private goToSettings(): void {
    if (this.onGoToSettings !== undefined) {
      this.onGoToSettings();
    }
  }

  build() {
    Stack() {
      if (this.visible) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(DesignTokens.Colors.BLACK)
          .opacity(0.4)
          .onClick(() => this.dismiss());

        Column() {
          Text('未导入词书')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(DesignTokens.Colors.GRAY_900)
            .width('100%')
            .margin({ bottom: 12 });

          Text('词书未导入，无法查看单词详情')
            .fontSize(14)
            .fontColor(DesignTokens.Colors.GRAY_600)
            .width('100%')
            .textAlign(TextAlign.Start)
            .margin({ bottom: 24 });

          Row({ space: 12 }) {
            Text('取消')
              .fontSize(15)
              .fontColor(DesignTokens.Colors.GRAY_600)
              .layoutWeight(1)
              .height(44)
              .textAlign(TextAlign.Center)
              .backgroundColor(DesignTokens.Colors.GRAY_100)
              .borderRadius(8)
              .onClick(() => this.dismiss());

            Text('知道了')
              .fontSize(15)
              .fontColor(DesignTokens.Colors.WHITE)
              .layoutWeight(1)
              .height(44)
              .textAlign(TextAlign.Center)
              .backgroundColor(DesignTokens.Colors.PRIMARY)
              .borderRadius(8)
              .onClick(() => this.dismiss());
          }
          .width('100%');
        }
        .width('85%')
        .padding(20)
        .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
        .borderRadius(12);
      }
    }
    .width(this.visible ? '100%' : '0%')
    .height(this.visible ? '100%' : '0%')
    .alignContent(Alignment.Center);
  }
}
