import { WordDefinition } from '../model/WordModel';
import { TextSanitizer } from './TextSanitizer';

export interface ContextDefinitionTextInput {
  storyTranslation: string;
  targetWord: string;
  definition: WordDefinition | null;
}

export function buildContextDefinitionText(input: ContextDefinitionTextInput): string {
  const safeWord = input.targetWord.replace(/[<>]/g, '');
  const def = input.definition ?? new WordDefinition();
  const sanitize = (value: string): string => TextSanitizer.stripMarkdownEmphasis(value).trim();
  let out = '';

  const translation = sanitize(input.storyTranslation);
  if (translation.length > 0) {
    out += `【完整语境翻译】\n${translation}\n\n`;
  }

  const phonetic = sanitize(def.phonetic);
  const pos = sanitize(def.pos);
  if (phonetic.length > 0 || pos.length > 0) {
    const parts: string[] = [];
    if (phonetic.length > 0) {
      parts.push(phonetic);
    }
    if (pos.length > 0) {
      parts.push(pos);
    }
    out += `【音标/词性】\n${parts.join('  ')}\n\n`;
  }

  const contextMeaning = sanitize(def.contextMeaning);
  if (contextMeaning.length > 0) {
    out += `【目标词\"${safeWord}\"在语境中的释义】\n${contextMeaning}\n\n`;
  }

  if (def.commonMeanings.length > 0) {
    out += '【完整词典释义】\n';
    for (let i = 0; i < def.commonMeanings.length; i++) {
      const meaning = def.commonMeanings[i];
      out += `${sanitize(meaning.pos)}: ${sanitize(meaning.cn)}`;
      if (i < def.commonMeanings.length - 1) {
        out += '\n';
      }
    }
    out += '\n\n';
  }

  if (def.phrases.length > 0) {
    out += '【常用短语/搭配】\n';
    for (let i = 0; i < def.phrases.length; i++) {
      const p = def.phrases[i];
      const phrase = sanitize(p.phrase);
      const meaning = sanitize(p.meaning);
      const example = sanitize(p.example);
      out += `${phrase}：${meaning}`;
      if (example.length > 0) {
        out += `\n例：${example}`;
      }
      if (i < def.phrases.length - 1) {
        out += '\n';
      }
    }
    out += '\n\n';
  }

  if (def.examples.length > 0) {
    out += '【例句】\n';
    for (let i = 0; i < def.examples.length; i++) {
      const e = def.examples[i];
      const sentence = sanitize(e.sentence);
      const translationText = sanitize(e.translation);
      out += sentence;
      if (translationText.length > 0) {
        out += `\n${translationText}`;
      }
      if (i < def.examples.length - 1) {
        out += '\n';
      }
    }
    out += '\n\n';
  }

  if (def.frequency > 0 || def.examTags.length > 0) {
    const metaParts: string[] = [];
    if (def.frequency > 0) {
      metaParts.push(`频率：${def.frequency}`);
    }
    if (def.examTags.length > 0) {
      metaParts.push(`考试：${def.examTags.join(',')}`);
    }
    out += `【词汇信息】\n${metaParts.join('  ')}\n\n`;
  }

  const trimmed = out.trim();
  return trimmed.length > 0 ? trimmed : '暂无释义';
}
