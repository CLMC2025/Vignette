// =====================================================
// ModelStore.ets - Store and load evolution models locally
//
// We keep the model JSON in AppStorage for simplicity.
// If you need durable persistence across process kills,
// replace with preferences or file storage.
// =====================================================

/**
 * Minimal config required to interpret a policy table.
 */
export interface SSPModelConfig {
  dBins: number;
  hBins: number;
  minH: number;
  maxH: number;
  actions: number[];
  goalHalfLife: number;
}

/**
 * DHP transition parameters (optional, for future richer usage).
 */
export interface DHPParamsRecord {
  successHGain: number;
  failHShrink: number;
  dDec: number;
  dInc: number;
  minH: number;
  maxH: number;
}

/**
 * Model metadata interface
 */
export interface ModelMeta {
  // Training event stats
  totalEvents?: number;
  usedPairs?: number;
  successCount?: number;
  failCount?: number;
  // Reason for model creation (e.g., 'default', 'training_failed')
  reason?: string;
}

export interface EvolveModelPackage {
  version: number;
  trainedAtMs: number;
  algo: string;
  // Flattened policy table (action index for each discretized state)
  policy: number[];
  // Optional: needed to map a continuous state to policy index
  config?: SSPModelConfig;
  // Optional: fitted transition params
  dhpParams?: DHPParamsRecord;
  // Extra metadata
  meta: ModelMeta;
}

export class EvolveModelStore {
  private static readonly KEY: string = 'evolve_model_package';

  static getLocalModel(): EvolveModelPackage | null {
    const json = AppStorage.get<string>(EvolveModelStore.KEY);
    if (json === undefined || json.length === 0) {
      return null;
    }
    try {
      return JSON.parse(json) as EvolveModelPackage;
    } catch (e) {
      return null;
    }
  }

  static saveLocalModel(model: EvolveModelPackage): void {
    AppStorage.setOrCreate(EvolveModelStore.KEY, JSON.stringify(model));
  }
}
