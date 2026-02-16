export function validateUserWordBookName(name: string): string {
  const normalized = name.trim();
  if (normalized.length === 0) {
    return '请输入词书名称';
  }
  if (normalized.length > 20) {
    return '词书名称不能超过20个字符';
  }
  return '';
}

