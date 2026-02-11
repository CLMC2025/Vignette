import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';

@Component
export struct SettingsSyncDialog {
  @Link visible: boolean;
  @Link title: string;
  @Link message: string;
  @Link data: string;
  @Link isImport: boolean;

  onImport: (data: string) => void = () => {};

  private async copyToClipboard(data: string): Promise<void> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.clearData();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, data);
      systemPasteboard.setPasteData(pasteData);
      promptAction.showToast({ message: '已复制到剪贴板', duration: 1500 });
    } catch (e) {
      promptAction.showToast({ message: '复制失败', duration: 1500 });
    }
  }

  build() {
    if (this.visible) {
      Stack() {
        // Backdrop
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
          .opacity(0.5)
          .onClick(() => {
            this.visible = false;
          })

        // Dialog Content
        Column() {
          Column() {
            Text(this.title.length > 0 ? this.title : '数据同步')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
              .margin({ bottom: 12 })

            if (this.message.length > 0) {
              Text(this.message)
                .fontSize(13)
                .fontColor('#666666')
                .margin({ bottom: 12 })
            }

            // Data area
            TextArea({ text: this.data, placeholder: this.isImport ? '在此粘贴 JSON...' : '' })
              .width('100%')
              .height(180)
              .fontSize(12)
              .backgroundColor('#F7F7F7')
              .borderRadius(8)
              .padding(8)
              .enabled(this.isImport)
              .onChange((value: string) => {
                this.data = value;
              })
              .margin({ bottom: 16 })

            Row() {
              if (!this.isImport) {
                Button('复制')
                  .width('45%')
                  .height(44)
                  .fontSize(16)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#2196F3')
                  .borderRadius(22)
                  .onClick(() => {
                    this.copyToClipboard(this.data.length > 0 ? this.data : this.message);
                  })

                Blank()

                Button('关闭')
                  .width('45%')
                  .height(44)
                  .fontSize(16)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#666666')
                  .borderRadius(22)
                  .onClick(() => {
                    this.visible = false;
                  })
              } else {
                Button('导入')
                  .width('45%')
                  .height(44)
                  .fontSize(16)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#4CAF50')
                  .borderRadius(22)
                  .enabled(this.data.trim().length > 0)
                  .onClick(() => {
                    this.onImport(this.data);
                  })

                Blank()

                Button('取消')
                  .width('45%')
                  .height(44)
                  .fontSize(16)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#666666')
                  .borderRadius(22)
                  .onClick(() => {
                    this.visible = false;
                  })
              }
            }
          }
          .width('90%')
          .padding(24)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .shadow({
            color: '#00000020',
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
