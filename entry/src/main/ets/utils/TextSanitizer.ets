export class TextSanitizer {
  private static fixLeadingArtifacts(text: string): string {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return '';
    }
    const fixed = trimmed.replace(/^(The)\s+(a|an|your|my|our|this|that|these|those)\b/i, '$2');
    return fixed.trim();
  }

  private static stripLinePrefixes(text: string): string {
    if (text.length === 0) {
      return '';
    }
    const lines = text.split('\n');
    const out: string[] = [];
    for (let i = 0; i < lines.length; i++) {
      const cleaned = TextSanitizer.stripCommonLinePrefix(lines[i]);
      out.push(cleaned);
    }
    return out.join('\n').trim();
  }

  private static stripCommonLinePrefix(line: string): string {
    let out = line.trim();
    if (out.length === 0) {
      return '';
    }

    out = out.replace(/^(?:[-*•]\s+)/, '');
    out = out.replace(/^\d{1,3}(?:[.)]\s+)/, '');

    if (/^(?:[IVX]{1,5})(?:[.)]?\s+)[A-Z]/.test(out)) {
      out = out.replace(/^(?:[IVX]{1,5})(?:[.)]?\s+)/, '');
    }

    return out.trim();
  }

  static stripMarkdownEmphasis(text: string): string {
    if (text.length === 0) {
      return '';
    }
    let out = text.replace(/\*\*([^\n*]+)\*\*/g, '$1');
    out = out.replace(/\*([^\n*]+)\*/g, '$1');
    out = out.replace(/\*\*/g, '');
    return out.replace(/\*/g, '');
  }

  static normalizeSpacesPreserveNewlines(text: string): string {
    if (text.length === 0) {
      return '';
    }
    const lines = text.split('\n');
    const out: string[] = [];
    for (const line of lines) {
      const trimmed = line.replace(/[\t ]+/g, ' ').trim();
      out.push(trimmed);
    }
    return out.join('\n').trim();
  }

  static sanitizeContext(text: string): string {
    const noEmphasis = TextSanitizer.stripMarkdownEmphasis(text);
    const normalized = TextSanitizer.normalizeSpacesPreserveNewlines(noEmphasis);
    const stripped = TextSanitizer.stripLinePrefixes(normalized);
    return TextSanitizer.fixLeadingArtifacts(stripped);
  }
}
