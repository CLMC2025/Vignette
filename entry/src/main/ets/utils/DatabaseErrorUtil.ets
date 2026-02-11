export function isUniqueConstraintErrorMessage(errorStr: string): boolean {
  const lower = errorStr.toLowerCase();
  if (lower.includes('unique constraint failed')) {
    return true;
  }
  if (lower.includes('sqlite_constraint_unique')) {
    return true;
  }
  if (lower.includes('sqlite_constraint_primarykey')) {
    return true;
  }
  if (lower.includes('abort due to constraint violation')) {
    return true;
  }
  return false;
}

