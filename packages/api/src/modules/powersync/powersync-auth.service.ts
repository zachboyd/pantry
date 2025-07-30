import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import * as jose from 'jose';
import type {
  JwksResponse,
  PowerSyncAuthService,
  PowerSyncJwtConfig,
  PowerSyncJwtPayload,
  UserRecord,
} from './powersync.types.js';

@Injectable()
export class PowerSyncAuthServiceImpl implements PowerSyncAuthService {
  private readonly logger = new Logger(PowerSyncAuthServiceImpl.name);
  private readonly config: PowerSyncJwtConfig;
  private privateKey: CryptoKey;
  private publicJwk: jose.JWK;
  private keyId: string;

  constructor() {
    this.config = {
      expiresIn: process.env.POWERSYNC_JWT_EXPIRES_IN || '5m',
      issuer: process.env.POWERSYNC_JWT_ISSUER || 'pantry-api',
      audience: ['powersync-dev', 'pantry'],
    };
    this.initializeKeys();
  }

  /**
   * Get the expiration duration in seconds
   */
  getExpirationSeconds(): number {
    const expiresIn = this.config.expiresIn;

    // Parse duration string (e.g., '5m', '1h', '30s')
    const match = expiresIn.match(/^(\d+)([smhd])$/);
    if (!match) {
      throw new Error(`Invalid expiration format: ${expiresIn}`);
    }

    const value = parseInt(match[1], 10);
    const unit = match[2];

    switch (unit) {
      case 's':
        return value;
      case 'm':
        return value * 60;
      case 'h':
        return value * 60 * 60;
      case 'd':
        return value * 24 * 60 * 60;
      default:
        throw new Error(`Unsupported time unit: ${unit}`);
    }
  }

  private async initializeKeys() {
    try {
      const privateKeyBase64 = process.env.POWERSYNC_PRIVATE_KEY;
      const publicKeyBase64 = process.env.POWERSYNC_PUBLIC_KEY;

      if (!privateKeyBase64 || !publicKeyBase64) {
        throw new Error(
          'POWERSYNC_PRIVATE_KEY and POWERSYNC_PUBLIC_KEY environment variables are required. Run "npm run env:generate" to generate them.',
        );
      }

      // Import keys from base64-encoded strings
      const privateKeyPem = Buffer.from(privateKeyBase64, 'base64').toString(
        'utf-8',
      );
      const publicKeyPem = Buffer.from(publicKeyBase64, 'base64').toString(
        'utf-8',
      );

      this.privateKey = await jose.importPKCS8(privateKeyPem, 'RS256');
      const publicKey = await jose.importSPKI(publicKeyPem, 'RS256');

      // Export public key as JWK for JWKS endpoint
      this.publicJwk = await jose.exportJWK(publicKey);
      this.publicJwk.use = 'sig';
      this.publicJwk.alg = 'RS256';

      // Generate deterministic key ID using JWK thumbprint
      this.keyId = await jose.calculateJwkThumbprint(this.publicJwk, 'sha256');
      this.publicJwk.kid = this.keyId;

      this.logger.log(
        'PowerSync JWT keys loaded successfully from environment variables',
      );
    } catch (error) {
      this.logger.error(error, 'Failed to initialize JWT keys');
      throw error;
    }
  }

  async generateToken(user: UserRecord): Promise<string> {
    const payload = {
      user_id: user.id,
      email: user.email || undefined,
    };

    try {
      const jwt = await new jose.SignJWT(payload)
        .setProtectedHeader({
          alg: 'RS256',
          kid: this.keyId,
        })
        .setIssuedAt()
        .setIssuer(this.config.issuer)
        .setAudience(this.config.audience)
        .setSubject(user.id)
        .setExpirationTime(this.config.expiresIn)
        .sign(this.privateKey);

      this.logger.debug(`Generated PowerSync JWT for user ${user.id}`);
      return jwt;
    } catch (error) {
      this.logger.error(error, 'Failed to generate PowerSync JWT');
      throw new UnauthorizedException(
        'Failed to generate authentication token',
      );
    }
  }

  async verifyToken(token: string): Promise<PowerSyncJwtPayload> {
    try {
      const publicKey = await jose.importJWK(this.publicJwk);

      const { payload } = await jose.jwtVerify(token, publicKey, {
        issuer: this.config.issuer,
        audience: this.config.audience,
      });

      // The payload contains our custom claims
      return {
        sub: payload.sub!,
        aud: payload.aud as string[],
        iss: payload.iss!,
        iat: payload.iat!,
        exp: payload.exp!,
        user_id: (payload as any).user_id,
        email: (payload as any).email,
      };
    } catch (error) {
      this.logger.warn(error, 'PowerSync JWT verification failed');
      throw new UnauthorizedException('Invalid authentication token');
    }
  }

  async getJwks(): Promise<JwksResponse> {
    try {
      return {
        keys: [this.publicJwk],
      };
    } catch (error) {
      this.logger.error(error, 'Failed to generate JWKS');
      throw error;
    }
  }
}
