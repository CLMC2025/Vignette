// =====================================================
// DHPModel.ets - Discrete Half-life & Difficulty model (DHP)
//
// This is a lightweight on-device approximation inspired by the
// DHP family of models (half-life + difficulty). It provides:
// - Recall probability prediction: p=2^{-t/h}
// - State transition heuristics for success/failure
// 
// NOTE:
// The parameter learning portion can be improved using local review
// history. For now we estimate a few transition scalars from observed
// FSRS stability changes.
// =====================================================

export interface DHPState {
  d: number; // difficulty in [1, 10]
  h: number; // half-life in days
}

export interface DHPParams {
  successHGain: number; // multiplicative gain on success (approx)
  failHShrink: number; // multiplicative shrink on failure (approx)
  dDec: number;
  dInc: number;
  minH: number;
  maxH: number;
}

export interface StabilityPair {
  before: number;
  after: number;
  success: boolean;
}

export class DHPModel {
  private params: DHPParams;

  constructor(params?: Partial<DHPParams>) {
    this.params = {
      successHGain: 1.22,
      failHShrink: 0.35,
      dDec: 0.10,
      dInc: 0.30,
      minH: 0.25,
      maxH: 3650
    };
    if (params) {
      if (params.successHGain !== undefined) {
        this.params.successHGain = params.successHGain;
      }
      if (params.failHShrink !== undefined) {
        this.params.failHShrink = params.failHShrink;
      }
      if (params.dDec !== undefined) {
        this.params.dDec = params.dDec;
      }
      if (params.dInc !== undefined) {
        this.params.dInc = params.dInc;
      }
      if (params.minH !== undefined) {
        this.params.minH = params.minH;
      }
      if (params.maxH !== undefined) {
        this.params.maxH = params.maxH;
      }
    }
  }

  getParams(): DHPParams {
    return {
      successHGain: this.params.successHGain,
      failHShrink: this.params.failHShrink,
      dDec: this.params.dDec,
      dInc: this.params.dInc,
      minH: this.params.minH,
      maxH: this.params.maxH
    };
  }

  setParams(params: Partial<DHPParams>): void {
    const newParams: DHPParams = {
      successHGain: this.params.successHGain,
      failHShrink: this.params.failHShrink,
      dDec: this.params.dDec,
      dInc: this.params.dInc,
      minH: this.params.minH,
      maxH: this.params.maxH
    };
    if (params.successHGain !== undefined) {
      newParams.successHGain = params.successHGain;
    }
    if (params.failHShrink !== undefined) {
      newParams.failHShrink = params.failHShrink;
    }
    if (params.dDec !== undefined) {
      newParams.dDec = params.dDec;
    }
    if (params.dInc !== undefined) {
      newParams.dInc = params.dInc;
    }
    if (params.minH !== undefined) {
      newParams.minH = params.minH;
    }
    if (params.maxH !== undefined) {
      newParams.maxH = params.maxH;
    }
    this.params = newParams;
  }

  recallProb(halfLifeDays: number, elapsedDays: number): number {
    const h = Math.max(this.params.minH, halfLifeDays);
    const t = Math.max(0, elapsedDays);
    const p = Math.pow(2, -t / h);
    if (Number.isNaN(p) || !Number.isFinite(p)) return 0;
    return Math.max(0, Math.min(1, p));
  }

  /**
   * Update state after scheduling an interval and getting outcome.
   */
  step(state: DHPState, intervalDays: number, success: boolean): DHPState {
    const d0 = this.clamp(state.d, 1, 10);
    const h0 = this.clamp(state.h, this.params.minH, this.params.maxH);
    const dNorm = (d0 - 1) / 9;

    if (success) {
      // Easier words grow faster
      const gain = 1 + (this.params.successHGain - 1) * (1 - 0.55 * dNorm);
      const h1 = this.clamp(h0 * gain + 0.02 * intervalDays, this.params.minH, this.params.maxH);
      const d1 = this.clamp(d0 - this.params.dDec, 1, 10);
      return { d: d1, h: h1 };
    }

    // Failure: half-life shrinks, difficulty increases
    const hFail = this.clamp(h0 * this.params.failHShrink, this.params.minH, this.params.maxH);
    const dFail = this.clamp(d0 + this.params.dInc, 1, 10);
    return { d: dFail, h: hFail };
  }

  /**
   * Estimate a few transition parameters from observed stability changes.
   */
  fitFromStability(pairs: StabilityPair[]): void {
    if (pairs.length === 0) return;

    const successRatios: number[] = [];
    const failRatios: number[] = [];

    for (const p of pairs) {
      const b = Math.max(0.01, p.before);
      const a = Math.max(0.01, p.after);
      const ratio = a / b;
      if (p.success) {
        successRatios.push(ratio);
      } else {
        failRatios.push(ratio);
      }
    }

    const avgSuccess = this.average(successRatios, 1.22);
    const avgFail = this.average(failRatios, 0.35);

    // Clamp to reasonable ranges to avoid instability
    this.params.successHGain = this.clamp(avgSuccess, 1.05, 1.8);
    this.params.failHShrink = this.clamp(avgFail, 0.1, 0.8);
  }

  private average(nums: number[], fallback: number): number {
    if (nums.length === 0) return fallback;
    let s = 0;
    for (const v of nums) s += v;
    return s / nums.length;
  }

  private clamp(v: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, v));
  }
}
