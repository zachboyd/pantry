#!/usr/bin/env node --loader ts-node/esm

/**
 * PowerSync Schema Generation Script
 *
 * Automatically generates PowerSync schema from Kysely database types.
 * Uses simple auto-detection and safe defaults for reliable compilation.
 *
 * Usage: npm run powersync:generate
 */

import { writeFileSync, readFileSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Tables to exclude from PowerSync sync (auth, internal, etc.)
const EXCLUDED_TABLES = [
  'auth_account',
  'auth_session',
  'auth_user',
  'auth_verification',
  'cron.job',
  'cron.job_run_details',
];

/**
 * Simple type mapping - always produces valid results
 */
function mapTypeToColumnType(typeDef: string): 'text' | 'integer' | 'real' {
  const type = typeDef.toLowerCase();

  // Boolean types → integer (0/1 in PowerSync)
  if (type.includes('boolean')) {
    return 'integer';
  }

  // Numeric types → integer or real
  if (type.includes('number') || type.includes('int')) {
    return 'integer';
  }

  if (
    type.includes('numeric') ||
    type.includes('decimal') ||
    type.includes('float')
  ) {
    return 'real';
  }

  // Everything else → text (safe default)
  // This includes: string, Date, Timestamp, Json, enums, etc.
  return 'text';
}

/**
 * Extract database indexes from migration files
 */
function extractDatabaseIndexes(): Record<string, Record<string, string[]>> {
  const migrationsDir = join(__dirname, '../src/database/migrations');
  const migrationFiles = readdirSync(migrationsDir)
    .filter((file: string) => file.endsWith('.ts'))
    .map((file: string) => join(migrationsDir, file));

  const dbIndexes: Record<string, Record<string, string[]>> = {};

  for (const filePath of migrationFiles) {
    try {
      const content = readFileSync(filePath, 'utf8');

      // Extract createIndex statements
      // Pattern 1: .createIndex('name').on('table').columns([...])
      const indexPattern1 =
        /\.createIndex\s*\(\s*['"`]([^'"`]+)['"`]\s*\)\s*\.on\s*\(\s*['"`]([^'"`]+)['"`]\s*\)\s*\.columns\s*\(\s*\[([^\]]+)\]\s*\)/g;
      // Pattern 2: .createIndex('name').on('table').column('col')
      const indexPattern2 =
        /\.createIndex\s*\(\s*['"`]([^'"`]+)['"`]\s*\)\s*\.on\s*\(\s*['"`]([^'"`]+)['"`]\s*\)\s*\.column\s*\(\s*['"`]([^'"`]+)['"`]\s*\)/g;

      // Handle multi-column indexes: .columns([...])
      let match: RegExpExecArray | null;
      while ((match = indexPattern1.exec(content)) !== null) {
        const [, indexName, tableName, columnsStr] = match;

        // Parse column names from the array
        const columns = columnsStr
          .split(',')
          .map((col) => col.trim().replace(/['"`]/g, ''))
          .filter((col) => col.length > 0);

        if (columns.length > 0) {
          if (!dbIndexes[tableName]) {
            dbIndexes[tableName] = {};
          }

          // Generate simplified PowerSync index name
          const powerSyncIndexName = generatePowerSyncIndexName(
            indexName,
            columns,
          );
          dbIndexes[tableName][powerSyncIndexName] = columns;
        }
      }

      // Handle single-column indexes: .column('col')
      while ((match = indexPattern2.exec(content)) !== null) {
        const [, indexName, tableName, columnName] = match;
        const columns = [columnName];

        if (!dbIndexes[tableName]) {
          dbIndexes[tableName] = {};
        }

        // Generate simplified PowerSync index name
        const powerSyncIndexName = generatePowerSyncIndexName(
          indexName,
          columns,
        );
        dbIndexes[tableName][powerSyncIndexName] = columns;
      }
    } catch (error) {
      console.warn(
        `⚠️  Could not parse migration file ${filePath}: ${(error as Error).message}`,
      );
    }
  }

  return dbIndexes;
}

/**
 * Generate simplified PowerSync index name based purely on columns
 */
function generatePowerSyncIndexName(
  _dbIndexName: string,
  columns: string[],
): string {
  // Generate name based purely on columns, not hardcoded patterns
  if (columns.length === 1) {
    // Single column: 'auth_user_id' -> 'auth_user', 'email' -> 'email'
    return columns[0].replace(/_id$/, '');
  }

  if (columns.length === 2) {
    // Two columns: ['chat_id', 'user_id'] -> 'chat_user'
    return columns.join('_').replace(/_id/g, '');
  }

  if (columns.length === 3) {
    // Three columns: use first and last
    return `${columns[0]}_${columns[columns.length - 1]}`.replace(/_id/g, '');
  }

  // Fallback for more complex indexes: use first column + suffix
  return `${columns[0].replace(/_id$/, '')}_multi`;
}

/**
 * Generate PowerSync indexes based on extracted database indexes
 */
function generateIndexes(
  tableName: string,
  columns: string[],
): Record<string, string[]> {
  const indexes: Record<string, string[]> = {};

  // Extract indexes from migration files on first call (cached)
  if (!generateIndexes.dbIndexes) {
    generateIndexes.dbIndexes = extractDatabaseIndexes();
  }

  const tableIndexes = generateIndexes.dbIndexes[tableName];
  if (tableIndexes) {
    for (const [indexName, indexColumns] of Object.entries(tableIndexes)) {
      // Only add index if all required columns exist in the table
      if (indexColumns.every((col) => columns.includes(col))) {
        indexes[indexName] = indexColumns;
      }
    }
  }

  return indexes;
}

// Cache for database indexes
generateIndexes.dbIndexes = null as Record<
  string,
  Record<string, string[]>
> | null;

/**
 * Extract table definitions from Kysely DB interface
 */
function extractTablesFromDB(
  content: string,
): Map<string, Map<string, string>> {
  const tables = new Map<string, Map<string, string>>();

  // Find the DB interface
  const dbMatch = content.match(/export interface DB \{([\s\S]*?)\}/m);
  if (!dbMatch) {
    throw new Error('Could not find DB interface in generated types');
  }

  // Extract table entries from DB interface
  const dbContent = dbMatch[1];
  const tablePattern = /['"]?([^'":\s]+)['"]?\s*:\s*([^;]+);?/g;
  let match: RegExpExecArray | null;

  while ((match = tablePattern.exec(dbContent)) !== null) {
    const [, tableName, interfaceName] = match;

    if (EXCLUDED_TABLES.includes(tableName)) {
      continue;
    }

    // Extract columns from the table interface
    const columns = extractColumnsFromInterface(content, interfaceName.trim());
    if (columns.size > 0) {
      tables.set(tableName, columns);
    }
  }

  return tables;
}

/**
 * Extract columns from a specific interface
 */
function extractColumnsFromInterface(
  content: string,
  interfaceName: string,
): Map<string, string> {
  const columns = new Map<string, string>();

  // Find the interface definition
  const interfacePattern = new RegExp(
    `export interface ${interfaceName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')} \\{([\\s\\S]*?)\\}`,
    'm',
  );

  const interfaceMatch = content.match(interfacePattern);
  if (!interfaceMatch) {
    console.warn(`⚠️  Could not find interface ${interfaceName}`);
    return columns;
  }

  // Extract column definitions
  const interfaceBody = interfaceMatch[1];
  const columnPattern = /([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*([^;]+);?/g;
  let match: RegExpExecArray | null;

  while ((match = columnPattern.exec(interfaceBody)) !== null) {
    const [, columnName, columnType] = match;
    columns.set(columnName.trim(), columnType.trim());
  }

  return columns;
}

/**
 * Generate clean PowerSync schema code
 */
function generateSchema(tables: Map<string, Map<string, string>>): string {
  const imports = `import { column, Schema, Table } from '@powersync/node';`;

  const header = `
// PowerSync schema mapping from database tables
// Auto-generated from Kysely database types - DO NOT EDIT MANUALLY
// Generated at: ${new Date().toISOString()}
// 
// This file is automatically generated from the database schema.
// To regenerate, run: npm run powersync:generate
`;

  const tableDefinitions: string[] = [];
  const tableNames: string[] = [];

  for (const [tableName, columns] of tables) {
    const tableVarName = tableName.replace(/[.-]/g, '_');
    const columnNames = Array.from(columns.keys());

    // Generate column definitions with proper comma handling
    const columnDefs = columnNames.map((columnName, index) => {
      const columnType = columns.get(columnName)!;
      const powerSyncType = mapTypeToColumnType(columnType);
      const isLast = index === columnNames.length - 1;

      // Add helpful comments for non-obvious mappings
      let comment = '';
      if (
        powerSyncType === 'text' &&
        (columnType.includes('Date') || columnType.includes('Timestamp'))
      ) {
        comment = ' // date/time as text';
      } else if (powerSyncType === 'text' && columnType.includes('Json')) {
        comment = ' // JSON as text';
      } else if (
        powerSyncType === 'integer' &&
        columnType.includes('boolean')
      ) {
        comment = ' // boolean as integer';
      }

      // Place comma before comment to avoid syntax issues
      const comma = isLast ? '' : ',';
      return `  ${columnName}: column.${powerSyncType}${comma}${comment}`;
    });

    // Generate indexes
    const indexes = generateIndexes(tableName, columnNames);
    let indexesDef = '';
    if (Object.keys(indexes).length > 0) {
      const indexEntries = Object.entries(indexes).map(
        ([name, cols]) =>
          `    ${name}: [${cols.map((c) => `'${c}'`).join(', ')}]`,
      );
      indexesDef = `,
{
  indexes: {
${indexEntries.join(',\n')}
  }
}`;
    }

    // Combine into table definition
    tableDefinitions.push(
      `export const ${tableVarName} = new Table({
${columnDefs.join('\n')}
}${indexesDef});`,
    );

    tableNames.push(tableVarName);
  }

  const schemaExport = `
// Main schema export
export const AppSchema = new Schema({
${tableNames.map((name) => `  ${name}`).join(',\n')}
});

export type Database = (typeof AppSchema)['types'];`;

  // Generate type exports
  const typeExports = Array.from(tables.keys())
    .map((tableName) => {
      const typeName =
        tableName
          .split('_')
          .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
          .join('') + 'Record';
      return `export type ${typeName} = Database['${tableName}'];`;
    })
    .join('\n');

  return [
    imports,
    header,
    tableDefinitions.join('\n\n'),
    schemaExport,
    typeExports,
  ].join('\n');
}

// Main execution
console.log('🔄 Generating PowerSync schema from Kysely database types...');

try {
  // Paths
  const databaseTypesPath = join(__dirname, '../src/generated/database.ts');
  const outputPath = join(__dirname, '../src/generated/powersync-schema.ts');

  console.log(`📋 Source: ${databaseTypesPath}`);
  console.log(`🏠 Output: ${outputPath}`);
  console.log('');

  // Read and parse database types
  console.log('🔍 Parsing Kysely database types...');
  const content = readFileSync(databaseTypesPath, 'utf8');
  const tables = extractTablesFromDB(content);

  console.log(`📋 Found ${tables.size} tables to sync:`);
  for (const tableName of tables.keys()) {
    console.log(`   - ${tableName}`);
  }
  console.log('');

  // Generate PowerSync schema
  console.log('🛠️  Generating PowerSync schema...');
  const schemaCode = generateSchema(tables);

  // Write output
  writeFileSync(outputPath, schemaCode);

  console.log('✅ PowerSync schema generation complete!');
  console.log('');
  console.log('📋 Generated:');
  console.log(`   - ${outputPath}`);
  console.log('');
  console.log('🎯 Usage:');
  console.log('   import { AppSchema, UserRecord } from "./powersync-schema"');
  console.log('');
  console.log('💡 Features:');
  console.log('   - Auto-detected tables and columns');
  console.log('   - Smart type mapping with safe defaults');
  console.log('   - Auto-extracted indexes from migration files');
  console.log('   - Clean, compilable TypeScript output');
} catch (error) {
  console.error('❌ PowerSync schema generation failed:');
  console.error((error as Error).message);
  process.exit(1);
}
