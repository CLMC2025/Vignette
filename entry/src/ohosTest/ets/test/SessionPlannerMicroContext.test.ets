import { describe, it, expect } from '@ohos/hypium';

import { SessionPlanner, TaskType } from '../../../main/ets/manager/SessionPlanner';
import { WordItem, WordStatus } from '../../../main/ets/model/WordModel';

export default function sessionPlannerMicroContextTest() {
  describe('SessionPlanner planMicroContextSession', () => {
    it('should create story-only tasks for each word', 0, () => {
      const planner = SessionPlanner.getInstance();
      const words = [
        new WordItem(1, 'apple', WordStatus.NEW),
        new WordItem(2, 'banana', WordStatus.REVIEW)
      ];

      const tasks = planner.planMicroContextSession(words);
      expect(tasks.length).assertEqual(2);
      for (const task of tasks) {
        expect(task.type).assertEqual(TaskType.STORY);
      }
    });
  });
}
