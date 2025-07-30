#!/usr/bin/env tsx

import { randomBytes } from 'crypto';
import { existsSync, readFileSync, writeFileSync } from 'fs';
import * as jose from 'jose';
import { dirname, join } from 'path';
import { createInterface } from 'readline';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const apiDir = join(__dirname, '..');
const envExamplePath = join(apiDir, '.env.example');

// Get environment from command line args or default to 'local'
const cliEnvironment = process.argv[2] || null;

interface EnvVar {
  key: string;
  description: string;
  default: string | (() => string);
  isSecret?: boolean;
  required: boolean;
  isOptional?: boolean;
}

// Parse .env.example file to extract variables dynamically
function parseEnvExample(): EnvVar[] {
  const content = readFileSync(envExamplePath, 'utf-8');
  const envVars: EnvVar[] = [];
  const lines = content.split('\n');
  let currentDescription = '';
  let isOptionalSection = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();

    // Track if we're in an optional section
    if (line.includes('Optional:') || line.includes('optional')) {
      isOptionalSection = true;
      continue;
    }

    // Extract descriptions from comments
    if (line.startsWith('#') && !line.includes('Configuration')) {
      const desc = line.replace(/^#\s*/, '').trim();
      if (desc && !desc.includes('=')) {
        currentDescription = desc;
      }
      continue;
    }

    // Parse environment variable lines
    if (line.includes('=') && !line.startsWith('#')) {
      const [key, ...valueParts] = line.split('=');
      const value = valueParts.join('=').trim();

      if (key) {
        const cleanKey = key.trim();

        // Determine if it's a secret (should be auto-generated if not provided)
        const isSecret =
          cleanKey.includes('SECRET') ||
          (cleanKey.includes('KEY') && !cleanKey.includes('API_KEY')) ||
          cleanKey.includes('PASSWORD') ||
          (cleanKey.includes('JWT') && cleanKey.includes('SECRET')) ||
          (cleanKey.includes('TOKEN') && !cleanKey.includes('EXPIRES'));

        // Use description or generate one from key name
        const description =
          currentDescription ||
          cleanKey
            .toLowerCase()
            .replace(/_/g, ' ')
            .replace(/\b\w/g, (l) => l.toUpperCase());

        envVars.push({
          key: cleanKey,
          description,
          default: value || '',
          isSecret,
          required: !isOptionalSection && !line.startsWith('#'),
          isOptional: isOptionalSection,
        });

        // Reset description after use
        currentDescription = '';
      }
    }
  }

  console.log(`📄 Parsed ${envVars.length} variables from .env.example`);
  return envVars;
}

function generateDefault(defaultValue: string | (() => string)): string {
  return typeof defaultValue === 'function' ? defaultValue() : defaultValue;
}

// Cache for generated PowerSync keys to ensure they're generated as a pair
let powerSyncKeys: { privateKey: string; publicKey: string } | null = null;

async function generatePowerSyncKeys(): Promise<{
  privateKey: string;
  publicKey: string;
}> {
  if (powerSyncKeys) {
    return powerSyncKeys;
  }

  console.log('   🔑 Generating RSA key pair for PowerSync...');

  // Generate RSA key pair using jose (same as PowerSync service)
  const { publicKey, privateKey } = await jose.generateKeyPair('RS256', {
    modulusLength: 2048,
    extractable: true,
  });

  // Export keys as base64-encoded strings
  const privateKeyBase64 = Buffer.from(
    await jose.exportPKCS8(privateKey),
  ).toString('base64');

  const publicKeyBase64 = Buffer.from(
    await jose.exportSPKI(publicKey),
  ).toString('base64');

  powerSyncKeys = {
    privateKey: privateKeyBase64,
    publicKey: publicKeyBase64,
  };

  return powerSyncKeys;
}

function createReadlineInterface() {
  return createInterface({
    input: process.stdin,
    output: process.stdout,
  });
}

function promptUser(question: string): Promise<string> {
  const rl = createReadlineInterface();
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

async function promptForEnvVar(envVar: EnvVar): Promise<string> {
  const defaultVal = generateDefault(envVar.default);
  const secretInfo = envVar.isSecret ? ' (auto-generated secure secret)' : '';
  const requiredInfo = envVar.required ? ' (required)' : ' (optional)';

  console.log(`\n📝 ${envVar.key}${requiredInfo}`);
  console.log(`   ${envVar.description}${secretInfo}`);

  if (envVar.isSecret) {
    console.log(`   🔑 Will auto-generate secure secret if left empty`);
  } else {
    console.log(`   📋 Default: ${defaultVal}`);
  }

  const answer = await promptUser(
    `   Enter value (or press Enter for ${envVar.isSecret ? 'auto-generated secret' : 'default'}): `,
  );

  // Special handling for PowerSync key pairs
  if (envVar.isSecret && !answer) {
    if (envVar.key === 'POWERSYNC_PRIVATE_KEY') {
      const keys = await generatePowerSyncKeys();
      return keys.privateKey;
    } else if (envVar.key === 'POWERSYNC_PUBLIC_KEY') {
      const keys = await generatePowerSyncKeys();
      return keys.publicKey;
    } else {
      // Generate regular secret for other variables
      return randomBytes(32).toString('hex');
    }
  }

  return answer || defaultVal;
}

async function promptForEnvironment(): Promise<string> {
  console.log('🌍 What environment are you setting up?');
  console.log('   1. Local (default) - overwrites .env');
  console.log('   2. Development - creates .env.development');
  console.log('   3. Staging - creates .env.staging');
  console.log('   4. Production - creates .env.production');
  console.log('   5. Custom - creates .env.<name>');

  const choice = await promptUser(
    '\n   Select environment [1-5] (default: 1): ',
  );

  switch (choice) {
    case '2':
      return 'development';
    case '3':
      return 'staging';
    case '4':
      return 'production';
    case '5':
      const custom = await promptUser('   Enter custom environment name: ');
      return custom || 'local';
    default:
      return 'local';
  }
}

function getEnvironmentDefaults(env: string): Partial<Record<string, string>> {
  // Environment-specific overrides can be added here if needed
  // For now, we use the defaults from .env.example as-is
  const overrides: Record<string, Partial<Record<string, string>>> = {
    staging: {
      NODE_ENV: 'staging',
      LOG_LEVEL: 'info',
    },
    production: {
      NODE_ENV: 'production',
      LOG_LEVEL: 'warn',
    },
  };

  return overrides[env] || {};
}

function getEnvFilePath(environment: string): string {
  // Local environment overwrites the main .env file
  if (environment === 'local') {
    return join(apiDir, '.env');
  }
  // Other environments create environment-specific files
  return join(apiDir, `.env.${environment}`);
}

async function generateEnvFile(): Promise<void> {
  console.log('🔧 Interactive Environment File Generator\n');

  // Use CLI argument if provided, otherwise prompt
  const environment = cliEnvironment || (await promptForEnvironment());
  const envPath = getEnvFilePath(environment);

  if (existsSync(envPath)) {
    const fileName = environment === 'local' ? '.env' : `.env.${environment}`;
    console.log(`⚠️  ${fileName} file already exists!`);
    const overwrite = await promptUser(
      '   Do you want to overwrite it? (y/N): ',
    );
    if (overwrite.toLowerCase() !== 'y' && overwrite.toLowerCase() !== 'yes') {
      console.log(
        `💡 Cancelled. Rename or delete the existing ${fileName} file to generate a new one.\n`,
      );
      return;
    }
    console.log('');
  }

  // Parse variables from .env.example
  const envVars = parseEnvExample();
  const envDefaults = getEnvironmentDefaults(environment);

  console.log(`\n🎯 Setting up ${environment} environment`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  const envValues: Record<string, string> = {};

  // Apply environment-specific defaults
  for (const envVar of envVars) {
    const envDefault = envDefaults[envVar.key];
    if (envDefault) {
      envVar.default = envDefault;
    }
  }

  // Prompt for each variable
  for (const envVar of envVars) {
    const value = await promptForEnvVar(envVar);
    envValues[envVar.key] = value;
  }

  // Generate the .env file content dynamically
  const envLines: string[] = [
    `# Auto-generated .env file for ${environment} environment`,
    `# Generated on: ${new Date().toISOString()}`,
    '',
  ];

  // Group variables by section (based on comments in .env.example)
  const originalContent = readFileSync(envExamplePath, 'utf-8');
  const originalLines = originalContent.split('\n');
  let currentSection = '';

  for (let i = 0; i < originalLines.length; i++) {
    const line = originalLines[i].trim();

    // Track section headers
    if (line.startsWith('#') && line.includes('Configuration')) {
      currentSection = line;
      envLines.push('');
      envLines.push(currentSection);
      continue;
    }

    // Add environment variable if we have a value for it
    if (line.includes('=') && !line.startsWith('#')) {
      const [key] = line.split('=');
      const cleanKey = key?.trim();

      if (cleanKey && envValues[cleanKey] !== undefined) {
        envLines.push(`${cleanKey}=${envValues[cleanKey]}`);
      }
    }

    // Add other comment lines (descriptions, optional sections, etc.)
    if (line.startsWith('#') && !line.includes('Configuration')) {
      envLines.push(line);
    }
  }

  const envContent = envLines.join('\n');
  writeFileSync(envPath, envContent);

  const fileName = environment === 'local' ? '.env' : `.env.${environment}`;
  console.log(`\n✅ ${fileName} file generated successfully!`);
  console.log(`📍 Location: ${envPath}`);
  console.log(`🌍 Environment: ${environment}`);
  console.log('');
  console.log('🔑 Generated secure secrets for:');
  console.log('   - BETTER_AUTH_SECRET');
  console.log('   - POWERSYNC_PRIVATE_KEY');
  console.log('   - POWERSYNC_PUBLIC_KEY');
  console.log('');
  console.log('📝 Next steps:');
  console.log('   1. Review the generated .env file');
  console.log('   2. Start the database: npm run docker:dev');
  console.log('   3. Run migrations: npm run db:migrate');
  console.log('   4. Start the server: npm run start:dev');
  console.log('');
}

async function main(): Promise<void> {
  console.log('🚀 Pantry API - Environment Generator\n');

  // Show usage if help is requested
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    console.log('Usage: npm run env:generate [environment]\n');
    console.log('Environments:');
    console.log('  local       - Creates/overwrites .env (default)');
    console.log('  development - Creates .env.development');
    console.log('  staging     - Creates .env.staging');
    console.log('  production  - Creates .env.production');
    console.log('  <custom>    - Creates .env.<custom>\n');
    console.log('Examples:');
    console.log('  npm run env:generate');
    console.log('  npm run env:generate local');
    console.log('  npm run env:generate staging');
    console.log('  npm run env:generate production\n');
    return;
  }

  await generateEnvFile();
  process.exit(0);
}

main().catch(console.error);
