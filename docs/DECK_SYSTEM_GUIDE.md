# Deck System + Study Manager Implementation Guide

## Overview

This document describes the complete deck system implementation for Vignette, including SRS (Spaced Repetition System) card management, study sessions, and FSRS v5 algorithm integration.

## Architecture

### Data Models

```
┌─────────────┐         ┌──────────────┐
│    Deck     │─────┬──>│   SRSCard    │
└─────────────┘     │   └──────────────┘
                    │   │ fsrsState    │
┌─────────────┐     │   │ queue        │
│ DeckConfig  │<────┘   │ left         │
└─────────────┘         │ dueDate      │
                        └──────────────┘
```

#### Deck Model

**Purpose**: Container for SRS cards with shared configuration.

**Fields**:
- `id`: Unique identifier
- `name`: Deck name
- `type`: BOOK or READING
- `sourceId`: Reference to word book or reading material
- `config`: DeckConfig object
- `stats`: Computed statistics (not stored)

**DeckConfig**:
```typescript
{
  newCardsPerDay: 20,           // Max new cards per day
  learningSteps: [15, 1440, 4320], // Minutes: 15min, 1 day, 3 days
  relearningSteps: [10, 1440],  // Minutes: 10min, 1 day
  reviewsPerDay: 200            // Max reviews per day
}
```

#### SRSCard Model

**Purpose**: Individual flashcard with FSRS state.

**Fields**:
- `id`, `deckId`, `wordId`
- `front`, `back`: Card content
- `context`, `contextType`: Optional context (STORY/SENTENCE/READING)
- `fsrsState`: FSRSState object (difficulty, stability, retrievability, reps, lapses)
- `dueDate`: Unix timestamp
- `interval`: Days until next review
- `reps`, `lapses`: Counters
- `queue`: Card state (0-3)
- `left`: Remaining learning steps
- `sourceType`, `sourceMaterialId`, `sourcePosition`: Source tracking

**Queue States** (Anki-compatible):
```typescript
enum CardQueue {
  NEW = 0,         // Never studied
  LEARNING = 1,    // Progressing through learning steps
  REVIEW = 2,      // Graduated to FSRS scheduling
  RELEARNING = 3   // Failed review, using relearning steps
}
```

### Database Schema

#### Decks Table
```sql
CREATE TABLE decks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'BOOK',
  source_id INTEGER,
  config TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
```

#### Cards Table
```sql
CREATE TABLE cards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  deck_id INTEGER NOT NULL,
  word_id INTEGER,
  front TEXT NOT NULL,
  back TEXT NOT NULL,
  context TEXT,
  context_type TEXT NOT NULL DEFAULT 'NONE',
  fsrs_state TEXT NOT NULL DEFAULT '{}',
  due_date INTEGER NOT NULL,
  interval REAL NOT NULL DEFAULT 0,
  reps INTEGER NOT NULL DEFAULT 0,
  lapses INTEGER NOT NULL DEFAULT 0,
  queue INTEGER NOT NULL DEFAULT 0,
  left INTEGER NOT NULL DEFAULT 0,
  source_type TEXT NOT NULL DEFAULT 'MANUAL',
  source_material_id INTEGER,
  source_position INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (deck_id) REFERENCES decks(id) ON DELETE CASCADE
)
```

**Indices** (for performance):
- `idx_cards_deck` on `deck_id`
- `idx_cards_queue` on `queue`
- `idx_cards_due` on `due_date`
- `idx_cards_deck_queue_due` on `(deck_id, queue, due_date)` ← **Composite for fast session loading**

---

## Core Components

### 1. DeckManager

**Purpose**: High-level deck management.

**Singleton Pattern**:
```typescript
const deckManager = DeckManager.getInstance();
```

**Key Methods**:

#### createBookDeck(bookId, name, config?)
Creates a deck from a word book.

**Flow**:
1. Create deck record in database
2. Load all words from specified book
3. Convert each WordItem → SRSCard
4. Preserve existing FSRS state if word was studied before
5. Insert all cards in batch

**Example**:
```typescript
const deck = await deckManager.createBookDeck('cet4', 'CET-4 Vocabulary');
// Creates deck with ~4500 cards from CET-4 word book
```

#### createReadingDeck(materialId, title, config?)
Creates an empty deck for reading material.

**Example**:
```typescript
const deck = await deckManager.createReadingDeck(123, 'Harry Potter Chapter 1');
// Creates empty deck, cards added during reading
```

#### getDecksWithStats()
Returns all decks with computed statistics.

**Output**:
```typescript
[
  {
    id: 1,
    name: 'CET-4 Vocabulary',
    type: 'BOOK',
    stats: {
      newCount: 20,
      learningCount: 15,
      reviewCount: 50,
      relearnCount: 5,
      totalCount: 90
    }
  },
  // ...
]
```

#### addCardToReadingDeck(deckId, front, back, context?, position?)
Adds a card to a reading deck.

**Example**:
```typescript
await deckManager.addCardToReadingDeck(
  deckId,
  'magnificent',
  'extremely beautiful, elaborate, or impressive',
  'The palace was magnificent in the moonlight.',
  142
);
```

---

### 2. StudyManager

**Purpose**: Manages study sessions for a deck.

**Lifecycle**:
```typescript
const studyManager = new StudyManager(deckId);
await studyManager.initialize();

while (studyManager.hasMore()) {
  const card = studyManager.getCurrentCard();
  // Show card to user...
  
  const rating = getUserRating(); // AGAIN/HARD/GOOD/EASY
  await studyManager.processRating(rating);
}

const stats = studyManager.getSessionStats();
```

**Key Methods**:

#### initialize()
Loads deck and due cards with priority ordering.

**Priority Order**:
1. LEARNING cards (most urgent)
2. RELEARNING cards (failed reviews)
3. REVIEW cards (due today)
4. NEW cards (up to `newCardsPerDay` limit)

**Example**:
```typescript
await studyManager.initialize();
// Loads: 10 learning + 5 relearning + 30 review + 20 new = 65 cards
```

#### processRating(rating)
Processes user's rating and updates card state.

**Queue-Specific Logic**:

**NEW Cards**:
```typescript
AGAIN → Stay NEW, reschedule for 1 minute
HARD  → Enter LEARNING, schedule for step 0 (15 minutes)
GOOD  → Enter LEARNING, schedule for step 0 (15 minutes)
EASY  → Graduate to REVIEW, use FSRS interval (~4 days)
```

**LEARNING Cards**:
```typescript
AGAIN → Reset to step 0 (15 minutes), increment lapses
HARD  → Repeat current step × 1.2
GOOD  → Move to next step OR graduate if last step
EASY  → Graduate to REVIEW immediately
```

**REVIEW Cards** (use FSRS v5):
```typescript
AGAIN → Move to RELEARNING, reset to step 0 (10 minutes)
HARD  → FSRS calculates interval (typically shorter)
GOOD  → FSRS calculates interval (typical spacing)
EASY  → FSRS calculates interval (longer spacing)
```

**RELEARNING Cards**:
```typescript
AGAIN → Reset to step 0 (10 minutes)
HARD  → Repeat current step × 1.2
GOOD  → Move to next step OR graduate to REVIEW
EASY  → Graduate to REVIEW immediately
```

**Example**:
```typescript
const card = studyManager.getCurrentCard();
// front: "magnificent"
// queue: LEARNING, left: 2 (needs 2 more steps)

await studyManager.processRating(Rating.GOOD);
// → left: 1, dueDate: now + 1440 minutes (1 day)

// Next day...
await studyManager.processRating(Rating.GOOD);
// → left: 0, queue: REVIEW, dueDate: now + FSRS interval (~3 days)
```

#### previewIntervals(card?)
Shows intervals for all possible ratings.

**Example**:
```typescript
const intervals = studyManager.previewIntervals();
// Map {
//   1 (AGAIN) → 0.007 days (10 minutes),
//   2 (HARD)  → 1.5 days,
//   3 (GOOD)  → 3.2 days,
//   4 (EASY)  → 8.5 days
// }
```

#### undoLastReview()
Reverts the last review.

**Example**:
```typescript
await studyManager.processRating(Rating.AGAIN); // Oops!
const success = await studyManager.undoLastReview();
// success: true, card state restored
```

---

## Learning Steps System

### Default Learning Steps
```typescript
learningSteps: [15, 1440, 4320]
// Step 0: 15 minutes
// Step 1: 1 day (1440 minutes)
// Step 2: 3 days (4320 minutes)
// Then graduate to REVIEW queue
```

### Relearning Steps (for failed reviews)
```typescript
relearningSteps: [10, 1440]
// Step 0: 10 minutes
// Step 1: 1 day
// Then graduate back to REVIEW queue
```

### Step Progression Example

**Scenario**: Learning a new word

1. **First encounter** (NEW)
   - User rates GOOD
   - Queue: NEW → LEARNING
   - left: 2 (needs 2 more steps)
   - Due: now + 15 minutes

2. **After 15 minutes** (LEARNING, left=2)
   - User rates GOOD
   - left: 2 → 1
   - Due: now + 1 day

3. **After 1 day** (LEARNING, left=1)
   - User rates GOOD
   - left: 1 → 0
   - Queue: LEARNING → REVIEW
   - Due: FSRS calculates ~3 days

4. **After 3 days** (REVIEW)
   - User rates GOOD
   - FSRS calculates next interval: ~8 days

5. **After 8 days** (REVIEW)
   - User rates AGAIN
   - Queue: REVIEW → RELEARNING
   - left: 1 (relearning steps)
   - Due: now + 10 minutes

---

## FSRS v5 Integration

### When FSRS is Used

**ONLY** for cards in REVIEW queue (graduated cards).

**NOT** used for:
- NEW cards (use fixed initial intervals)
- LEARNING cards (use learning steps)
- RELEARNING cards (use relearning steps)

### FSRS Application

```typescript
// In StudyManager.applyFSRS()
const elapsedDays = calculateElapsedDays(card);
const result = fsrsAlgorithm.review(
  card.fsrsState,
  rating,
  elapsedDays
);

card.fsrsState = result.newState;
card.dueDate = result.nextReviewMs;
card.interval = result.intervalDays;
```

### Interval Preview

```typescript
// Show user what will happen for each rating
const intervals = fsrsAlgorithm.previewIntervals(
  card.fsrsState,
  elapsedDays
);

// Display:
// AGAIN: 2 hours
// HARD:  1.5 days
// GOOD:  3.2 days
// EASY:  8.5 days
```

---

## Usage Examples

### Create and Study a Deck

```typescript
import { DeckManager } from './manager/DeckManager';
import { StudyManager, SessionStats } from './manager/StudyManager';
import { Rating } from './model/WordModel';

// 1. Create deck from word book
const deckManager = DeckManager.getInstance();
const deck = await deckManager.createBookDeck('cet6', 'CET-6 Words');

// 2. Check deck statistics
const decks = await deckManager.getDecksWithStats();
console.log(decks[0].stats);
// { newCount: 20, learningCount: 0, reviewCount: 0, relearnCount: 0 }

// 3. Start study session
const studyManager = new StudyManager(deck.id);
await studyManager.initialize();

// 4. Study loop
while (studyManager.hasMore()) {
  const card = studyManager.getCurrentCard();
  
  // Show card front
  console.log(`Q: ${card.front}`);
  
  // Show interval preview
  const intervals = studyManager.previewIntervals();
  console.log('Intervals:', intervals);
  
  // Wait for user input...
  const rating = Rating.GOOD; // From UI
  
  // Process rating
  await studyManager.processRating(rating);
  
  // Show stats
  const stats = studyManager.getSessionStats();
  console.log(`Progress: ${stats.reviewedCount} / ${stats.totalCount}`);
}

console.log('Session complete!');
```

### Add Cards from Reading

```typescript
// 1. Create reading deck
const deck = await deckManager.createReadingDeck(
  456,
  'The Great Gatsby - Chapter 1'
);

// 2. Add cards during reading
await deckManager.addCardToReadingDeck(
  deck.id,
  'elusive',
  'difficult to find, catch, or achieve',
  'The meaning of the green light remained elusive.',
  89
);

await deckManager.addCardToReadingDeck(
  deck.id,
  'contemptuous',
  'showing contempt; scornful',
  'He gave her a contemptuous look.',
  142
);

// 3. Study the reading cards
const studyManager = new StudyManager(deck.id);
await studyManager.initialize();
// ... study loop
```

---

## Testing

### Manual Testing

**Test Scenario 1**: NEW → LEARNING → REVIEW
```typescript
1. Create deck with test word
2. Rate GOOD → should enter LEARNING with 15min interval
3. After 15min, rate GOOD → should move to next step (1 day)
4. After 1 day, rate GOOD → should graduate to REVIEW
5. Verify FSRS interval is used
```

**Test Scenario 2**: Review Failure → Relearning
```typescript
1. Start with card in REVIEW queue
2. Rate AGAIN → should enter RELEARNING
3. Verify relearning steps are used (10min, 1 day)
4. After completing steps, should return to REVIEW
```

**Test Scenario 3**: Undo
```typescript
1. Review a card with rating AGAIN
2. Call undoLastReview()
3. Verify card state is restored
4. Verify can review again
```

### Unit Test Structure

```typescript
describe('StudyManager', () => {
  it('should initialize with correct card priority', async () => {
    // Test card loading order
  });
  
  it('should process NEW card with GOOD rating', async () => {
    // Verify enters LEARNING queue
    // Verify correct interval
  });
  
  it('should graduate card after completing learning steps', async () => {
    // Verify queue transition LEARNING → REVIEW
  });
  
  it('should apply FSRS for REVIEW cards', async () => {
    // Verify FSRS algorithm is called
    // Verify interval matches FSRS output
  });
  
  it('should move failed REVIEW to RELEARNING', async () => {
    // Verify queue transition REVIEW → RELEARNING
    // Verify relearning steps are used
  });
});
```

---

## Performance Considerations

### Database Queries

**Optimized**:
- Composite index `(deck_id, queue, due_date)` enables fast session loading
- Separate counts avoid loading full card data
- Batch operations for deck creation

**Query Examples**:
```sql
-- Load due cards for session (uses composite index)
SELECT * FROM cards 
WHERE deck_id = ? AND due_date <= ? 
ORDER BY queue, due_date 
LIMIT 100;

-- Count due cards by queue (uses composite index)
SELECT COUNT(*) FROM cards 
WHERE deck_id = ? AND queue = ? AND due_date <= ?;
```

### Memory Management

- Cards loaded on-demand per session
- SessionStats computed once at initialization
- Review history kept minimal (last N reviews only)

### Caching

- FSRS interval cache (200 entries max)
- Deck config cached in Deck object
- Statistics computed on-demand, not stored

---

## Future Enhancements

### Phase 1 (Current)
- ✅ Core deck system
- ✅ Study session management
- ✅ FSRS v5 integration
- ✅ Learning steps

### Phase 2 (Future)
- [ ] Deck templates (pre-configured settings)
- [ ] Card templates (custom front/back formats)
- [ ] Sub-decks (hierarchical organization)
- [ ] Filtered decks (dynamic queries)
- [ ] Custom learning steps per deck
- [ ] Sibling card burial (don't show related cards together)

### Phase 3 (Advanced)
- [ ] Deck sharing (export/import)
- [ ] Collaborative decks
- [ ] Statistics dashboard
- [ ] Retention curves
- [ ] Optimal scheduling (maximize retention, minimize reviews)

---

## Appendix: Queue State Machine

```
                ┌─────────┐
                │   NEW   │
                └────┬────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
      AGAIN        GOOD/HARD     EASY
        │            │            │
    (1 min)          v            v
                ┌─────────┐   ┌─────────┐
                │LEARNING │   │ REVIEW  │
                └────┬────┘   └────┬────┘
                     │             │
        ┌────────────┼────────┐    │
        │            │        │    │
      AGAIN        HARD      GOOD  │
        │            │        │    │
   (reset step 0) (repeat)   │    │
                             │    │
                        (advance step)
                             │    │
                             v    │
                         (graduate)
                             │    │
                             v    v
                        ┌─────────┐
                        │ REVIEW  │◄───┐
                        └────┬────┘    │
                             │         │
                           AGAIN    GOOD/HARD/EASY
                             │         │
                             v       (FSRS)
                     ┌───────────┐    │
                     │RELEARNING │    │
                     └─────┬─────┘    │
                           │          │
                        (steps)       │
                           │          │
                           └──────────┘
```

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-11  
**Author**: Vignette Development Team
