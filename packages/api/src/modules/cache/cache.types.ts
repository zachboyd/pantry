/**
 * Cache types for the CacheHelper
 */
export type CacheType = 'permissions' | 'users' | 'households';

/**
 * Cache statistics interface (for future monitoring if needed)
 */
export interface CacheStats {
  hits: number;
  misses: number;
  hitRate: number;
  size: number;
  memoryUsage?: number;
}
