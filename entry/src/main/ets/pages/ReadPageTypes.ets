// =====================================================
// ReadPageTypes.ets - Type definitions for ReadPage
// =====================================================

class WordCountRange {
  minWords: number;
  maxWords: number;

  constructor(minWords: number, maxWords: number) {
    this.minWords = minWords;
    this.maxWords = maxWords;
  }
}


/**
 * Interface for objects with toJSON method
 */
interface ToJSONable {
  toJSON?: () => string;
}


/**
 * Interface for objects with clone method
 */
interface Cloneable {
  clone?: () => object;
}


/**
 * Raw FSRS state structure from router params
 */
interface RawFSRSState {
  difficulty?: number;
  stability?: number;
  retrievability?: number;
  reps?: number;
  lapses?: number;
}


/**
 * Raw history item structure
 */
interface RawHistoryItem {
  timestamp: number;
  rating: number;
  scheduledDays: number;
  stateBefore: string | RawFSRSState;
  stateAfter: string | RawFSRSState;
}


/**
 * Raw review history structure
 */
interface RawReviewHistory {
  items?: RawHistoryItem[];
}


/**
 * Common meaning structure
 */
interface CommonMeaning {
  pos: string;
  cn: string;
}


/**
 * Raw word definition structure
 */
interface RawWordDefinition {
  word?: string;
  phonetic?: string;
  pos?: string;
  contextMeaning?: string;
  commonMeanings?: Array<CommonMeaning>;
  source?: string;
}


export {
  WordCountRange,
  ToJSONable,
  Cloneable,
  RawFSRSState,
  RawHistoryItem,
  RawReviewHistory,
  CommonMeaning,
  RawWordDefinition
};
