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
    google: {
      clientId: string;
      clientSecret: string;
    };
  };
  aws: {
    accessKeyId?: string;
    secretAccessKey?: string;
    region: string;
    s3: {
      bucketName: string;
    };
    ses: {
      useMockService: boolean;
      region: string;
      fromAddress: string;
      configurationSetName?: string;
    };
  };
}

export interface ConfigService {
  config: Configuration;
}
