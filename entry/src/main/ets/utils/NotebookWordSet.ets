export function addNotebookWord(prev: Set<string>, word: string): Set<string> {
  const next = new Set<string>(prev);
  next.add(word);
  return next;
}

export function removeNotebookWord(prev: Set<string>, word: string): Set<string> {
  const next = new Set<string>(prev);
  next.delete(word);
  return next;
}

