import { AsyncLocalStorage } from 'async_hooks';

export interface RequestContext {
  correlationId: string;
}

export class RequestContextService {
  private static asyncLocalStorage = new AsyncLocalStorage<RequestContext>();

  /**
   * Run a callback within a request context
   */
  static run<T>(context: RequestContext, callback: () => T): T {
    return this.asyncLocalStorage.run(context, callback);
  }

  /**
   * Get the current request context
   */
  static getContext(): RequestContext | undefined {
    return this.asyncLocalStorage.getStore();
  }

  /**
   * Get the current correlation ID
   */
  static getCorrelationId(): string | undefined {
    return this.getContext()?.correlationId;
  }

  /**
   * Set correlation ID in current context (if context exists)
   */
  static setCorrelationId(correlationId: string): void {
    const context = this.getContext();
    if (context) {
      context.correlationId = correlationId;
    }
  }
}
