export interface Configuration {
  app: {
    port: number;
    nodeEnv: string;
    corsOrigins: string[];
  };
  logging: {
    level: string;
    pretty: boolean;
  };
  database: {
    url: string;
  };
  openai: {
    apiKey?: string;
  };
}

export interface ConfigService {
  config: Configuration;
}
