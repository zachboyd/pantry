import { Module } from '@nestjs/common';
import { EmailServiceImpl } from './email.service.js';
import { TOKENS } from '../../common/tokens.js';
import { AppConfigModule } from '../config/config.module.js';
import type { EmailConfig } from './email.types.js';
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
      useClass: EmailServiceImpl,
    },
  ],
  exports: [TOKENS.EMAIL.SERVICE],
})
export class EmailModule {}
