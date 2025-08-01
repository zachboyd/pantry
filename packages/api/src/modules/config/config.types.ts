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
  redis: {
    url: string;
  };
  openai: {
    apiKey?: string;
  };
  aws: {
    accessKeyId?: string;
    secretAccessKey?: string;
    region: string;
    s3BucketName: string;
  };
}

export interface ConfigService {
  config: Configuration;
}
