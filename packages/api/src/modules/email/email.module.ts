import { Module } from '@nestjs/common';
import { EmailServiceImpl } from './email.service.js';
import { MockEmailService } from './mock-email.service.js';
import { TOKENS } from '../../common/tokens.js';
import { AppConfigModule } from '../config/config.module.js';
import type { EmailConfig, EmailService } from './email.types.js';
import type { ConfigService } from '../config/config.types.js';

@Module({
  imports: [AppConfigModule],
  providers: [
    {
      provide: TOKENS.EMAIL.CONFIG,
      useFactory: (configService: ConfigService): EmailConfig => {
        const { aws } = configService.config;
        return {
          region: aws.ses.region,
          fromAddress: aws.ses.fromAddress,
          configurationSetName: aws.ses.configurationSetName,
          credentials: aws.accessKeyId
            ? {
                accessKeyId: aws.accessKeyId,
                secretAccessKey: aws.secretAccessKey!,
              }
            : undefined,
        };
      },
      inject: [TOKENS.CONFIG.SERVICE],
    },
    {
      provide: TOKENS.EMAIL.SERVICE,
      useFactory: (
        configService: ConfigService,
        emailConfig: EmailConfig,
      ): EmailService => {
        const { aws } = configService.config;
        if (aws.ses.useMockService) {
          return new MockEmailService();
        }
        return new EmailServiceImpl(emailConfig);
      },
      inject: [TOKENS.CONFIG.SERVICE, TOKENS.EMAIL.CONFIG],
    },
  ],
  exports: [TOKENS.EMAIL.SERVICE],
})
export class EmailModule {}
