// =====================================================
// SSPMMC.ets - Stochastic Shortest Path (SSP) solver with MMC-style
// value iteration.
//
// We discretize the continuous (difficulty d, half-life h) space into
// (D x H) states and compute an optimal review interval policy.
//
// This is an on-device approximation. You can later refine:
// - state discretization
// - cost function
// - transition model (fit from history)
// =====================================================

import { DHPModel, DHPState } from './DHPModel';

export interface SSPConfig {
  dBins: number;
  hBins: number;
  minH: number;
  maxH: number;
  // Review interval candidate actions (days)
  actions: number[];
  // Goal half-life (in days). Reaching >= goal means "mastered".
  goalHalfLife: number;
  // Costs
  reviewCost: number;
  failureCost: number;
  // Discount factor (0,1]
  gamma: number;
  // Iteration limits
  maxIterations: number;
  tolerance: number;
}

export interface SSPPolicy {
  version: number;
  trainedAtMs: number;
  config: SSPConfig;
  // Best action index for each state (flattened: dIdx*hBins + hIdx)
  actionIndex: number[];
}

export class SSPMMC {
  private model: DHPModel;
  private cfg: SSPConfig;

  constructor(model: DHPModel, cfg?: Partial<SSPConfig>) {
    this.model = model;
    
    // Initialize with default values
    this.cfg = {
      dBins: 10,
      hBins: 30,
      minH: 0.25,
      maxH: 3650,
      actions: [1, 2, 3, 4, 7, 10, 14, 21, 30, 45, 60, 90],
      goalHalfLife: 180,
      reviewCost: 1.0,
      failureCost: 2.5,
      gamma: 1.0,
      maxIterations: 200,
      tolerance: 1e-4,
    };
    
    // Manually merge cfg if provided
    if (cfg) {
      if (cfg.dBins !== undefined) {
        this.cfg.dBins = cfg.dBins;
      }
      if (cfg.hBins !== undefined) {
        this.cfg.hBins = cfg.hBins;
      }
      if (cfg.minH !== undefined) {
        this.cfg.minH = cfg.minH;
      }
      if (cfg.maxH !== undefined) {
        this.cfg.maxH = cfg.maxH;
      }
      if (cfg.actions !== undefined) {
        this.cfg.actions = cfg.actions;
      }
      if (cfg.goalHalfLife !== undefined) {
        this.cfg.goalHalfLife = cfg.goalHalfLife;
      }
      if (cfg.reviewCost !== undefined) {
        this.cfg.reviewCost = cfg.reviewCost;
      }
      if (cfg.failureCost !== undefined) {
        this.cfg.failureCost = cfg.failureCost;
      }
      if (cfg.gamma !== undefined) {
        this.cfg.gamma = cfg.gamma;
      }
      if (cfg.maxIterations !== undefined) {
        this.cfg.maxIterations = cfg.maxIterations;
      }
      if (cfg.tolerance !== undefined) {
        this.cfg.tolerance = cfg.tolerance;
      }
    }
  }

  getConfig(): SSPConfig {
    // Create a deep copy of the config with a new actions array
    return {
      dBins: this.cfg.dBins,
      hBins: this.cfg.hBins,
      minH: this.cfg.minH,
      maxH: this.cfg.maxH,
      actions: this.cfg.actions.slice(), // Create a copy of the actions array
      goalHalfLife: this.cfg.goalHalfLife,
      reviewCost: this.cfg.reviewCost,
      failureCost: this.cfg.failureCost,
      gamma: this.cfg.gamma,
      maxIterations: this.cfg.maxIterations,
      tolerance: this.cfg.tolerance,
    };
  }

  train(version: number = 1): SSPPolicy {
    const dBins = this.cfg.dBins;
    const hBins = this.cfg.hBins;
    const nStates = dBins * hBins;

    const V: number[] = new Array(nStates).fill(0);
    const pi: number[] = new Array(nStates).fill(0);

    // Initialize: optimistic for goal states
    for (let d = 0; d < dBins; d++) {
      for (let h = 0; h < hBins; h++) {
        const idx = this.sIndex(d, h);
        const hVal = this.hFromBin(h);
        V[idx] = hVal >= this.cfg.goalHalfLife ? 0 : 5;
      }
    }

    for (let it = 0; it < this.cfg.maxIterations; it++) {
      let delta = 0;

      for (let d = 0; d < dBins; d++) {
        for (let h = 0; h < hBins; h++) {
          const sIdx = this.sIndex(d, h);
          const hVal = this.hFromBin(h);
          if (hVal >= this.cfg.goalHalfLife) {
            V[sIdx] = 0;
            pi[sIdx] = this.cfg.actions.length - 1;
            continue;
          }

          const state: DHPState = { d: this.dFromBin(d), h: hVal };
          let best = Number.POSITIVE_INFINITY;
          let bestA = 0;

          for (let a = 0; a < this.cfg.actions.length; a++) {
            const interval = this.cfg.actions[a];
            const p = this.model.recallProb(state.h, interval);

            const sSucc = this.model.step(state, interval, true);
            const sFail = this.model.step(state, interval, false);
            const succIdx = this.stateToIndex(sSucc);
            const failIdx = this.stateToIndex(sFail);

            const q = this.cfg.reviewCost
              + this.cfg.gamma * (p * V[succIdx] + (1 - p) * (this.cfg.failureCost + V[failIdx]));

            if (q < best) {
              best = q;
              bestA = a;
            }
          }

          const old = V[sIdx];
          V[sIdx] = best;
          pi[sIdx] = bestA;
          const diff = Math.abs(old - best);
          if (diff > delta) delta = diff;
        }
      }

      if (delta < this.cfg.tolerance) {
        break;
      }
    }

    return {
      version,
      trainedAtMs: Date.now(),
      config: this.getConfig(),
      actionIndex: pi
    };
  }

  /**
   * Lookup recommended interval days given a continuous state.
   */
  recommendIntervalDays(state: DHPState, policy: SSPPolicy): number {
    const idx = this.stateToIndex(state, policy.config);
    const aIdx = policy.actionIndex[idx] ?? 0;
    const act = policy.config.actions[aIdx] ?? policy.config.actions[0];
    return act;
  }

  private stateToIndex(state: DHPState, cfg?: SSPConfig): number {
    const c = cfg ?? this.cfg;
    const dIdx = this.dToBin(state.d, c.dBins);
    const hIdx = this.hToBin(state.h, c.hBins, c.minH, c.maxH);
    return dIdx * c.hBins + hIdx;
  }

  private sIndex(dIdx: number, hIdx: number): number {
    return dIdx * this.cfg.hBins + hIdx;
  }

  private dToBin(d: number, bins: number): number {
    const dd = Math.max(1, Math.min(10, d));
    const x = (dd - 1) / 9;
    const idx = Math.floor(x * bins);
    return Math.max(0, Math.min(bins - 1, idx));
  }

  private dFromBin(bin: number): number {
    const x = (bin + 0.5) / this.cfg.dBins;
    return 1 + 9 * x;
  }

  private hToBin(h: number, bins: number, minH: number, maxH: number): number {
    const hh = Math.max(minH, Math.min(maxH, h));
    // log-scale discretization
    const logMin = Math.log(minH);
    const logMax = Math.log(maxH);
    const x = (Math.log(hh) - logMin) / (logMax - logMin);
    const idx = Math.floor(x * bins);
    return Math.max(0, Math.min(bins - 1, idx));
  }

  private hFromBin(bin: number): number {
    const logMin = Math.log(this.cfg.minH);
    const logMax = Math.log(this.cfg.maxH);
    const x = (bin + 0.5) / this.cfg.hBins;
    return Math.exp(logMin + x * (logMax - logMin));
  }
}
