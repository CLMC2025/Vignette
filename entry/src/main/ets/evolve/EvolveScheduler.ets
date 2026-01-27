// =====================================================
// EvolveScheduler.ets - Apply evolved policy to scheduling
//
// Design:
// - Keep FSRS as the default core state update
// - Optionally adjust next interval based on an evolved SSP-MMC policy
// - Provide a conservative hybrid mode (min interval)
// =====================================================

import { FSRSState, Rating } from '../model/WordModel';
import { EvolveModelStore, EvolveModelPackage, SSPModelConfig } from './ModelStore';

export enum SchedulerMode {
  FSRS = 'FSRS',
  SSPMMC = 'SSPMMC',
  HYBRID = 'HYBRID'
}

export class EvolveScheduler {
  private static readonly KEY_MODE: string = 'scheduler_mode';

  // FSRS stability is defined as days until retrievability drops to ~0.9.
  // DHP half-life is defined at retrievability 0.5 (2^{-t/h}).
  // Convert by solving 0.9 = 2^{-S/h} => h = -S / log2(0.9) ≈ 4.57 * S.
  private static readonly STABILITY_TO_HALF_LIFE: number = 4.57;

  static getMode(): SchedulerMode {
    const v = AppStorage.get<string>(EvolveScheduler.KEY_MODE);
    if (v === SchedulerMode.SSPMMC) return SchedulerMode.SSPMMC;
    if (v === SchedulerMode.HYBRID) return SchedulerMode.HYBRID;
    return SchedulerMode.FSRS;
  }

  static setMode(mode: SchedulerMode): void {
    AppStorage.setOrCreate(EvolveScheduler.KEY_MODE, mode);
  }

  static getModel(): EvolveModelPackage | null {
    return EvolveModelStore.getLocalModel();
  }

  static getModelVersion(): number {
    return EvolveModelStore.getLocalModel()?.version ?? 0;
  }

  static getModelTrainedAtMs(): number {
    return EvolveModelStore.getLocalModel()?.trainedAtMs ?? 0;
  }

  /**
   * Recommend a next interval (days) using the evolved policy.
   * Returns null if no model is available.
   */
  static recommendIntervalDays(stateAfter: FSRSState): number | null {
    const model = EvolveModelStore.getLocalModel();
    if (model === null) return null;
    if (model.config === undefined) return null;

    const cfg = model.config;
    if (cfg.actions.length === 0 || model.policy.length === 0) return null;

    const halfLife = EvolveScheduler.toHalfLife(stateAfter.stability);
    const idx = EvolveScheduler.stateToIndex(stateAfter.difficulty, halfLife, cfg);
    const actionIndex = model.policy[idx] ?? 1;

    const action = cfg.actions[actionIndex] ?? cfg.actions[1] ?? 1;
    const interval = Math.max(1, Math.round(action));
    return interval;
  }

  /**
   * Decide the final interval based on scheduler mode.
   * - rating AGAIN keeps FSRS short lapse interval
   * - first review keeps FSRS (fast feedback)
   */
  static decideIntervalDays(
    mode: SchedulerMode,
    rating: Rating,
    isFirstReview: boolean,
    fsrsIntervalDays: number,
    stateAfter: FSRSState
  ): number {
    if (rating === Rating.AGAIN) {
      return fsrsIntervalDays;
    }
    if (isFirstReview) {
      return fsrsIntervalDays;
    }

    const policyInterval = EvolveScheduler.recommendIntervalDays(stateAfter);
    if (policyInterval === null) {
      return fsrsIntervalDays;
    }

    if (mode === SchedulerMode.SSPMMC) {
      return policyInterval;
    }
    if (mode === SchedulerMode.HYBRID) {
      return Math.max(1, Math.min(fsrsIntervalDays, policyInterval));
    }
    return fsrsIntervalDays;
  }

  private static toHalfLife(fsrsStability: number): number {
    const s = Math.max(0, fsrsStability);
    return Math.max(0.25, s * EvolveScheduler.STABILITY_TO_HALF_LIFE);
  }

  private static stateToIndex(difficulty: number, halfLife: number, cfg: SSPModelConfig): number {
    const dIdx = EvolveScheduler.dToBin(difficulty, cfg.dBins);
    const hIdx = EvolveScheduler.hToBin(halfLife, cfg);
    return dIdx * cfg.hBins + hIdx;
  }

  private static dToBin(d: number, dBins: number): number {
    const dd = Math.max(1, Math.min(10, d));
    const v = Math.floor(((dd - 1) / 9) * dBins);
    return Math.max(0, Math.min(dBins - 1, v));
  }

  private static hToBin(h: number, cfg: SSPModelConfig): number {
    const hh = Math.max(cfg.minH, Math.min(cfg.maxH, h));
    const logMin = Math.log(cfg.minH);
    const logMax = Math.log(cfg.maxH);
    const t = (Math.log(hh) - logMin) / Math.max(1e-9, (logMax - logMin));
    const v = Math.floor(t * cfg.hBins);
    return Math.max(0, Math.min(cfg.hBins - 1, v));
  }
}
