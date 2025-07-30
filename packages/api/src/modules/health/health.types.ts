export interface HealthResponse {
  status: string;
  timestamp: string;
}

/**
 * Interface for Health service operations
 */
export interface HealthService {
  /**
   * Get the current health status of the API
   * @returns Health response with status and timestamp
   */
  getHealth(): HealthResponse;
}
