import { DesignTokens } from '../model/DesignTokens';

@Component
export struct SkeletonLoader {
  @Prop loaderWidth: number | string = '100%';
  @Prop loaderHeight: number | string = 16;
  @Prop cornerRadius: number = DesignTokens.BorderRadius.SM;
  @State private shimmerPosition: number = -200;

  aboutToAppear(): void {
    this.startAnimation();
  }

  private startAnimation(): void {
    const animate = (): void => {
      animateTo({
        duration: 1500,
        curve: Curve.Linear,
        onFinish: () => {
          this.shimmerPosition = -200;
          setTimeout(() => animate(), 300);
        }
      }, () => {
        this.shimmerPosition = 600;
      });
    };
    animate();
  }

  build() {
    Stack() {
      Column()
        .width(this.loaderWidth)
        .height(this.loaderHeight)
        .backgroundColor(DesignTokens.Colors.GRAY_200)
        .borderRadius(this.cornerRadius)

      Column()
        .width(100)
        .height(this.loaderHeight)
        .linearGradient({
          angle: 90,
          colors: [
            ['transparent', 0],
            ['rgba(255,255,255,0.6)', 0.5],
            ['transparent', 1]
          ]
        })
        .borderRadius(this.cornerRadius)
        .position({ x: this.shimmerPosition, y: 0 })
    }
    .width(this.loaderWidth)
    .height(this.loaderHeight)
    .clip(true)
    .borderRadius(this.cornerRadius)
  }
}

@Component
export struct SkeletonText {
  @Prop lines: number = 3;
  @Prop lineHeight: number = 14;
  @Prop lineSpacing: number = 8;
  @Prop lastLineWidth: string = '60%';

  build() {
    Column({ space: this.lineSpacing }) {
      ForEach(Array.from({ length: this.lines }), (_: ESObject, index: number) => {
        SkeletonLoader({
          loaderWidth: index === this.lines - 1 ? this.lastLineWidth : '100%',
          loaderHeight: this.lineHeight,
          cornerRadius: DesignTokens.BorderRadius.SM
        })
      }, (_: ESObject, index: number) => `skeleton-line-${index}`)
    }
    .width('100%')
  }
}

@Component
export struct SkeletonCard {
  @Prop cardHeight: number = 120;
  @Prop showAvatar: boolean = false;
  @Prop showImage: boolean = false;

  build() {
    Column({ space: DesignTokens.Spacing.MD }) {
      if (this.showAvatar) {
        Row({ space: DesignTokens.Spacing.MD }) {
          SkeletonLoader({
            loaderWidth: 48,
            loaderHeight: 48,
            cornerRadius: 24
          })

          Column({ space: 8 }) {
            SkeletonLoader({
              loaderWidth: 120,
              loaderHeight: 14,
              cornerRadius: DesignTokens.BorderRadius.SM
            })
            SkeletonLoader({
              loaderWidth: 80,
              loaderHeight: 12,
              cornerRadius: DesignTokens.BorderRadius.SM
            })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
      }

      if (this.showImage) {
        SkeletonLoader({
          loaderWidth: '100%',
          loaderHeight: 100,
          cornerRadius: DesignTokens.BorderRadius.MD
        })
      }

      SkeletonText({
        lines: 2,
        lineHeight: 14,
        lineSpacing: 8
      })
    }
    .width('100%')
    .height(this.cardHeight)
    .padding(DesignTokens.Spacing.LG)
    .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
    .borderRadius(DesignTokens.BorderRadius.LG)
  }
}

@Component
export struct SkeletonProgressCard {
  build() {
    Column({ space: DesignTokens.Spacing.LG }) {
      Row() {
        Column({ space: 8 }) {
          SkeletonLoader({
            loaderWidth: 150,
            loaderHeight: 20,
            cornerRadius: DesignTokens.BorderRadius.SM
          })
          SkeletonLoader({
            loaderWidth: 100,
            loaderHeight: 14,
            cornerRadius: DesignTokens.BorderRadius.SM
          })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        SkeletonLoader({
          loaderWidth: 70,
          loaderHeight: 70,
          cornerRadius: 35
        })
      }
      .width('100%')

      Row({ space: DesignTokens.Spacing.LG }) {
        ForEach([1, 2, 3], (item: number) => {
          Row({ space: 8 }) {
            SkeletonLoader({
              loaderWidth: 20,
              loaderHeight: 20,
              cornerRadius: DesignTokens.BorderRadius.SM
            })
            Column({ space: 4 }) {
              SkeletonLoader({
                loaderWidth: 30,
                loaderHeight: 18,
                cornerRadius: DesignTokens.BorderRadius.SM
              })
              SkeletonLoader({
                loaderWidth: 40,
                loaderHeight: 12,
                cornerRadius: DesignTokens.BorderRadius.SM
              })
            }
          }
        }, (item: number) => `stat-${item}`)
      }
      .width('100%')

      SkeletonLoader({
        loaderWidth: '100%',
        loaderHeight: 48,
        cornerRadius: 24
      })
    }
    .width('100%')
    .padding(DesignTokens.Spacing.XL)
    .backgroundColor(DesignTokens.Colors.GRAY_100)
    .borderRadius(DesignTokens.BorderRadius.XL)
  }
}

@Component
export struct SkeletonHeatmap {
  @Prop rows: number = 7;
  @Prop columns: number = 20;

  build() {
    Row() {
      Column({ space: 2 }) {
        ForEach(Array.from({ length: this.rows }), (_: ESObject, index: number) => {
          Text(['一', '二', '三', '四', '五', '六', '日'][index])
            .fontSize(9)
            .fontColor(DesignTokens.Colors.GRAY_300)
            .width(14)
            .height(10)
            .textAlign(TextAlign.Center)
        }, (_: ESObject, index: number) => `label-${index}`)
      }
      .margin({ right: 4 })

      Scroll() {
        Row({ space: 2 }) {
          ForEach(Array.from({ length: this.columns }), (_: ESObject, colIndex: number) => {
            Column({ space: 2 }) {
              ForEach(Array.from({ length: this.rows }), (_: ESObject, rowIndex: number) => {
                SkeletonLoader({
                  loaderWidth: 10,
                  loaderHeight: 10,
                  cornerRadius: 2
                })
              }, (_: ESObject, rowIndex: number) => `cell-${colIndex}-${rowIndex}`)
            }
          }, (_: ESObject, colIndex: number) => `col-${colIndex}`)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
  }
}

@Component
export struct SkeletonStatCard {
  build() {
    Row({ space: DesignTokens.Spacing.SM }) {
      ForEach([1, 2, 3, 4], (item: number) => {
        Column({ space: DesignTokens.Spacing.SM }) {
          SkeletonLoader({
            loaderWidth: 24,
            loaderHeight: 24,
            cornerRadius: DesignTokens.BorderRadius.SM
          })
          SkeletonLoader({
            loaderWidth: 40,
            loaderHeight: 20,
            cornerRadius: DesignTokens.BorderRadius.SM
          })
          SkeletonLoader({
            loaderWidth: 30,
            loaderHeight: 12,
            cornerRadius: DesignTokens.BorderRadius.SM
          })
        }
        .layoutWeight(1)
        .padding(DesignTokens.Spacing.MD)
        .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
        .borderRadius(DesignTokens.BorderRadius.LG)
      }, (item: number) => `stat-card-${item}`)
    }
    .width('100%')
  }
}

@Component
export struct SkeletonHomePage {
  build() {
    Column({ space: DesignTokens.Spacing.LG }) {
      Row() {
        Column({ space: 8 }) {
          SkeletonLoader({
            loaderWidth: 100,
            loaderHeight: 12,
            cornerRadius: DesignTokens.BorderRadius.SM
          })
          Row({ space: 8 }) {
            SkeletonLoader({
              loaderWidth: 120,
              loaderHeight: 18,
              cornerRadius: DesignTokens.BorderRadius.SM
            })
            SkeletonLoader({
              loaderWidth: 16,
              loaderHeight: 12,
              cornerRadius: DesignTokens.BorderRadius.SM
            })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        SkeletonLoader({
          loaderWidth: 40,
          loaderHeight: 40,
          cornerRadius: 20
        })
      }
      .width('100%')

      SkeletonProgressCard()

      Row({ space: DesignTokens.Spacing.SM }) {
        ForEach([1, 2], (item: number) => {
          Column({ space: 8 }) {
            Row() {
              SkeletonLoader({
                loaderWidth: 60,
                loaderHeight: 14,
                cornerRadius: DesignTokens.BorderRadius.SM
              })
              Blank()
              SkeletonLoader({
                loaderWidth: 16,
                loaderHeight: 14,
                cornerRadius: DesignTokens.BorderRadius.SM
              })
            }
            .width('100%')

            Blank()

            Row({ space: 4 }) {
              SkeletonLoader({
                loaderWidth: 40,
                loaderHeight: 22,
                cornerRadius: DesignTokens.BorderRadius.SM
              })
              SkeletonLoader({
                loaderWidth: 20,
                loaderHeight: 14,
                cornerRadius: DesignTokens.BorderRadius.SM
              })
            }

            SkeletonLoader({
              loaderWidth: '100%',
              loaderHeight: 6,
              cornerRadius: 3
            })
          }
          .layoutWeight(1)
          .height(110)
          .padding(16)
          .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
          .borderRadius(16)
        }, (item: number) => `plan-card-${item}`)
      }
      .width('100%')

      Column({ space: DesignTokens.Spacing.MD }) {
        Row() {
          SkeletonLoader({
            loaderWidth: 80,
            loaderHeight: 16,
            cornerRadius: DesignTokens.BorderRadius.SM
          })
          Blank()
          SkeletonLoader({
            loaderWidth: 50,
            loaderHeight: 12,
            cornerRadius: DesignTokens.BorderRadius.SM
          })
        }
        .width('100%')

        SkeletonHeatmap()
      }
      .width('100%')
      .padding(20)
      .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
      .borderRadius(20)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 10, bottom: 40 })
  }
}
