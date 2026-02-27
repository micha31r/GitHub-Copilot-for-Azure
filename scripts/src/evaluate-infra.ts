#!/usr/bin/env node
/**
 * Evaluate Infrastructure Plan vs Generated Bicep
 *
 * Compares the infrastructure plan (.azure/infrastructure-plan.json) against
 * the generated Bicep files (infra/) across six surfaces:
 *   1. Resource types
 *   2. Resource subtypes
 *   3. SKUs
 *   4. Properties
 *   5. Dependencies
 * 
 * Other useful data
 *  - Bicep API versions
 *
 * Usage: npm run eval-bicep
 */

import { readFileSync, readdirSync } from 'node:fs';
import { resolve, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import Table from 'cli-table3';
import chalk from 'chalk';

/* Types */

interface PlanResource {
  name: string;
  type: string;
  subtype?: string;
  sku?: string;
  dependencies?: string[];
  properties?: Record<string, unknown>;
}

interface BicepResource {
  file: string;
  type: string;
  version: string;
  sku: string | null;
  properties: string[];
}

interface BicepModule {
  symbol: string;
  modulePath: string;
  type: string | null;
  deps: string[];
}

const PASS = chalk.green('✓');
const FAIL = chalk.red('✗');
const WARN = chalk.yellow('~');

/* Paths */

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '../..');
const planPath = resolve(repoRoot, '.azure/infrastructure-plan.json');
const infraDir = resolve(repoRoot, 'infra');

/* Parsing */

function loadPlan(): PlanResource[] {
  const raw = JSON.parse(readFileSync(planPath, 'utf-8'));
  return raw.plan.resources as PlanResource[];
}

/**
 * Minimal Bicep parser. Extracts resource declarations and top-level property keys.
 * Looks for lines like:  resource foo 'Type@Version' = {
 * Then collects property keys from the properties: { ... } block.
 */
function parseBicepFile(filePath: string): BicepResource[] {
  const content = readFileSync(filePath, 'utf-8');
  const resources: BicepResource[] = [];
  const fileName = basename(filePath);

  const resourceRe = /resource\s+\w+\s+'([^']+)@([^']+)'\s*=/g;
  let m: RegExpExecArray | null;

  while ((m = resourceRe.exec(content)) !== null) {
    const type = m[1];
    const version = m[2];
    const props = extractPropertyKeys(content, m.index);
    const sku = extractSkuName(content, m.index);
    resources.push({ file: fileName, type, version, sku, properties: props });
  }
  return resources;
}

/**
 * Extract the SKU name from a resource block.
 * Handles hardcoded (name: 'Basic'), parameterized (name: skuName), and
 * resolves param references to their default values when possible.
 */
function extractSkuName(content: string, startOffset: number): string | null {
  const after = content.slice(startOffset);
  const skuMatch = after.match(/\bsku\s*:\s*\{/);
  if (!skuMatch || skuMatch.index === undefined) return null;

  const skuBlock = after.slice(skuMatch.index, skuMatch.index + 200);
  const literalMatch = skuBlock.match(/name\s*:\s*'([^']+)'/);
  if (literalMatch) return literalMatch[1];

  const paramMatch = skuBlock.match(/name\s*:\s*(\w+)/);
  if (paramMatch) {
    const paramName = paramMatch[1];
    const defaultMatch = content.match(
      new RegExp(`param\\s+${paramName}\\s+\\w+\\s*=\\s*'([^']+)'`)
    );
    if (defaultMatch) return `${defaultMatch[1]} (param: ${paramName})`;
    return `(param: ${paramName})`;
  }
  return null;
}

function extractPropertyKeys(content: string, startOffset: number): string[] {
  const after = content.slice(startOffset);
  const propMatch = after.match(/properties\s*:\s*\{/);
  if (!propMatch || propMatch.index === undefined) return [];

  const keys: string[] = [];
  const blockStart = propMatch.index + propMatch[0].length;
  let depth = 1;
  const lines = after.slice(blockStart).split('\n');

  for (const line of lines) {
    for (const ch of line) {
      if (ch === '{') depth++;
      if (ch === '}') depth--;
    }
    if (depth <= 0) break;
    if (depth === 1) {
      const keyMatch = line.match(/^\s*(\w+)\s*:/);
      if (keyMatch) keys.push(keyMatch[1]);
    }
  }
  return keys;
}

function loadBicepResources(): BicepResource[] {
  const resources: BicepResource[] = [];
  resources.push(...parseBicepFile(resolve(infraDir, 'main.bicep')));
  const modulesDir = resolve(infraDir, 'modules');
  for (const f of readdirSync(modulesDir).filter(f => f.endsWith('.bicep'))) {
    resources.push(...parseBicepFile(resolve(modulesDir, f)));
  }
  return resources;
}

/**
 * Parse module declarations from main.bicep to extract dependency graph.
 * Looks for patterns like:
 *   module <sym> 'modules/<file>.bicep' = {
 *     params: { ...: otherModule.outputs.id }
 *   }
 */
function parseBicepModules(): BicepModule[] {
  const content = readFileSync(resolve(infraDir, 'main.bicep'), 'utf-8');
  const modules: BicepModule[] = [];

  const moduleRe = /module\s+(\w+)\s+'([^']+)'\s*=(?:\s*if\s*\([^)]*\))?\s*\{/g;
  let m: RegExpExecArray | null;

  while ((m = moduleRe.exec(content)) !== null) {
    const symbol = m[1];
    const modulePath = m[2];

    const after = content.slice(m.index);
    const deps = new Set<string>();
    const refRe = /(\w+)\.outputs\./g;
    let ref: RegExpExecArray | null;

    const blockEnd = after.indexOf('\n}\n', 10);
    const block = blockEnd > 0 ? after.slice(0, blockEnd) : after.slice(0, 500);

    while ((ref = refRe.exec(block)) !== null) {
      if (ref[1] !== symbol) deps.add(ref[1]);
    }

    if (block.match(/scope\s*:\s*rg\b/)) {
      deps.add('rg');
    }

    const moduleFile = resolve(infraDir, modulePath);
    let type: string | null = null;
    try {
      const moduleContent = readFileSync(moduleFile, 'utf-8');
      const typeMatch = moduleContent.match(/resource\s+\w+\s+'([^']+)@/);
      if (typeMatch) type = typeMatch[1];
    } catch { /* module file not found */ }

    modules.push({ symbol, modulePath, type, deps: [...deps] });
  }

  return modules;
}

/* Helpers */

function groupByType<T>(items: T[], keyFn: (item: T) => string): Map<string, T[]> {
  const map = new Map<string, T[]>();
  for (const item of items) {
    const key = keyFn(item);
    if (!map.has(key)) map.set(key, []);
    map.get(key)!.push(item);
  }
  return map;
}

function shortType(type: string): string {
  const parts = type.split('/');
  return parts[parts.length - 1];
}

function heading(n: number, title: string): void {
  console.log(`\n${chalk.bold(`${n}. ${title}`)}`);
}

/* Comparison */

function compare(planResources: PlanResource[], bicepResources: BicepResource[]): number {
  const planTypes = new Set(planResources.map(r => r.type));
  const bicepTypes = new Set(bicepResources.map(r => r.type));
  const planByType = groupByType(planResources, r => r.type);
  let issues = 0;
  let warnings = 0;

  const coveredCount = [...planTypes].filter(t => bicepTypes.has(t)).length;
  console.log(`\n  Coverage: ${coveredCount}/${planTypes.size} plan types covered in Bicep (${bicepTypes.size} total Bicep types)`);

  // 1. Resource types
  heading(1, 'RESOURCE TYPES');
  const typeTable = new Table({ head: ['Resource Type', 'Plan', 'Bicep', ''] });
  const allTypes = new Set([...planTypes, ...bicepTypes]);
  for (const t of allTypes) {
    const inPlan = planTypes.has(t);
    const inBicep = bicepTypes.has(t);
    const match = inPlan && inBicep;
    if (!match) {
      if (inBicep && !inPlan) warnings++; else issues++;
    }
    typeTable.push([
      t,
      inPlan ? 'Yes' : chalk.dim('No'),
      inBicep ? 'Yes' : chalk.dim('No'),
      match ? PASS : (inBicep && !inPlan ? WARN : FAIL),
    ]);
  }
  console.log(typeTable.toString());

  // 2. Resource subtypes
  heading(2, 'RESOURCE SUBTYPES');
  const subtypes = planResources.filter(r => r.subtype);
  if (subtypes.length === 0) {
    console.log('  No subtypes defined in plan.');
  } else {
    const subTable = new Table({ head: ['Subtype', 'Resource Type', 'In Bicep', ''] });
    const subtypeMap = new Map<string, string>();
    for (const r of subtypes) subtypeMap.set(r.type, r.subtype!);
    for (const [type, subtype] of subtypeMap) {
      const inBicep = bicepTypes.has(type);
      if (!inBicep) issues++;
      subTable.push([subtype, shortType(type), inBicep ? 'Yes' : 'No', inBicep ? PASS : FAIL]);
    }
    console.log(subTable.toString());
  }

  // 3. SKUs
  heading(3, 'SKUS');
  const skuTable = new Table({ head: ['Resource Type', 'Plan SKU', 'Bicep SKU', ''] });
  let skusCompared = false;

  for (const br of bicepResources) {
    const planGroup = planByType.get(br.type);
    if (!planGroup) continue;

    const planSkus = new Set(
      planGroup.map(r => r.sku).filter(s => s && s !== 'N/A') as string[]
    );
    if (planSkus.size === 0 && !br.sku) continue;

    const bicepSku = br.sku ?? '(none)';
    const planSkuList = planSkus.size > 0 ? [...planSkus].join(', ') : '(none)';

    const bicepSkuBase = bicepSku.replace(/\s*\(param:.*\)/, '').toLowerCase();
    const mismatched = [...planSkus].filter(s => s.toLowerCase() !== bicepSkuBase);
    const match = mismatched.length === 0 && !(planSkus.size > 0 && !br.sku);

    if (!match) issues++;
    skuTable.push([shortType(br.type), planSkuList, bicepSku, match ? PASS : FAIL]);
    skusCompared = true;
  }

  if (skusCompared) {
    console.log(skuTable.toString());
  } else {
    console.log('  No SKUs to compare.');
  }

  // 4. Properties
  heading(4, 'PROPERTIES');
  const propTable = new Table({ head: ['Resource Type', 'Property', 'Plan', 'Bicep', ''] });
  let propsCompared = false;

  for (const br of bicepResources) {
    const planGroup = planByType.get(br.type);
    if (!planGroup) continue;

    const planPropKeys = new Set<string>();
    for (const pr of planGroup) {
      if (pr.properties) {
        for (const k of Object.keys(pr.properties)) planPropKeys.add(k);
      }
    }
    const bicepPropKeys = new Set(br.properties);
    const allProps = new Set([...planPropKeys, ...bicepPropKeys]);

    for (const p of allProps) {
      const inPlan = planPropKeys.has(p);
      const inBicep = bicepPropKeys.has(p);
      const match = inPlan && inBicep;
      if (!match) {
        if (inBicep && !inPlan) warnings++; else issues++;
      }
      propsCompared = true;
      propTable.push([
        shortType(br.type),
        p,
        inPlan ? 'Yes' : chalk.dim('No'),
        inBicep ? 'Yes' : chalk.dim('No'),
        match ? PASS : (inBicep && !inPlan ? WARN : FAIL),
      ]);
    }
  }

  // Plan types with properties but no Bicep properties block
  for (const [type, group] of planByType) {
    if (!bicepTypes.has(type)) continue;
    const hasProps = group.some(r => r.properties && Object.keys(r.properties).length > 0);
    const bicepMatch = bicepResources.find(br => br.type === type);
    if (hasProps && bicepMatch && bicepMatch.properties.length === 0) {
      propTable.push([shortType(type), chalk.dim('(all)'), 'Yes', chalk.dim('No'), FAIL]);
      issues++;
      propsCompared = true;
    }
  }

  if (propsCompared) {
    console.log(propTable.toString());
  } else {
    console.log('  No properties to compare.');
  }

  // 5. Dependencies
  heading(5, 'DEPENDENCIES');
  const bicepModules = parseBicepModules();

  const symbolToType = new Map<string, string>();
  for (const mod of bicepModules) {
    if (mod.type) symbolToType.set(mod.symbol, mod.type);
  }
  symbolToType.set('rg', 'Microsoft.Resources/resourceGroups');

  const planNameToType = new Map<string, string>();
  for (const r of planResources) planNameToType.set(r.name, r.type);

  const depTable = new Table({ head: ['Resource Type', 'Dependency', 'Plan', 'Bicep', ''] });
  let depsCompared = false;

  for (const mod of bicepModules) {
    if (!mod.type) continue;

    const bicepDepTypes = new Set(
      mod.deps.map(sym => symbolToType.get(sym)).filter(Boolean) as string[]
    );

    const planGroup = planByType.get(mod.type);
    if (!planGroup) continue;

    const planDepTypes = new Set<string>();
    for (const r of planGroup) {
      if (r.dependencies) {
        for (const depName of r.dependencies) {
          const depType = planNameToType.get(depName);
          if (depType) planDepTypes.add(depType);
        }
      }
    }

    if (planDepTypes.size === 0 && bicepDepTypes.size === 0) continue;

    const allDeps = new Set([...planDepTypes, ...bicepDepTypes]);
    for (const dep of allDeps) {
      const inPlan = planDepTypes.has(dep);
      const inBicep = bicepDepTypes.has(dep);
      const match = inPlan && inBicep;
      if (!match) {
        if (inBicep && !inPlan) warnings++; else issues++;
      }
      depsCompared = true;
      depTable.push([
        shortType(mod.type),
        shortType(dep),
        inPlan ? 'Yes' : chalk.dim('No'),
        inBicep ? 'Yes' : chalk.dim('No'),
        match ? PASS : (inBicep && !inPlan ? WARN : FAIL),
      ]);
    }
  }

  if (depsCompared) {
    console.log(depTable.toString());
  } else {
    console.log('  No dependencies to compare.');
  }

  // 6. API versions
  heading(6, 'API VERSIONS');
  const versionTable = new Table({ head: ['Resource Type', 'Version', 'File'] });
  for (const br of bicepResources) {
    versionTable.push([shortType(br.type), br.version, br.file]);
  }
  console.log(versionTable.toString());


  // Summary
  console.log();
  if (issues === 0 && warnings === 0) {
    console.log(chalk.green(`${PASS} All ${planTypes.size} plan resource types are covered in Bicep.`));
  } else {
    const parts: string[] = [];
    if (issues > 0) parts.push(chalk.red(`${issues} error(s)`));
    if (warnings > 0) parts.push(chalk.yellow(`${warnings} warning(s)`));
    console.log(`${issues > 0 ? FAIL : WARN} ${parts.join(', ')} found.`);
  }
  console.log();

  return issues;
}

/* Main */

function main(): void {
  console.log(chalk.bold('\nEvaluating infrastructure plan vs generated Bicep\n'));
  console.log(`  Plan:  .azure/infrastructure-plan.json`);
  console.log(`  Bicep: infra/`);

  const planResources = loadPlan();
  const bicepResources = loadBicepResources();

  console.log(`\n  Plan resources: ${planResources.length}  |  Bicep resources: ${bicepResources.length}`);

  const issues = compare(planResources, bicepResources);
  process.exit(issues > 0 ? 1 : 0);
}

main();
