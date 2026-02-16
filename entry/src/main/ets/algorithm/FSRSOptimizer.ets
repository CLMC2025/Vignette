/**
 * FSRSOptimizer.ets - FSRS Parameter Optimization
 * Implements Adam optimizer for FSRS parameters
 * Based on FSRS-6 algorithm with enhancements
 */

import { FSRSState, Rating, HistoryItem } from '../model/FSRSModels';

export interface OptimizationConfig {
  learningRate: number;
  epochs: number;
  batchSize: number;
  minReviews: number;
  l2Regularization: number;
  beta1: number;
  beta2: number;
  epsilon: number;
  autoOptimizeThreshold: number;
  autoOptimizeIntervalDays: number;
}

export interface OptimizationResult {
  success: boolean;
  oldParameters: number[];
  newParameters: number[];
  lossBefore: number;
  lossAfter: number;
  epochsRun: number;
  reviewCount: number;
  errorMessage?: string;
}

export interface OptimizationProgress {
  epoch: number;
  totalEpochs: number;
  currentLoss: number;
  progress: number;
}

export interface EvaluationResult {
  loss: number;
  rmse: number;
  accuracy: number;
}

export interface AutoOptimizeState {
  lastReviewCount: number;
  lastOptimizeTime: number;
  totalReviewsSinceOptimize: number;
  shouldPrompt: boolean;
}

export interface DifficultyParameters {
  global: number[];
  cet4: number[];
  cet6: number[];
  kaoyan: number[];
  custom: number[];
}

export interface AutoOptimizeCheckResult {
  shouldPrompt: boolean;
  reason: string;
}

interface SimulationResult {
  newState: FSRSState;
  predictedR: number;
}

interface ParameterStorageData {
  parameters: number[];
  timestamp: number;
  version: number;
  difficultyParams?: DifficultyParameters;
}

interface AdamState {
  m: number[];
  v: number[];
  t: number;
}

interface ExportData {
  globalParams: number[] | null;
  difficultyParams: DifficultyParameters | null;
  timestamp: number;
  autoState: AutoOptimizeState | null;
}

interface ImportData {
  globalParams?: number[];
  difficultyParams?: DifficultyParameters;
  autoState?: AutoOptimizeState;
}

function createDefaultConfig(): OptimizationConfig {
  return {
    learningRate: 0.01,
    epochs: 100,
    batchSize: 32,
    minReviews: 100,
    l2Regularization: 0.01,
    beta1: 0.9,
    beta2: 0.999,
    epsilon: 1e-8,
    autoOptimizeThreshold: 200,
    autoOptimizeIntervalDays: 7
  };
}

function copyConfig(src: OptimizationConfig): OptimizationConfig {
  return {
    learningRate: src.learningRate,
    epochs: src.epochs,
    batchSize: src.batchSize,
    minReviews: src.minReviews,
    l2Regularization: src.l2Regularization,
    beta1: src.beta1,
    beta2: src.beta2,
    epsilon: src.epsilon,
    autoOptimizeThreshold: src.autoOptimizeThreshold,
    autoOptimizeIntervalDays: src.autoOptimizeIntervalDays
  };
}

function mergeConfig(base: OptimizationConfig, partial: Partial<OptimizationConfig>): OptimizationConfig {
  const result: OptimizationConfig = {
    learningRate: partial.learningRate !== undefined ? partial.learningRate : base.learningRate,
    epochs: partial.epochs !== undefined ? partial.epochs : base.epochs,
    batchSize: partial.batchSize !== undefined ? partial.batchSize : base.batchSize,
    minReviews: partial.minReviews !== undefined ? partial.minReviews : base.minReviews,
    l2Regularization: partial.l2Regularization !== undefined ? partial.l2Regularization : base.l2Regularization,
    beta1: partial.beta1 !== undefined ? partial.beta1 : base.beta1,
    beta2: partial.beta2 !== undefined ? partial.beta2 : base.beta2,
    epsilon: partial.epsilon !== undefined ? partial.epsilon : base.epsilon,
    autoOptimizeThreshold: partial.autoOptimizeThreshold !== undefined ? partial.autoOptimizeThreshold : base.autoOptimizeThreshold,
    autoOptimizeIntervalDays: partial.autoOptimizeIntervalDays !== undefined ? partial.autoOptimizeIntervalDays : base.autoOptimizeIntervalDays
  };
  return result;
}

function copyAutoOptimizeState(src: AutoOptimizeState): AutoOptimizeState {
  return {
    lastReviewCount: src.lastReviewCount,
    lastOptimizeTime: src.lastOptimizeTime,
    totalReviewsSinceOptimize: src.totalReviewsSinceOptimize,
    shouldPrompt: src.shouldPrompt
  };
}

const DEFAULT_PARAMETERS: number[] = [
  0.4, 0.9, 2.3, 10.9, 4.93, 0.94, 0.86, 0.01, 1.49, 0.14, 0.94,
  2.18, 0.05, 0.34, 1.26, 0.29, 2.61, 0.96, 0.08, 0.04, 0.15
];

const PARAM_BOUNDS: [number, number][] = [
  [0.1, 10], [0.1, 10], [0.1, 10], [0.1, 20], [1, 10],
  [0.1, 5], [0.1, 5], [0.001, 1], [0.5, 5], [0.01, 1],
  [0.1, 5], [0.5, 5], [0.001, 1], [0.1, 2], [0.1, 5],
  [0.1, 2], [1, 5], [0.1, 5], [0.01, 1], [0.01, 1],
  [0.01, 0.5]
];

const PARAM_NAMES: string[] = [
  'S_Again', 'S_Hard', 'S_Good', 'S_Easy',
  'D_Init', 'D_Rating', 'D_Delta', 'D_MeanRev',
  'S_Short', 'S_ShortPen', 'S_ShortBonus',
  'S_Forget', 'D_Forget', 'S_ForgetExp', 'R_Forget',
  'Hard_Pen', 'Easy_Bonus',
  'S_Recall', 'R_Recall', 'S_RecallExp', 'Decay'
];

function copyArray(arr: number[]): number[] {
  const result: number[] = [];
  for (let i = 0; i < arr.length; i++) {
    result.push(arr[i]);
  }
  return result;
}

function createDefaultDifficultyParameters(): DifficultyParameters {
  return {
    global: copyArray(DEFAULT_PARAMETERS),
    cet4: copyArray(DEFAULT_PARAMETERS),
    cet6: copyArray(DEFAULT_PARAMETERS),
    kaoyan: copyArray(DEFAULT_PARAMETERS),
    custom: copyArray(DEFAULT_PARAMETERS)
  };
}

function copyDifficultyParameters(src: DifficultyParameters): DifficultyParameters {
  return {
    global: copyArray(src.global),
    cet4: copyArray(src.cet4),
    cet6: copyArray(src.cet6),
    kaoyan: copyArray(src.kaoyan),
    custom: copyArray(src.custom)
  };
}

export class FSRSOptimizer {
  private static instance: FSRSOptimizer | null = null;

  private parameters: number[];
  private difficultyParams: DifficultyParameters;
  private config: OptimizationConfig;
  private isOptimizing: boolean = false;
  private shouldAbort: boolean = false;
  private autoOptimizeState: AutoOptimizeState;

  private constructor() {
    this.parameters = copyArray(DEFAULT_PARAMETERS);
    this.config = createDefaultConfig();
    this.difficultyParams = createDefaultDifficultyParameters();
    this.autoOptimizeState = {
      lastReviewCount: 0,
      lastOptimizeTime: 0,
      totalReviewsSinceOptimize: 0,
      shouldPrompt: false
    };
  }

  static getInstance(): FSRSOptimizer {
    if (FSRSOptimizer.instance === null) {
      FSRSOptimizer.instance = new FSRSOptimizer();
    }
    return FSRSOptimizer.instance;
  }

  getParameters(): number[] {
    return copyArray(this.parameters);
  }

  setParameters(params: number[]): void {
    if (params.length >= 21) {
      this.parameters = copyArray(params);
    }
  }

  getDifficultyParameters(): DifficultyParameters {
    return copyDifficultyParameters(this.difficultyParams);
  }

  setDifficultyParameters(params: Partial<DifficultyParameters>): void {
    if (params.global) this.difficultyParams.global = copyArray(params.global);
    if (params.cet4) this.difficultyParams.cet4 = copyArray(params.cet4);
    if (params.cet6) this.difficultyParams.cet6 = copyArray(params.cet6);
    if (params.kaoyan) this.difficultyParams.kaoyan = copyArray(params.kaoyan);
    if (params.custom) this.difficultyParams.custom = copyArray(params.custom);
  }

  getParametersForDifficulty(difficultyLevel: number): number[] {
    switch (difficultyLevel) {
      case 1: return copyArray(this.difficultyParams.cet4);
      case 2: return copyArray(this.difficultyParams.cet6);
      case 3: return copyArray(this.difficultyParams.kaoyan);
      case 4: return copyArray(this.difficultyParams.custom);
      default: return copyArray(this.difficultyParams.global);
    }
  }

  getConfig(): OptimizationConfig {
    return copyConfig(this.config);
  }

  setConfig(config: Partial<OptimizationConfig>): void {
    this.config = mergeConfig(this.config, config);
  }

  getAutoOptimizeState(): AutoOptimizeState {
    return copyAutoOptimizeState(this.autoOptimizeState);
  }

  resetAutoOptimizeState(): void {
    this.autoOptimizeState = {
      lastReviewCount: 0,
      lastOptimizeTime: Date.now(),
      totalReviewsSinceOptimize: 0,
      shouldPrompt: false
    };
  }

  abort(): void {
    this.shouldAbort = true;
  }

  private clampParameters(params: number[]): number[] {
    const clamped: number[] = [];
    for (let i = 0; i < params.length && i < PARAM_BOUNDS.length; i++) {
      const min = PARAM_BOUNDS[i][0];
      const max = PARAM_BOUNDS[i][1];
      clamped.push(Math.max(min, Math.min(max, params[i])));
    }
    return clamped;
  }

  private powerForgettingCurve(t: number, s: number, decay: number): number {
    const factor = Math.pow(0.9, 1 / decay) - 1;
    return Math.pow(1 + factor * t / s, decay);
  }

  private initStability(w: number[], rating: Rating): number {
    const idx = rating - 1;
    return Math.max(0.1, w[idx]);
  }

  private initDifficulty(w: number[], rating: Rating): number {
    const d = w[4] - w[5] * (rating - 3);
    return Math.max(1, Math.min(10, d));
  }

  private nextDifficulty(w: number[], d: number, rating: Rating): number {
    const deltaDifficulty = w[6] * (rating - 3);
    const meanReversion = w[7] * (w[4] - d);
    let nextD = d + deltaDifficulty + meanReversion;
    return Math.max(1, Math.min(10, nextD));
  }

  private nextRecallStability(w: number[], d: number, s: number, r: number, rating: Rating): number {
    const hardPenalty = rating === Rating.HARD ? w[15] : 1;
    const easyBonus = rating === Rating.EASY ? w[16] : 1;
    const newS = s * Math.exp(w[17] * (rating - 3 + w[18])) * Math.pow(s, -w[19]) * hardPenalty * easyBonus;
    return Math.max(0.1, newS);
  }

  private nextForgetStability(w: number[], d: number, s: number, r: number): number {
    const newS = w[11] * Math.pow(d, -w[12]) * (Math.pow(s + 1, w[13]) - 1) * Math.exp(w[14] * (1 - r));
    return Math.max(0.1, newS);
  }

  private simulateReview(
    w: number[],
    state: FSRSState,
    rating: Rating,
    elapsedDays: number
  ): SimulationResult {
    const decay = -w[20];
    const predictedR = this.powerForgettingCurve(elapsedDays, state.stability, decay);

    const newState = state.clone();

    if (state.reps === 0 && state.lapses === 0 && state.stability <= 0) {
      newState.difficulty = this.initDifficulty(w, rating);
      newState.stability = this.initStability(w, rating);
    } else if (rating === Rating.AGAIN) {
      newState.difficulty = this.nextDifficulty(w, state.difficulty, rating);
      newState.stability = this.nextForgetStability(w, state.difficulty, state.stability, predictedR);
      newState.lapses += 1;
    } else {
      newState.difficulty = this.nextDifficulty(w, state.difficulty, rating);
      newState.stability = this.nextRecallStability(w, state.difficulty, state.stability, predictedR, rating);
      newState.reps += 1;
    }

    const result: SimulationResult = { newState: newState, predictedR: predictedR };
    return result;
  }

  private computeLoss(
    w: number[],
    history: HistoryItem[],
    l2Lambda: number
  ): number {
    let totalLoss = 0;
    const decay = -w[20];

    for (const item of history) {
      const elapsedDays = Math.max(0.01, (item.timestamp - (item.stateBefore.stability > 0 ? item.timestamp - item.scheduledDays * 24 * 60 * 60 * 1000 : item.timestamp)) / (24 * 60 * 60 * 1000));

      const predictedR = this.powerForgettingCurve(item.scheduledDays, item.stateAfter.stability, decay);

      const actualRecall = item.rating !== Rating.AGAIN ? 1 : 0;

      const bce = -(actualRecall * Math.log(Math.max(0.001, predictedR)) + (1 - actualRecall) * Math.log(Math.max(0.001, 1 - predictedR)));
      totalLoss += bce;
    }

    let l2Penalty = 0;
    for (const param of w) {
      l2Penalty += param * param;
    }
    totalLoss += l2Lambda * l2Penalty;

    return totalLoss / history.length;
  }

  private computeGradients(
    w: number[],
    history: HistoryItem[],
    epsilon: number = 0.0001
  ): number[] {
    const gradients: number[] = [];
    const baseLoss = this.computeLoss(w, history, this.config.l2Regularization);

    for (let i = 0; i < w.length; i++) {
      const wPlus = copyArray(w);
      wPlus[i] += epsilon;
      const lossPlus = this.computeLoss(wPlus, history, this.config.l2Regularization);
      gradients.push((lossPlus - baseLoss) / epsilon);
    }

    return gradients;
  }

  private initAdamState(paramCount: number): AdamState {
    return {
      m: new Array(paramCount).fill(0),
      v: new Array(paramCount).fill(0),
      t: 0
    };
  }

  private adamUpdate(
    params: number[],
    gradients: number[],
    adamState: AdamState
  ): number[] {
    const beta1 = this.config.beta1;
    const beta2 = this.config.beta2;
    const epsilon = this.config.epsilon;
    const learningRate = this.config.learningRate;
    
    adamState.t += 1;

    const updated: number[] = [];

    for (let i = 0; i < params.length; i++) {
      adamState.m[i] = beta1 * adamState.m[i] + (1 - beta1) * gradients[i];
      adamState.v[i] = beta2 * adamState.v[i] + (1 - beta2) * gradients[i] * gradients[i];

      const mHat = adamState.m[i] / (1 - Math.pow(beta1, adamState.t));
      const vHat = adamState.v[i] / (1 - Math.pow(beta2, adamState.t));

      updated.push(params[i] - learningRate * mHat / (Math.sqrt(vHat) + epsilon));
    }

    return updated;
  }

  checkAutoOptimize(currentReviewCount: number): AutoOptimizeCheckResult {
    const state = this.autoOptimizeState;
    const newReviews = currentReviewCount - state.lastReviewCount;
    
    if (newReviews > 0) {
      state.totalReviewsSinceOptimize += newReviews;
      state.lastReviewCount = currentReviewCount;
    }

    const daysSinceOptimize = (Date.now() - state.lastOptimizeTime) / (24 * 60 * 60 * 1000);

    if (state.totalReviewsSinceOptimize >= this.config.autoOptimizeThreshold) {
      state.shouldPrompt = true;
      const result: AutoOptimizeCheckResult = {
        shouldPrompt: true,
        reason: `已积累${state.totalReviewsSinceOptimize}条新复习记录，建议优化参数`
      };
      return result;
    }

    if (daysSinceOptimize >= this.config.autoOptimizeIntervalDays && currentReviewCount >= this.config.minReviews) {
      state.shouldPrompt = true;
      const result: AutoOptimizeCheckResult = {
        shouldPrompt: true,
        reason: `距离上次优化已${Math.floor(daysSinceOptimize)}天，建议重新优化参数`
      };
      return result;
    }

    const result: AutoOptimizeCheckResult = { shouldPrompt: false, reason: '' };
    return result;
  }

  async optimize(
    history: HistoryItem[],
    onProgress?: (progress: OptimizationProgress) => void,
    difficultyLevel?: number
  ): Promise<OptimizationResult> {
    if (history.length < this.config.minReviews) {
      const result: OptimizationResult = {
        success: false,
        oldParameters: copyArray(this.parameters),
        newParameters: copyArray(this.parameters),
        lossBefore: 0,
        lossAfter: 0,
        epochsRun: 0,
        reviewCount: history.length,
        errorMessage: `需要至少${this.config.minReviews}条复习记录，当前只有${history.length}条`
      };
      return result;
    }

    if (this.isOptimizing) {
      const result: OptimizationResult = {
        success: false,
        oldParameters: copyArray(this.parameters),
        newParameters: copyArray(this.parameters),
        lossBefore: 0,
        lossAfter: 0,
        epochsRun: 0,
        reviewCount: history.length,
        errorMessage: '优化正在进行中'
      };
      return result;
    }

    this.isOptimizing = true;
    this.shouldAbort = false;

    const targetParams = difficultyLevel !== undefined 
      ? this.getParametersForDifficulty(difficultyLevel) 
      : this.parameters;

    const oldParams = copyArray(targetParams);
    let currentParams = copyArray(targetParams);
    let bestParams = copyArray(targetParams);
    let bestLoss = this.computeLoss(currentParams, history, this.config.l2Regularization);
    const initialLoss = bestLoss;

    const adamState = this.initAdamState(currentParams.length);

    let epoch = 0;
    let noImprovementCount = 0;
    const maxNoImprovement = 15;

    try {
      for (epoch = 0; epoch < this.config.epochs; epoch++) {
        if (this.shouldAbort) {
          break;
        }

        const gradients = this.computeGradients(currentParams, history);

        currentParams = this.adamUpdate(currentParams, gradients, adamState);

        currentParams = this.clampParameters(currentParams);

        const currentLoss = this.computeLoss(currentParams, history, this.config.l2Regularization);

        if (currentLoss < bestLoss) {
          bestLoss = currentLoss;
          bestParams = copyArray(currentParams);
          noImprovementCount = 0;
        } else {
          noImprovementCount++;
        }

        if (onProgress) {
          const progress: OptimizationProgress = {
            epoch: epoch + 1,
            totalEpochs: this.config.epochs,
            currentLoss: currentLoss,
            progress: (epoch + 1) / this.config.epochs
          };
          onProgress(progress);
        }

        if (noImprovementCount >= maxNoImprovement) {
          break;
        }

        await new Promise<void>(resolve => setTimeout(resolve, 1));
      }

      this.parameters = bestParams;

      if (difficultyLevel !== undefined) {
        switch (difficultyLevel) {
          case 1: this.difficultyParams.cet4 = bestParams; break;
          case 2: this.difficultyParams.cet6 = bestParams; break;
          case 3: this.difficultyParams.kaoyan = bestParams; break;
          case 4: this.difficultyParams.custom = bestParams; break;
          default: this.difficultyParams.global = bestParams; break;
        }
      } else {
        this.difficultyParams.global = bestParams;
      }

      this.autoOptimizeState.lastOptimizeTime = Date.now();
      this.autoOptimizeState.totalReviewsSinceOptimize = 0;
      this.autoOptimizeState.shouldPrompt = false;

      const result: OptimizationResult = {
        success: true,
        oldParameters: oldParams,
        newParameters: bestParams,
        lossBefore: initialLoss,
        lossAfter: bestLoss,
        epochsRun: epoch,
        reviewCount: history.length
      };
      return result;
    } finally {
      this.isOptimizing = false;
    }
  }

  evaluateParameters(history: HistoryItem[]): EvaluationResult {
    if (history.length === 0) {
      const result: EvaluationResult = { loss: 0, rmse: 0, accuracy: 0 };
      return result;
    }

    const loss = this.computeLoss(this.parameters, history, 0);
    let sumSquaredError = 0;
    let correctPredictions = 0;

    const decay = -this.parameters[20];

    for (const item of history) {
      const predictedR = this.powerForgettingCurve(item.scheduledDays, item.stateAfter.stability, decay);
      const actualRecall = item.rating !== Rating.AGAIN ? 1 : 0;

      sumSquaredError += Math.pow(predictedR - actualRecall, 2);

      if ((predictedR >= 0.5 && actualRecall === 1) || (predictedR < 0.5 && actualRecall === 0)) {
        correctPredictions++;
      }
    }

    const result: EvaluationResult = {
      loss: loss,
      rmse: Math.sqrt(sumSquaredError / history.length),
      accuracy: correctPredictions / history.length
    };
    return result;
  }

  static formatParameters(params: number[]): string {
    return params.map((p, i) => `w[${i}]=${p.toFixed(4)}`).join(', ');
  }

  static compareParameters(oldParams: number[], newParams: number[]): string[] {
    const changes: string[] = [];

    for (let i = 0; i < Math.min(oldParams.length, newParams.length, PARAM_NAMES.length); i++) {
      const diff = newParams[i] - oldParams[i];
      const pctChange = oldParams[i] !== 0 ? (diff / oldParams[i]) * 100 : 0;
      changes.push(`${PARAM_NAMES[i]}: ${oldParams[i].toFixed(3)} → ${newParams[i].toFixed(3)} (${pctChange >= 0 ? '+' : ''}${pctChange.toFixed(1)}%)`);
    }

    return changes;
  }
}

export class FSRSParameterStore {
  private static instance: FSRSParameterStore | null = null;
  private readonly STORAGE_KEY = 'fsrs_parameters';
  private readonly STORAGE_KEY_TIMESTAMP = 'fsrs_parameters_timestamp';
  private readonly STORAGE_KEY_VERSION = 'fsrs_parameters_version';
  private readonly STORAGE_KEY_DIFFICULTY = 'fsrs_difficulty_params';
  private readonly STORAGE_KEY_AUTO = 'fsrs_auto_optimize_state';

  private constructor() {}

  static getInstance(): FSRSParameterStore {
    if (FSRSParameterStore.instance === null) {
      FSRSParameterStore.instance = new FSRSParameterStore();
    }
    return FSRSParameterStore.instance;
  }

  saveParameters(params: number[]): void {
    const data: ParameterStorageData = {
      parameters: params,
      timestamp: Date.now(),
      version: 2
    };
    AppStorage.setOrCreate(this.STORAGE_KEY, JSON.stringify(data.parameters));
    AppStorage.setOrCreate(this.STORAGE_KEY_TIMESTAMP, String(data.timestamp));
    AppStorage.setOrCreate(this.STORAGE_KEY_VERSION, String(data.version));
  }

  saveDifficultyParameters(params: DifficultyParameters): void {
    AppStorage.setOrCreate(this.STORAGE_KEY_DIFFICULTY, JSON.stringify(params));
  }

  loadParameters(): number[] | null {
    const stored = AppStorage.get<string>(this.STORAGE_KEY);
    if (stored && stored.length > 0) {
      try {
        const parsed: object = JSON.parse(stored);
        if (Array.isArray(parsed)) {
          const params = parsed as number[];
          if (params.length >= 21) {
            return params;
          }
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  loadDifficultyParameters(): DifficultyParameters | null {
    const stored = AppStorage.get<string>(this.STORAGE_KEY_DIFFICULTY);
    if (stored && stored.length > 0) {
      try {
        const parsed: object = JSON.parse(stored);
        if (parsed !== null && typeof parsed === 'object') {
          return parsed as DifficultyParameters;
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  saveAutoOptimizeState(state: AutoOptimizeState): void {
    AppStorage.setOrCreate(this.STORAGE_KEY_AUTO, JSON.stringify(state));
  }

  loadAutoOptimizeState(): AutoOptimizeState | null {
    const stored = AppStorage.get<string>(this.STORAGE_KEY_AUTO);
    if (stored && stored.length > 0) {
      try {
        const parsed: object = JSON.parse(stored);
        if (parsed !== null && typeof parsed === 'object') {
          return parsed as AutoOptimizeState;
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  getTimestamp(): number {
    const stored = AppStorage.get<string>(this.STORAGE_KEY_TIMESTAMP);
    return stored ? parseInt(stored, 10) : 0;
  }

  clearParameters(): void {
    AppStorage.delete(this.STORAGE_KEY);
    AppStorage.delete(this.STORAGE_KEY_TIMESTAMP);
    AppStorage.delete(this.STORAGE_KEY_VERSION);
    AppStorage.delete(this.STORAGE_KEY_DIFFICULTY);
    AppStorage.delete(this.STORAGE_KEY_AUTO);
  }

  hasOptimizedParameters(): boolean {
    return this.loadParameters() !== null;
  }

  exportToJSON(): string {
    const data: ExportData = {
      globalParams: this.loadParameters(),
      difficultyParams: this.loadDifficultyParameters(),
      timestamp: this.getTimestamp(),
      autoState: this.loadAutoOptimizeState()
    };
    return JSON.stringify(data);
  }

  importFromJSON(json: string): boolean {
    try {
      const parsed: object = JSON.parse(json);
      if (parsed !== null && typeof parsed === 'object') {
        const data = parsed as Record<string, object>;
        if (data['globalParams'] !== undefined && Array.isArray(data['globalParams'])) {
          this.saveParameters(data['globalParams'] as number[]);
        }
        if (data['difficultyParams'] !== undefined && typeof data['difficultyParams'] === 'object') {
          this.saveDifficultyParameters(data['difficultyParams'] as DifficultyParameters);
        }
        if (data['autoState'] !== undefined && typeof data['autoState'] === 'object') {
          this.saveAutoOptimizeState(data['autoState'] as AutoOptimizeState);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
