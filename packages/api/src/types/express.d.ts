// Express type extensions for custom properties
declare global {
  namespace Express {
    interface Request {
      correlationId?: string;
    }
  }
}

export {};
