import { BuiltInWordBooks, WordBookDefinition } from '../model/WordBookCatalog';

export enum BookKind {
  System = 0,
  User = 1
}

export function classifyBookId(bookId: string): BookKind {
  const id = bookId.trim();
  if (id.length === 0) {
    return BookKind.System;
  }
  const found = BuiltInWordBooks.find((b: WordBookDefinition) => b.id === id);
  return found !== undefined ? BookKind.System : BookKind.User;
}

