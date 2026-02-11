@Component
export struct PrivacyPolicyDialog {
  @Prop privacyLines: string[];
  onAccept: () => void = () => {};
  onReject: () => void = () => {};

  // Copied from Index.ets to ensure self-contained logic
  private readonly PRIVACY_HEADINGS: string[] = [
    '引言',
    '信息收集',
    '我们收集的信息',
    '我们不收集的信息',
    '数据使用',
    '数据安全',
    '用户权利',
    '第三方 AI 服务',
    '第三方服务',
    '儿童隐私',
    '政策更新',
    '联系我们',
    '同意声明'
  ];

  private isPrivacyHeading(text: string): boolean {
    const trimmed = text.trim();
    if (trimmed.startsWith('## ') || trimmed.startsWith('### ') || trimmed.startsWith('# ')) {
      return true;
    }
    if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
      return true;
    }
    return this.PRIVACY_HEADINGS.indexOf(this.normalizePrivacyLine(trimmed)) >= 0;
  }

  private normalizePrivacyLine(text: string): string {
    const trimmed = text.trim();
    if (trimmed.startsWith('### ')) {
      return trimmed.slice(4).replace(/\*\*/g, '');
    }
    if (trimmed.startsWith('## ')) {
      return trimmed.slice(3).replace(/\*\*/g, '');
    }
    if (trimmed.startsWith('# ')) {
      return trimmed.slice(2).replace(/\*\*/g, '');
    }
    if (trimmed.startsWith('**') && trimmed.endsWith('**')) {
      return trimmed.slice(2, trimmed.length - 2);
    }
    return trimmed.replace(/\*\*/g, '');
  }

  private buildPrivacyDisplayLine(text: string): string {
    const unordered = /^(\s*)[-*]\s+(.+)$/.exec(text);
    if (unordered !== null) {
      const level = Math.min(2, Math.floor(unordered[1].length / 2));
      const marker = level === 0 ? '• ' : level === 1 ? '◦ ' : '▪ ';
      return `${marker}${this.normalizePrivacyLine(unordered[2])}`;
    }
    const ordered = /^(\s*)(\d+)\.\s+(.+)$/.exec(text);
    if (ordered !== null) {
      return `${ordered[2]}. ${this.normalizePrivacyLine(ordered[3])}`;
    }
    return this.normalizePrivacyLine(text);
  }

  build() {
    Stack() {
        Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#000000')
            .opacity(0.5)

        Column() {
        Column() {
            Text('隐私政策')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ bottom: 8 })

            Scroll() {
            Column() {
                ForEach(this.privacyLines, (line: string) => {
                if (this.isPrivacyHeading(line)) {
                    Text(this.normalizePrivacyLine(line))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#333333')
                    .textAlign(TextAlign.Start)
                    .width('100%')
                    .margin({ top: 10, bottom: 4 })
                } else {
                    Text(this.buildPrivacyDisplayLine(line))
                    .fontSize(12)
                    .fontColor('#666666')
                    .textAlign(TextAlign.Start)
                    .width('100%')
                    .margin({ top: 4 })
                }
                }, (line: string, index?: number) => `${index ?? 0}_${line}`)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            }
            .height(320)
            .scrollBar(BarState.On)
            .margin({ bottom: 16 })

            Row() {
            Button('不同意')
                .width('45%')
                .height(44)
                .fontSize(16)
                .fontColor('#FFFFFF')
                .backgroundColor('#666666')
                .borderRadius(22)
                .onClick(() => {
                this.onReject();
                })

            Blank()

            Button('同意并进入')
                .width('45%')
                .height(44)
                .fontSize(16)
                .fontColor('#FFFFFF')
                .backgroundColor('#2196F3')
                .borderRadius(22)
                .onClick(() => {
                this.onAccept();
                })
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
  }
}
