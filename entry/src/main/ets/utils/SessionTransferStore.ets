import { QueueItem } from '../model/WordModel';

export class SessionTransferStore {
  private static instance: SessionTransferStore | null = null;

  private ids: string[] = [];
  private queues: QueueItem[][] = [];
  private readonly maxSessions: number = 5;

  private constructor() {}

  static getInstance(): SessionTransferStore {
    if (SessionTransferStore.instance === null) {
      SessionTransferStore.instance = new SessionTransferStore();
    }
    return SessionTransferStore.instance;
  }

  put(queue: QueueItem[]): string {
    const id = `${Date.now()}_${Math.floor(Math.random() * 1_000_000)}`;
    this.ids.push(id);
    this.queues.push(queue);
    while (this.ids.length > this.maxSessions) {
      this.ids.shift();
      this.queues.shift();
    }
    return id;
  }

  take(sessionId: string): QueueItem[] | null {
    const idx = this.ids.indexOf(sessionId);
    if (idx < 0) {
      return null;
    }
    const queue = this.queues[idx];
    this.ids.splice(idx, 1);
    this.queues.splice(idx, 1);
    return queue;
  }
}

