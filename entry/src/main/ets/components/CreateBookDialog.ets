import { DesignTokens } from '../model/DesignTokens';
import { validateUserWordBookName } from '../utils/UserWordBookNameValidator';

export interface CreateBookDialogResult {
  name: string;
}

@Component
export struct CreateBookDialog {
  @Prop visible: boolean = false;
  onCancel: (() => void) | undefined = undefined;
  onCreate: ((result: CreateBookDialogResult) => void) | undefined = undefined;
  @State private name: string = '';
  @State private errorText: string = '';
  @State private submitting: boolean = false;

  aboutToAppear(): void {
    this.resetIfNeeded();
  }

  aboutToUpdate(): void {
    this.resetIfNeeded();
  }

  private resetIfNeeded(): void {
    if (!this.visible) {
      this.name = '';
      this.errorText = '';
      this.submitting = false;
    }
  }

  private cancel(): void {
    this.submitting = false;
    if (this.onCancel !== undefined) {
      this.onCancel();
    }
  }

  private submit(): void {
    const err = validateUserWordBookName(this.name);
    if (err.length > 0) {
      this.errorText = err;
      return;
    }
    if (this.onCreate === undefined) {
      return;
    }
    this.errorText = '';
    this.submitting = true;
    const result: CreateBookDialogResult = { name: this.name.trim() };
    this.onCreate(result);
  }

  build() {
    Stack() {
      if (this.visible) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
          .opacity(0.45)
          .onClick(() => this.cancel());

        Column() {
          Text('创建词书')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(DesignTokens.Colors.GRAY_900)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 12 });

          TextInput({ text: this.name, placeholder: '请输入词书名称（最多20字）' })
            .width('100%')
            .height(44)
            .fontSize(14)
            .backgroundColor(DesignTokens.Colors.GRAY_100)
            .borderRadius(DesignTokens.BorderRadius.LG)
            .padding({ left: 12, right: 12 })
            .maxLength(20)
            .onChange((value: string) => {
              this.name = value;
              if (this.errorText.length > 0) {
                this.errorText = '';
              }
            });

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(12)
              .fontColor('#D32F2F')
              .margin({ top: 8 })
              .width('100%');
          } else {
            Blank()
              .height(20);
          }

          Row({ space: 12 }) {
            Button('取消')
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(DesignTokens.Colors.GRAY_800)
              .backgroundColor(DesignTokens.Colors.GRAY_200)
              .borderRadius(DesignTokens.BorderRadius.FULL)
              .onClick(() => this.cancel());

            Button(this.submitting ? '创建中...' : '创建')
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(DesignTokens.Colors.WHITE)
              .backgroundColor(DesignTokens.Colors.PRIMARY)
              .borderRadius(DesignTokens.BorderRadius.FULL)
              .enabled(!this.submitting)
              .onClick(() => this.submit());
          }
          .width('100%')
          .margin({ top: 6 });
        }
        .width('88%')
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(DesignTokens.BorderRadius.XL)
        .position({ x: '6%', y: '32%' });
      }
    }
    .width(this.visible ? '100%' : '0%')
    .height(this.visible ? '100%' : '0%');
  }
}
