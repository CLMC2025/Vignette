// =====================================================
// OptimizerService.ets - On-device FSRS/DHP optimizer
//
// Goal:
// - Read local review events (history)
// - Fit a lightweight DHP transition model
// - Train an SSP-MMC policy table
// - Return a model package that can be synced via WebDAV
// =====================================================

import { DBManager, ReviewEventRow } from '../database/DBManager';
import { FSRSState } from '../model/WordModel';
import { DHPModel, StabilityPair } from './DHPModel';
import { SSPMMC, SSPConfig, SSPPolicy } from './SSPMMC';
import { DHPParamsRecord, EvolveModelPackage, EvolveModelStore, SSPModelConfig } from './ModelStore';

interface TrainingStats {
  totalEvents: number;
  usedPairs: number;
  successCount: number;
  failCount: number;
  maxStability: number;
}

export class OptimizerService {
  private static instance: OptimizerService | null = null;

  private readonly db: DBManager = DBManager.getInstance();

  private constructor() {}

  static getInstance(): OptimizerService {
    if (OptimizerService.instance === null) {
      OptimizerService.instance = new OptimizerService();
    }
    return OptimizerService.instance;
  }

  /**
   * Train a new evolution model from local review history.
   *
   * Notes:
   * - If history is insufficient, returns a conservative default model.
   * - The returned model is safe to apply immediately.
   */
  async trainFromLocalHistory(): Promise<EvolveModelPackage> {
    const prev = EvolveModelStore.getLocalModel();
    const nextVersion = (prev?.version ?? 0) + 1;

    let events: ReviewEventRow[] = [];
    try {
      // Cap count to avoid heavy I/O.
      events = await this.db.getRecentReviewEvents(8000);
    } catch (e) {
      console.warn('[OptimizerService] Failed to load review events:', e instanceof Error ? e.message : String(e));
      return this.buildDefaultModel(nextVersion, 'no_history');
    }

    const stats: TrainingStats = {
      totalEvents: events.length,
      usedPairs: 0,
      successCount: 0,
      failCount: 0,
      maxStability: 0
    };

    const pairs: StabilityPair[] = [];
    for (const ev of events) {
      const prevState = FSRSState.fromJSON(ev.prevStateJson);
      const newState = FSRSState.fromJSON(ev.newStateJson);

      const beforeS = this.clampPositive(prevState.stability);
      const afterS = this.clampPositive(newState.stability);

      if (afterS <= 0 || beforeS <= 0) {
        continue;
      }

      const success = (ev.rating !== 1); // AGAIN=1
      if (success) {
        stats.successCount++;
      } else {
        stats.failCount++;
      }

      pairs.push({ before: beforeS, after: afterS, success });
      stats.usedPairs++;
      if (afterS > stats.maxStability) stats.maxStability = afterS;
    }

    // Not enough signal → default model.
    if (pairs.length < 30) {
      return this.buildDefaultModel(nextVersion, 'insufficient_history');
    }

    // 1) Fit DHP from stability-change ratios.
    const dhp = new DHPModel();
    dhp.fitFromStability(pairs);

    // 2) Train policy table using SSP-MMC.
    const config = this.buildConfigFromStats(stats);
    // SSPMMC constructor: (model, cfg)
    const trainer = new SSPMMC(dhp, config);
    const policy: SSPPolicy = trainer.train(nextVersion);

    const model: EvolveModelPackage = {
      version: policy.version,
      trainedAtMs: policy.trainedAtMs,
      algo: 'SSPMMC_DHP',
      policy: policy.actionIndex,
      config: this.toModelConfig(policy.config),
      dhpParams: this.toDhpParams(dhp),
      meta: {
        totalEvents: stats.totalEvents,
        usedPairs: stats.usedPairs,
        successCount: stats.successCount,
        failCount: stats.failCount
      }
    };

    return model;
  }

  private clampPositive(v: number): number {
    if (!Number.isFinite(v)) return 0;
    if (v <= 0) return 0;
    return v;
  }

  private buildConfigFromStats(stats: TrainingStats): SSPConfig {
    // Build a conservative half-life range based on observed stability.
    // FSRS stability is "days until R=0.9"; convert to DHP half-life (R=0.5).
    const stability = Math.max(1, stats.maxStability);
    const maxHalfLife = Math.min(3650, stability * 4.6); // ~ S / -log2(0.9)

    return {
      dBins: 10,
      hBins: 30,
      minH: 0.25,
      maxH: Math.max(30, maxHalfLife),
      actions: [0.5, 1, 2, 3, 5, 7, 10, 14, 21, 30, 45, 60],
      goalHalfLife: 7,
      reviewCost: 1.0,
      failureCost: 2.5,
      gamma: 1.0,
      maxIterations: 200,
      tolerance: 1e-4
    };
  }

  private toModelConfig(cfg: SSPConfig): SSPModelConfig {
    return {
      dBins: cfg.dBins,
      hBins: cfg.hBins,
      minH: cfg.minH,
      maxH: cfg.maxH,
      actions: cfg.actions,
      goalHalfLife: cfg.goalHalfLife
    };
  }

  private toDhpParams(model: DHPModel): DHPParamsRecord {
    const params = model.getParams();
    return {
      successHGain: params.successHGain,
      failHShrink: params.failHShrink,
      dDec: params.dDec,
      dInc: params.dInc,
      minH: params.minH,
      maxH: params.maxH
    };
  }

  private buildDefaultModel(version: number, reason: string): EvolveModelPackage {
    const config: SSPConfig = {
      dBins: 10,
      hBins: 30,
      minH: 0.25,
      maxH: 3650,
      actions: [0.5, 1, 2, 3, 5, 7, 10, 14, 21, 30, 45, 60],
      goalHalfLife: 7,
      reviewCost: 1.0,
      failureCost: 2.5,
      gamma: 1.0,
      maxIterations: 200,
      tolerance: 1e-4
    };

    const dhp = new DHPModel();
    // SSPMMC constructor: (model, cfg)
    const trainer = new SSPMMC(dhp, config);
    const policy = trainer.train(version);

    return {
      version: policy.version,
      trainedAtMs: policy.trainedAtMs,
      algo: 'SSPMMC_DHP',
      policy: policy.actionIndex,
      config: this.toModelConfig(policy.config),
      dhpParams: this.toDhpParams(dhp),
      meta: {
        reason: reason
      }
    };
  }
}
