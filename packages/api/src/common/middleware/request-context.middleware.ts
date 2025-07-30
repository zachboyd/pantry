import { Request, Response, NextFunction } from 'express';
import { randomUUID } from 'crypto';
import { RequestContextService } from '../context/request-context.service.js';

/**
 * Express middleware that sets up AsyncLocalStorage context for each request
 */
export function requestContextMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  // Extract or generate correlation ID
  const correlationId =
    (req.headers['x-correlation-id'] as string) ||
    (req.headers['x-request-id'] as string) ||
    randomUUID();

  // Add to response headers for client debugging
  res.setHeader('x-correlation-id', correlationId);

  // Store correlation ID on request for compatibility
  req.correlationId = correlationId;

  // Run the rest of the request within AsyncLocalStorage context
  RequestContextService.run({ correlationId }, () => {
    next();
  });
}
