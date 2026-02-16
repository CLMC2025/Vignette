export interface HeatmapDailyStats {
  dateMs: number;
  knownCount: number;
  fuzzyCount: number;
  forgottenCount: number;
  newCount: number;
  reviewCount: number;
  durationMs: number;
  totalReviews: number;
}
