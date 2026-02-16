import { DesignTokens } from '../model/DesignTokens';
import { validateUserWordBookName } from '../utils/UserWordBookNameValidator';

export interface CreateBookDialogResult {
  name: string;
  category: string;
  difficulty: string;
  coverColor: string;
  icon: string;
}

@Component
export struct CreateBookDialog {
  @Prop visible: boolean = false;
  onCancel: (() => void) | undefined = undefined;
  onCreate: ((result: CreateBookDialogResult) => void) | undefined = undefined;
  @State private name: string = '';
  @State private errorText: string = '';
  @State private submitting: boolean = false;
  @State private selectedCategory: string = '其他';
  @State private selectedDifficulty: string = '初级';

  private readonly categoryOptions: string[] = ['考试', '商务', '旅游', '日常', '学术', '其他'];
  private readonly difficultyOptions: string[] = ['入门', '初级', '中级', '高级', '专家'];

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
    const result: CreateBookDialogResult = {
      name: this.name.trim(),
      category: this.selectedCategory,
      difficulty: this.selectedDifficulty,
      coverColor: '["#a8edea","#fed6e3"]',
      icon: '📚'
    };
    this.onCreate(result);
  }

  build() {
    Stack() {
      if (this.visible) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(DesignTokens.Colors.BLACK)
          .opacity(0.4)
          .onClick(() => this.cancel());

        Column() {
          Text('创建词书')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(DesignTokens.Colors.GRAY_900)
            .width('100%')
            .margin({ bottom: 16 });

          TextInput({ text: this.name, placeholder: '词书名称' })
            .width('100%')
            .height(44)
            .fontSize(15)
            .backgroundColor(DesignTokens.Colors.GRAY_100)
            .borderRadius(8)
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
              .fontColor(DesignTokens.Colors.ERROR)
              .margin({ top: 6 })
              .width('100%');
          }

          Text('分类')
            .fontSize(13)
            .fontColor(DesignTokens.Colors.GRAY_600)
            .margin({ top: 16 })
            .width('100%');

          Row() {
            ForEach(this.categoryOptions, (category: string) => {
              Text(category)
                .fontSize(13)
                .fontColor(this.selectedCategory === category ? DesignTokens.Colors.PRIMARY : DesignTokens.Colors.GRAY_600)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor(this.selectedCategory === category ? DesignTokens.Colors.PRIMARY_LIGHTEST : DesignTokens.Colors.GRAY_100)
                .borderRadius(6)
                .margin({ right: 6 })
                .onClick(() => {
                  this.selectedCategory = category;
                });
            });
          }
          .width('100%')
          .margin({ top: 8 });

          Text('难度')
            .fontSize(13)
            .fontColor(DesignTokens.Colors.GRAY_600)
            .margin({ top: 16 })
            .width('100%');

          Row() {
            ForEach(this.difficultyOptions, (difficulty: string) => {
              Text(difficulty)
                .fontSize(13)
                .fontColor(this.selectedDifficulty === difficulty ? DesignTokens.Colors.PRIMARY : DesignTokens.Colors.GRAY_600)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor(this.selectedDifficulty === difficulty ? DesignTokens.Colors.PRIMARY_LIGHTEST : DesignTokens.Colors.GRAY_100)
                .borderRadius(6)
                .margin({ right: 6 })
                .onClick(() => {
                  this.selectedDifficulty = difficulty;
                });
            });
          }
          .width('100%')
          .margin({ top: 8 });

          Row({ space: 12 }) {
            Text('取消')
              .fontSize(15)
              .fontColor(DesignTokens.Colors.GRAY_600)
              .layoutWeight(1)
              .height(44)
              .textAlign(TextAlign.Center)
              .backgroundColor(DesignTokens.Colors.GRAY_100)
              .borderRadius(8)
              .onClick(() => this.cancel());

            Text(this.submitting ? '创建中...' : '创建')
              .fontSize(15)
              .fontColor(DesignTokens.Colors.WHITE)
              .layoutWeight(1)
              .height(44)
              .textAlign(TextAlign.Center)
              .backgroundColor(DesignTokens.Colors.PRIMARY)
              .borderRadius(8)
              .onClick(() => this.submit());
          }
          .width('100%')
          .margin({ top: 24 });
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
