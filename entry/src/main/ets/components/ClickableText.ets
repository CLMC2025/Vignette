// =====================================================
// ClickableText.ets - 可点击文本组件
// 解析文本中的英文单词，使其可点击显示单词详情
// =====================================================

import { DesignTokens } from '../model/DesignTokens';

/**
 * 文本片段类型
 */
export enum TextSegmentType {
  WORD = 'word',
  PUNCTUATION = 'punctuation',
  WHITESPACE = 'whitespace'
}

/**
 * 文本片段
 */
export interface TextSegment {
  type: TextSegmentType;
  text: string;
  index: number;
}

/**
 * 可点击文本组件配置
 */
export interface ClickableTextOptions {
  text: string;
  fontSize?: number;
  fontColor?: ResourceColor;
  wordColor?: ResourceColor;
  fontWeight?: FontWeight;
  lineHeight?: number;
  onWordClick?: (word: string) => void;
}

/**
 * 可点击文本组件
 * 将文本中的英文单词解析为可点击的元素
 */
@Component
export struct ClickableText {
  @Prop text: string = '';
  @Prop fontSize: number = 14;
  @Prop fontColor: ResourceColor = DesignTokens.Colors.GRAY_800;
  @Prop wordColor: ResourceColor = DesignTokens.Colors.PRIMARY;
  @Prop fontWeight: FontWeight = FontWeight.Normal;
  @Prop lineHeight: number = 22;
  onWordClick: (word: string) => void = () => {};

  /**
   * 解析文本为片段
   */
  private parseText(text: string): TextSegment[] {
    const segments: TextSegment[] = [];
    let currentIndex = 0;

    while (currentIndex < text.length) {
      const char = text[currentIndex];

      // 检查是否是英文字母
      if (/[a-zA-Z]/.test(char)) {
        // 提取完整单词
        let word = '';
        let startIndex = currentIndex;
        while (currentIndex < text.length && /[a-zA-Z]/.test(text[currentIndex])) {
          word += text[currentIndex];
          currentIndex++;
        }
        segments.push({
          type: TextSegmentType.WORD,
          text: word,
          index: startIndex
        });
      }
      // 检查是否是空白字符
      else if (/\s/.test(char)) {
        let whitespace = '';
        let startIndex = currentIndex;
        while (currentIndex < text.length && /\s/.test(text[currentIndex])) {
          whitespace += text[currentIndex];
          currentIndex++;
        }
        segments.push({
          type: TextSegmentType.WHITESPACE,
          text: whitespace,
          index: startIndex
        });
      }
      // 其他字符（标点符号等）
      else {
        segments.push({
          type: TextSegmentType.PUNCTUATION,
          text: char,
          index: currentIndex
        });
        currentIndex++;
      }
    }

    return segments;
  }

  build() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.parseText(this.text), (segment: TextSegment, index: number) => {
        if (segment.type === TextSegmentType.WORD) {
          Text(segment.text)
            .fontSize(this.fontSize)
            .fontColor(this.wordColor)
            .fontWeight(this.fontWeight)
            .onClick(() => {
              this.onWordClick(segment.text.toLowerCase());
            })
        } else {
          Text(segment.text)
            .fontSize(this.fontSize)
            .fontColor(this.fontColor)
            .fontWeight(this.fontWeight)
        }
      }, (segment: TextSegment, index: number) => `${segment.index}-${segment.text}`)
    }
    .width('100%')
  }
}

/**
 * 可点击文本构建器函数
 * 用于在 Builder 方法中快速创建可点击文本
 */
export function buildClickableText(
  text: string,
  fontSize: number = 14,
  fontColor: ResourceColor = DesignTokens.Colors.GRAY_800,
  wordColor: ResourceColor = DesignTokens.Colors.PRIMARY,
  onWordClick: (word: string) => void = () => {}
): ClickableText {
  return new ClickableText({
    text: text,
    fontSize: fontSize,
    fontColor: fontColor,
    wordColor: wordColor,
    onWordClick: onWordClick
  });
}
