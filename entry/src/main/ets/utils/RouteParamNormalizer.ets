// =====================================================
// RouteParamNormalizer.ets
//
// Why:
// Router param passing in HarmonyOS/ArkTS can lose class prototypes.
// For example, WordItem/FSRSState/ReviewHistory/WordDefinition may become
// plain objects after navigation, causing runtime errors like:
//   "xxx.clone is not a function" or "undefined is not a function".
//
// This module converts router params back into real model instances.
// =====================================================

import {
  WordItem,
  WordStatus,
  FSRSState,
  ReviewHistory,
  WordDefinition,
  QueueItem
} from '../model/WordModel';

interface CommonMeaning {
  pos: string;
  cn: string;
}

interface RawWordDefinition {
  word?: string;
  phonetic?: string;
  pos?: string;
  contextMeaning?: string;
  commonMeanings?: Array<CommonMeaning>;
  source?: string;
}

interface ToJSONable {
  toJSON?: () => string;
}

interface Cloneable {
  clone?: () => object;
}

export interface RawQueueItem {
  word: RawWordItem | WordItem | string | object;
  priority: number | string;
}

export function normalizeQueueFromRouterParams(rawQueue: Array<RawQueueItem>): QueueItem[] {
  const result: QueueItem[] = [];

  for (const item of rawQueue) {
    const wordRaw = item.word;
    const priorityRaw = item.priority;

    const word = normalizeWordItem(wordRaw);
    const priority = typeof priorityRaw === 'number' ? priorityRaw : Number(priorityRaw ?? 1);

    if (word.word.trim().length === 0) {
      continue;
    }

    result.push(new QueueItem(word, isFinite(priority) ? priority : 1));
  }

  return result;
}

export interface RawWordItem {
  id?: number;
  word?: string;
  status?: string;
  fsrsState?: string | object;
  history?: string | object;
  definition?: string | object;
  dueDate?: number;
  createdAt?: number;
  updatedAt?: number;
  bookId?: string;
  tags?: string[];
  lapseCount?: number;
  leechLevel?: number;
  errorTags?: string[];
  suspendUntil?: number;
}

export function normalizeWordItem(raw: RawWordItem | WordItem | string | object): WordItem {
  if (raw instanceof WordItem) {
    return raw;
  }

  // If prototype is preserved, WordItem should have clone().
  if (raw && typeof raw === 'object') {
    const rawObj = raw as Cloneable;
    const cloneFn = rawObj.clone;
    if (typeof cloneFn === 'function') {
      return raw as WordItem;
    }
  }

  const obj = raw as RawWordItem || {} as RawWordItem;

  const id = typeof obj.id === 'number' ? obj.id : Number(obj.id ?? 0);
  const wordStr = String(obj.word ?? '');
  const status = normalizeWordStatus(obj.status ?? '');
  const fsrsState = normalizeFsrsState(obj.fsrsState);
  const history = normalizeReviewHistory(obj.history);
  const definition = normalizeDefinition(wordStr, obj.definition);

  const dueDate = typeof obj.dueDate === 'number' ? obj.dueDate : Number(obj.dueDate ?? Date.now());
  const createdAt = typeof obj.createdAt === 'number' ? obj.createdAt : Number(obj.createdAt ?? Date.now());
  const updatedAt = typeof obj.updatedAt === 'number' ? obj.updatedAt : Number(obj.updatedAt ?? Date.now());
  const bookId = String(obj.bookId ?? '');

  const tagsRaw = obj.tags;
  const tags: string[] = Array.isArray(tagsRaw) ? tagsRaw.map((v: string): string => String(v)) : [];

  const lapseCount = typeof obj.lapseCount === 'number' ? obj.lapseCount : Number(obj.lapseCount ?? 0);
  const leechLevel = typeof obj.leechLevel === 'number' ? obj.leechLevel : Number(obj.leechLevel ?? 0);

  const errorTagsRaw = obj.errorTags;
  const errorTags: string[] = Array.isArray(errorTagsRaw) ? errorTagsRaw.map((v: string): string => String(v)) : [];

  const suspendUntil = typeof obj.suspendUntil === 'number' ? obj.suspendUntil : Number(obj.suspendUntil ?? 0);

  return new WordItem(
    isFinite(id) ? id : 0,
    wordStr,
    status,
    fsrsState,
    history,
    definition,
    isFinite(dueDate) ? dueDate : Date.now(),
    isFinite(createdAt) ? createdAt : Date.now(),
    isFinite(updatedAt) ? updatedAt : Date.now(),
    bookId,
    tags,
    isFinite(lapseCount) ? lapseCount : 0,
    isFinite(leechLevel) ? leechLevel : 0,
    errorTags,
    isFinite(suspendUntil) ? suspendUntil : 0
  );
}

function normalizeWordStatus(raw?: string | number): WordStatus {
  const s = String(raw ?? '');
  if (s === WordStatus.NEW || s === WordStatus.LEARNING || s === WordStatus.REVIEW || s === WordStatus.RELEARNING) {
    return s as WordStatus;
  }
  if (s === 'MASTERED' || s === 'SUSPENDED') {
    return WordStatus.REVIEW;
  }
  return WordStatus.NEW;
}

interface RawFSRSState {
  difficulty?: number;
  stability?: number;
  retrievability?: number;
  reps?: number;
  lapses?: number;
}

function normalizeFsrsState(raw?: FSRSState | string | RawFSRSState | ToJSONable): FSRSState {
  if (raw instanceof FSRSState) {
    return raw;
  }

  if (typeof raw === 'string') {
    return FSRSState.fromJSON(raw);
  }

  if (raw && typeof raw === 'object') {
    const maybeObj = raw as ToJSONable;
    const toJson = maybeObj.toJSON;
    if (typeof toJson === 'function') {
      const json = toJson();
      return FSRSState.fromJSON(json);
    }
    return FSRSState.fromJSON(JSON.stringify(maybeObj));
  }

  return new FSRSState();
}

interface RawReviewItem {
  timestamp: number;
  rating: number;
  scheduledDays: number;
  stateBefore: string | object;
  stateAfter: string | object;
}

interface RawReviewHistory extends ToJSONable {
  items?: RawReviewItem[];
}

function normalizeReviewHistory(raw?: ReviewHistory | string | RawReviewHistory | RawFSRSState | ToJSONable): ReviewHistory {
  if (raw instanceof ReviewHistory) {
    return raw;
  }

  if (typeof raw === 'string') {
    return ReviewHistory.fromJSON(raw);
  }

  if (raw && typeof raw === 'object') {
    const maybeObj = raw as RawReviewHistory;
    const toJson = maybeObj.toJSON;
    if (typeof toJson === 'function') {
      const json = toJson();
      return ReviewHistory.fromJSON(json);
    }
    
    const itemsRaw = maybeObj.items;
    const normalized: RawReviewItem[] = [];

    if (Array.isArray(itemsRaw)) {
      for (const it of itemsRaw) {
        const o = it || ({} as RawReviewItem);
        const ts = typeof o.timestamp === 'number' ? o.timestamp : Number(o.timestamp ?? 0);
        const rating = typeof o.rating === 'number' ? o.rating : Number(o.rating ?? 0);
        const sd = typeof o.scheduledDays === 'number' ? o.scheduledDays : Number(o.scheduledDays ?? 0);

        const sb = o.stateBefore;
        const sa = o.stateAfter;
        const sbStr = typeof sb === 'string' ? sb : JSON.stringify(sb || {});
        const saStr = typeof sa === 'string' ? sa : JSON.stringify(sa || {});

        normalized.push({
          timestamp: isFinite(ts) ? ts : 0,
          rating: isFinite(rating) ? rating : 0,
          scheduledDays: isFinite(sd) ? sd : 0,
          stateBefore: sbStr,
          stateAfter: saStr
        });
      }
    }

    return ReviewHistory.fromJSON(JSON.stringify(normalized));
  }

  return new ReviewHistory();
}



function normalizeDefinition(wordFallback: string, raw?: WordDefinition | string | RawWordDefinition | CommonMeaning | ToJSONable): WordDefinition {
  if (raw instanceof WordDefinition) {
    return raw;
  }

  let def: WordDefinition = new WordDefinition();

  if (typeof raw === 'string') {
    def = WordDefinition.fromJSON(raw);
  } else if (raw && typeof raw === 'object') {
    const maybeToJson = raw as ToJSONable;
    const toJson = maybeToJson.toJSON;
    if (typeof toJson === 'function') {
      const json = toJson();
      def = WordDefinition.fromJSON(json);
    } else {
      const rawDef = raw as RawWordDefinition;
      def = WordDefinition.fromJSON(JSON.stringify(rawDef));
    }
  }

  if (def.word.trim().length === 0 && wordFallback.trim().length > 0) {
    def.word = wordFallback;
  }

  return def;
}
