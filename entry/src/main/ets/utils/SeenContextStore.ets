export class SeenContextStore {
  private readonly storageKey: string;
  private readonly maxSize: number;

  constructor(storageKey: string, maxSize: number) {
    this.storageKey = storageKey;
    this.maxSize = Math.max(1, maxSize);
  }

  load(): Set<string> {
    const raw = AppStorage.get<string>(this.storageKey) ?? '';
    if (raw.length === 0) {
      return new Set<string>();
    }
    try {
      const arr = JSON.parse(raw) as string[];
      const set = new Set<string>();
      for (const id of arr) {
        if (typeof id === 'string' && id.length > 0) {
          set.add(id);
        }
      }
      return set;
    } catch (e) {
      return new Set<string>();
    }
  }

  save(ids: Set<string>): void {
    const arr: string[] = [];
    for (const id of ids) {
      arr.push(id);
    }
    while (arr.length > this.maxSize) {
      arr.shift();
    }
    AppStorage.setOrCreate(this.storageKey, JSON.stringify(arr));
  }

  add(id: string): void {
    if (id.length === 0) {
      return;
    }
    const set = this.load();
    set.add(id);
    this.save(set);
  }

  has(id: string): boolean {
    if (id.length === 0) {
      return false;
    }
    const set = this.load();
    return set.has(id);
  }

  clear(): void {
    AppStorage.setOrCreate(this.storageKey, '[]');
  }
}
