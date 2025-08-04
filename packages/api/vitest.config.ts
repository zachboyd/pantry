import { defineConfig } from 'vitest/config';
import { resolve } from 'path';
import swc from 'unplugin-swc';

export default defineConfig({
  plugins: [
    swc.vite({
      tsconfigFile: './tsconfig.json'
    })
  ],
  
  test: {
    // Use Vitest projects to separate unit and integration tests
    projects: [
      // Unit tests project
      {
        extends: true,
        test: {
          name: 'unit',
          // Unit test file patterns - exclude integration tests
          include: ['**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}'],
          exclude: [
            '**/node_modules/**',
            '**/dist/**',
            '**/cypress/**',
            '**/.{idea,git,cache,output,temp}/**',
            '**/{karma,rollup,webpack,vite,vitest,jest,ava,babel,nyc,cypress,tsup,build}.config.*',
            '**/*.integration.spec.ts' // Exclude integration tests
          ],
          
          // Use Node.js environment
          environment: 'node',
          
          // Global test setup for unit tests
          globals: true,
          setupFiles: ['./src/test/setup.ts'],
          
          // Environment setup
          env: {
            NODE_ENV: 'test',
          },
          
          // Standard timeout for unit tests
          testTimeout: 10000,
          
          // Mock resolution
          deps: {
            interopDefault: true
          }
        }
      },
      
      // Integration tests project
      {
        extends: true,
        test: {
          name: 'integration',
          // Integration test file patterns - only integration tests
          include: ['**/*.integration.spec.ts'],
          exclude: [
            '**/node_modules/**',
            '**/dist/**',
            '**/cypress/**',
            '**/.{idea,git,cache,output,temp}/**'
          ],
          
          // Use Node.js environment
          environment: 'node',
          
          // Global setup and teardown for Docker services
          globalSetup: ['./src/test/setup/global-setup.ts'],
          
          // Integration test specific setup
          globals: true,
          setupFiles: [
            './src/test/setup.ts',
            './src/test/setup/integration-setup.ts'
          ],
          
          // Environment setup
          env: {
            NODE_ENV: 'test',
          },
          
          // Longer timeout for integration tests
          testTimeout: 30000,
          
          // Use forks pool for process isolation
          pool: 'forks',
          poolOptions: {
            forks: {
              singleFork: true
            }
          },
          
          // Mock resolution
          deps: {
            interopDefault: true
          }
        }
      }
    ],
    
    // Coverage configuration (applies to all projects)
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'coverage/**',
        'dist/**',
        'packages/*/test{,s}/**',
        '**/*.d.ts',
        'cypress/**',
        'test{,s}/**',
        'test{,-*}.{js,cjs,mjs,ts,tsx,jsx}',
        '**/*{.,-}test.{js,cjs,mjs,ts,tsx,jsx}',
        '**/*{.,-}spec.{js,cjs,mjs,ts,tsx,jsx}',
        '**/__tests__/**',
        '**/{karma,rollup,webpack,vite,vitest,jest,ava,babel,nyc,cypress,tsup,build}.config.*',
        '**/.{eslint,mocha,prettier}rc.{js,cjs,yml}',
        'src/generated/**',
        'src/database/migrations/**',
        'scripts/**'
      ],
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 80,
          statements: 80
        }
      }
    }
  },
  
  resolve: {
    alias: {
      // Match tsconfig baseUrl
      '@': resolve(__dirname, './src'),
      '@common': resolve(__dirname, './src/common'),
      '@modules': resolve(__dirname, './src/modules'),
      '@generated': resolve(__dirname, './src/generated')
    }
  }
});