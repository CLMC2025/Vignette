export interface FsrsParamsPackJSON {
  version?: string;
  w?: number[];
  requestRetention?: number;
  maximumInterval?: number;
  updatedAt?: number;
}

export class FsrsParamsPack {
  version: string;
  w: number[];
  requestRetention: number;
  maximumInterval: number;
  updatedAt: number;

  constructor(
    version: string = 'fsrs4anki-v6.1.1',
    w: number[] = [],
    requestRetention: number = 0.9,
    maximumInterval: number = 36500,
    updatedAt: number = Date.now()
  ) {
    this.version = version;
    this.w = w;
    this.requestRetention = requestRetention;
    this.maximumInterval = maximumInterval;
    this.updatedAt = updatedAt;
  }

  toJSON(): string {
    const obj: FsrsParamsPackJSON = {
      version: this.version,
      w: this.w,
      requestRetention: this.requestRetention,
      maximumInterval: this.maximumInterval,
      updatedAt: this.updatedAt
    };
    return JSON.stringify(obj);
  }

  static fromJSON(json: string): FsrsParamsPack | null {
    try {
      const obj = JSON.parse(json) as FsrsParamsPackJSON;
      const w = obj.w ?? null;
      if (w === null || w.length < 21) {
        return null;
      }
      const version = obj.version ?? 'fsrs4anki-v6.1.1';
      const requestRetention = obj.requestRetention ?? 0.9;
      const maximumInterval = obj.maximumInterval ?? 36500;
      const updatedAt = obj.updatedAt ?? Date.now();
      return new FsrsParamsPack(version, w, requestRetention, maximumInterval, updatedAt);
    } catch (e) {
      return null;
    }
  }
}

