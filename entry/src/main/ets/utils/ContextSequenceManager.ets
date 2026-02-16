export class ContextSequenceManager {
  private sequence: string[] = [];
  private cursor: number = -1;

  init(firstId: string): void {
    this.sequence = [firstId];
    this.cursor = 0;
  }

  restore(sequence: string[], cursor: number): void {
    this.sequence = [...sequence];
    this.cursor = cursor;
  }

  getSequence(): string[] {
    return [...this.sequence];
  }

  getCursor(): number {
    return this.cursor;
  }

  canUndo(): boolean {
    return this.cursor > 0;
  }

  undo(): string | null {
    if (this.cursor <= 0) {
      return null;
    }
    this.cursor -= 1;
    return this.sequence[this.cursor];
  }

  next(getNextFreshId: () => string | null, exists: (id: string) => boolean): string | null {
    if (this.cursor >= 0 && this.cursor < this.sequence.length - 1) {
      const redoId = this.sequence[this.cursor + 1];
      if (exists(redoId)) {
        this.cursor += 1;
        return redoId;
      }
      this.sequence = this.sequence.slice(0, this.cursor + 1);
    }
    const freshId = getNextFreshId();
    if (freshId === null) {
      return null;
    }
    this.sequence.push(freshId);
    this.cursor = this.sequence.length - 1;
    return freshId;
  }
}
