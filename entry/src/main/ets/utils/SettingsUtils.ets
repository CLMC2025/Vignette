// =====================================================
// SettingsUtils.ets
// 
// Utility functions for handling app settings
// =====================================================

import { SchedulerMode } from '../evolve/EvolveScheduler';

/**
 * Parse scheduler mode from string value
 * @param value String representation of scheduler mode
 * @returns SchedulerMode enum value
 */
export function parseSchedulerMode(value: string): SchedulerMode {
  if (value === SchedulerMode.SSPMMC) return SchedulerMode.SSPMMC;
  if (value === SchedulerMode.HYBRID) return SchedulerMode.HYBRID;
  return SchedulerMode.FSRS;
}
