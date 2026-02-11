export class HistoryPopResult<T> {
  stack: HistoryStack<T>;
  item: T | null;

  constructor(stack: HistoryStack<T>, item: T | null) {
    this.stack = stack;
    this.item = item;
  }
}

export class HistoryStack<T> {
  private readonly capacity: number;
  private readonly items: T[];

  constructor(capacity: number, items: T[] = []) {
    this.capacity = Math.max(1, capacity);
    this.items = items.slice(0, Math.max(0, items.length));
    while (this.items.length > this.capacity) {
      this.items.shift();
    }
  }

  size(): number {
    return this.items.length;
  }

  isEmpty(): boolean {
    return this.items.length === 0;
  }

  toArray(): T[] {
    return [...this.items];
  }

  push(item: T): HistoryStack<T> {
    const next: T[] = this.toArray();
    next.push(item);
    while (next.length > this.capacity) {
      next.shift();
    }
    return new HistoryStack<T>(this.capacity, next);
  }

  pop(): HistoryPopResult<T> {
    const next: T[] = this.toArray();
    if (next.length === 0) {
      return new HistoryPopResult<T>(new HistoryStack<T>(this.capacity, next), null);
    }
    const item: T = next[next.length - 1];
    next.splice(next.length - 1, 1);
    return new HistoryPopResult<T>(new HistoryStack<T>(this.capacity, next), item);
  }

  peek(): T | null {
    if (this.items.length === 0) {
      return null;
    }
    return this.items[this.items.length - 1];
  }

  clear(): HistoryStack<T> {
    return new HistoryStack<T>(this.capacity, []);
  }
}
