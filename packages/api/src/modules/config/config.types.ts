export interface Configuration {
  app: {
    port: number;
    nodeEnv: string;
    url: string;
    corsOrigins: string[];
  };
  logging: {
    level: string;
    pretty: boolean;
  };
  database: {
    url: string;
  };
  redis: {
    url: string;
  };
  openai: {
    apiKey?: string;
  };
  betterAuth: {
    secret: string;
  };
  aws: {
    accessKeyId?: string;
    secretAccessKey?: string;
    region: string;
    s3: {
      bucketName: string;
    };
    ses: {
      region: string;
      fromAddress: string;
      configurationSetName?: string;
    };
  };
}

export interface ConfigService {
  config: Configuration;
}
