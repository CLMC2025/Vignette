import { WordDefinition } from '../model/WordModel';
import { TextSanitizer } from './TextSanitizer';

export interface TranslationTextBuildInput {
  storyText: string;
  storyTranslation: string;
  targetWord: string;
  definition: WordDefinition | null;
  definitionLoading: boolean;
}

export function buildTranslationText(input: TranslationTextBuildInput): string {
  const target = input.targetWord.replace(/[<>]/g, '');
  const definition = input.definition ?? new WordDefinition();
  const sanitize = (value: string): string => TextSanitizer.stripMarkdownEmphasis(value).trim();
  const contextMeaning = sanitize(definition.contextMeaning);
  let out = '';

  if (input.storyText.length > 0) {
    if (input.storyTranslation.length > 0) {
      out += `【完整语境翻译】\n${sanitize(input.storyTranslation)}\n\n`;
    } else {
      out += '【完整语境翻译】\n加载中...\n\n';
    }

    if (contextMeaning.length > 0) {
      out += `【目标词\"${target}\"在语境中的释义】\n${contextMeaning}\n\n`;
    } else if (input.definitionLoading) {
      out += `【目标词\"${target}\"在语境中的释义】\n加载中...\n\n`;
    }

    if (definition.commonMeanings.length > 0) {
      out += '【完整词典释义】\n';
      for (let i = 0; i < definition.commonMeanings.length; i++) {
        const meaning = definition.commonMeanings[i];
        const pos = sanitize(meaning.pos);
        const cn = sanitize(meaning.cn);
        out += `${pos}: ${cn}`;
        if (i < definition.commonMeanings.length - 1) {
          out += '\n';
        }
      }
    } else if (input.definitionLoading) {
      out += '【完整词典释义】\n加载中...';
    }

    return out.trim().length > 0 ? out : '暂无释义';
  }

  if (contextMeaning.length > 0) {
    out += contextMeaning;
  }
  if (definition.commonMeanings.length > 0) {
    if (out.length > 0) {
      out += '\n\n';
    }
    out += '【完整词典释义】\n';
    for (let i = 0; i < definition.commonMeanings.length; i++) {
      const meaning = definition.commonMeanings[i];
      const pos = sanitize(meaning.pos);
      const cn = sanitize(meaning.cn);
      out += `${pos}: ${cn}`;
      if (i < definition.commonMeanings.length - 1) {
        out += '\n';
      }
    }
  }
  if (out.length === 0 && input.definitionLoading) {
    out = '加载中...';
  }
  return out.length > 0 ? out : '暂无释义';
}
