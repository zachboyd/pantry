import { promises as fs } from 'fs';
import * as path from 'path';
import type { Migration, MigrationProvider } from 'kysely';

/**
 * Test-specific migration provider that can handle TypeScript migrations
 * by dynamically importing them during test execution
 */
export class TestMigrationProvider implements MigrationProvider {
  constructor(private readonly migrationFolder: string) {}

  async getMigrations(): Promise<Record<string, Migration>> {
    const migrations: Record<string, Migration> = {};

    try {
      const files = await fs.readdir(this.migrationFolder);
      const migrationFiles = files
        .filter((file) => file.endsWith('.ts') || file.endsWith('.js'))
        .sort();

      for (const file of migrationFiles) {
        const migrationName = path.parse(file).name;
        const migrationPath = path.join(this.migrationFolder, file);

        try {
          // Dynamic import works with both .ts and .js files in test environment
          const module = await import(migrationPath);
          migrations[migrationName] = {
            up: module.up,
            down: module.down,
          };
        } catch (error) {
          console.warn(`Failed to load migration ${file}:`, error);
          // Continue with other migrations
        }
      }
    } catch (error) {
      console.warn('Failed to read migration folder:', error);
    }

    return migrations;
  }
}
