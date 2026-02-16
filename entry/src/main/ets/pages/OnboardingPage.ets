import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';
import { GuideManager } from '../manager/GuideManager';
import { GuideStep, GUIDE_CATEGORIES, GuideCategoryInfo } from '../model/GuideModels';

@Entry
@Component
struct OnboardingPage {
  private context: common.UIAbilityContext | null = null;
  private guideManager: GuideManager = GuideManager.getInstance();
  private steps: GuideStep[] = [];
  @State currentIndex: number = 0;
  @State isAnimating: boolean = false;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    this.guideManager.injectContext(this.context);
    void this.guideManager.initialize();
    this.steps = this.guideManager.getGuideSteps();
  }

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private getCategoryInfo(category: string): GuideCategoryInfo {
    const found = GUIDE_CATEGORIES.find((c: GuideCategoryInfo) => c.id === category);
    return found ?? GUIDE_CATEGORIES[GUIDE_CATEGORIES.length - 1];
  }

  private async skip(): Promise<void> {
    try {
      await this.guideManager.skipOnboarding();
      promptAction.showToast({ message: '可随时在设置中查看引导', duration: 1500 });
      router.back();
    } catch (_) {
      router.back();
    }
  }

  private async finish(): Promise<void> {
    try {
      await this.guideManager.completeOnboarding();
      promptAction.showToast({ message: '引导完成，开始学习吧！', duration: 1500 });
      router.back();
    } catch (_) {
      router.back();
    }
  }

  private prevStep(): void {
    if (this.currentIndex > 0 && !this.isAnimating) {
      this.isAnimating = true;
      this.currentIndex--;
      setTimeout(() => {
        this.isAnimating = false;
      }, 300);
    }
  }

  private nextStep(): void {
    if (this.currentIndex < this.steps.length - 1 && !this.isAnimating) {
      this.isAnimating = true;
      this.currentIndex++;
      void this.guideManager.completeStep(this.steps[this.currentIndex].id);
      setTimeout(() => {
        this.isAnimating = false;
      }, 300);
    } else if (this.currentIndex === this.steps.length - 1) {
      void this.finish();
    }
  }

  @Builder
  stepIndicator() {
    Row({ space: 6 }) {
      ForEach(this.steps, (step: GuideStep, index: number) => {
        Column()
          .width(index === this.currentIndex ? 20 : 8)
          .height(8)
          .backgroundColor(index === this.currentIndex
            ? this.colors.PRIMARY
            : this.colors.GRAY_300)
          .borderRadius(4)
          .animation({
            duration: 300,
            curve: Curve.EaseInOut
          })
      }, (step: GuideStep) => step.id)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .margin({ top: 16, bottom: 16 })
  }

  @Builder
  stepCard(step: GuideStep) {
    Column() {
      Text(step.icon)
        .fontSize(48)
        .margin({ bottom: 16 })

      Text(step.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors.GRAY_900)
        .textAlign(TextAlign.Center)
        .margin({ bottom: 8 })

      Text(step.description)
        .fontSize(15)
        .fontColor(this.colors.PRIMARY)
        .textAlign(TextAlign.Center)
        .margin({ bottom: 20 })

      Column() {
        Text(step.detail)
          .fontSize(14)
          .fontColor(this.colors.GRAY_600)
          .lineHeight(22)
          .textAlign(TextAlign.Start)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.colors.SURFACE_PRIMARY)
      .borderRadius(12)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(24)
    .backgroundColor(this.colors.SURFACE_ELEVATED)
    .borderRadius(20)
    .shadow({
      radius: 16,
      color: 'rgba(0, 0, 0, 0.08)',
      offsetX: 0,
      offsetY: 4
    })
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor(this.colors.GRAY_600)
          .padding(8)
          .onClick(() => router.back())

        Text('使用引导')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.GRAY_900)
          .layoutWeight(1)
          .margin({ left: 4 })

        Text('跳过')
          .fontSize(14)
          .fontColor(this.colors.GRAY_500)
          .padding(8)
          .onClick(() => { void this.skip(); })
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 10, bottom: 6 })

      Column() {
        if (this.steps.length > 0) {
          Stack() {
            ForEach(this.steps, (step: GuideStep, index: number) => {
              if (Math.abs(index - this.currentIndex) <= 1) {
                Column() {
                  this.stepCard(step)
                }
                .width('100%')
                .opacity(index === this.currentIndex ? 1 : 0)
                .scale({ x: index === this.currentIndex ? 1 : 0.95, y: index === this.currentIndex ? 1 : 0.95 })
                .animation({
                  duration: 300,
                  curve: Curve.EaseInOut
                })
                .visibility(index === this.currentIndex ? Visibility.Visible : Visibility.None)
              }
            }, (step: GuideStep) => step.id)
          }
          .width('100%')
          .layoutWeight(1)
          .alignContent(Alignment.Center)

          this.stepIndicator()

          Row() {
            Button('上一步')
              .height(44)
              .fontSize(15)
              .fontColor(this.colors.GRAY_700)
              .backgroundColor(this.colors.GRAY_100)
              .borderRadius(22)
              .enabled(this.currentIndex > 0)
              .opacity(this.currentIndex > 0 ? 1 : 0.5)
              .onClick(() => this.prevStep())

            Blank()

            Button(this.currentIndex === this.steps.length - 1 ? '完成' : '下一步')
              .height(44)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.colors.WHITE)
              .backgroundColor(this.colors.PRIMARY)
              .borderRadius(22)
              .onClick(() => this.nextStep())
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.BACKGROUND_PRIMARY)
    .id('onboarding_' + this.themeRefreshToken)
  }
}
