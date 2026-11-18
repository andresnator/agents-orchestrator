import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';

const ROOT = new URL('../', import.meta.url);
const REGISTRY_PATH = '.ai/atl/skill-registry.md';
const MAX_RULES = 3;

// global/AGENTS.md is the only owner of the registry contract.
const AGENTS = readFileSync(new URL('global/AGENTS.md', ROOT), 'utf8');

function registrySection(source) {
  const parts = source.split('## Skill Registry\n');
  assert.equal(parts.length, 2, 'global/AGENTS.md must have exactly one "## Skill Registry" section');
  return parts[1].split(/\n(?:## |<!-- )/)[0];
}

function rules(section) {
  return section.split('\n').filter((line) => line.startsWith('- '));
}

test('shouldKeepRegistryContractWithinThreeRulesWhenSectionIsRead', () => {
  // Given
  const section = registrySection(AGENTS);
  // When
  const lines = section.split('\n').filter((line) => line.trim() !== '');
  // Then
  assert.ok(lines.length >= 1 && lines.length <= MAX_RULES, `expected 1-${MAX_RULES} lines, got ${lines.length}`);
  assert.deepEqual(lines, rules(section), 'each line of the section must be one bullet rule');
});

test('shouldPreferNativeSkillListWhenSelectingSkill', () => {
  // Given
  const [first] = rules(registrySection(AGENTS));
  // Then
  assert.match(first, /native skill list/);
  assert.ok(!first.includes(REGISTRY_PATH), 'the first rule must not send the model to the registry file');
});

test('shouldReadRegistryPathOnlyAsFallbackWhenNativeListHasNoMatch', () => {
  // Given
  const fallback = rules(registrySection(AGENTS)).filter((line) => line.includes(`\`${REGISTRY_PATH}\``));
  // Then
  assert.equal(fallback.length, 1, `exactly one rule must name \`${REGISTRY_PATH}\``);
  assert.match(fallback[0], /only when the native list has no match or a command asks for it/);
});

test('shouldForbidHandEditsWhenRegistryIsGenerated', () => {
  // Given
  const section = registrySection(AGENTS);
  // Then
  assert.match(section, /Never edit the registry by hand/);
});

test('shouldDenyEditAfterWildcardWhenScoutIsLoaded', () => {
  // Given: OpenCode uses the last matching permission rule, so the key order is the behavior.
  const frontmatter = readFileSync(new URL('agents/scout.md', ROOT), 'utf8').split('---\n')[1];
  // When
  const wildcard = frontmatter.indexOf('"*": allow');
  const edit = frontmatter.indexOf('edit: deny');
  // Then
  assert.ok(wildcard !== -1 && edit !== -1, 'scout must allow "*" and deny edit');
  assert.ok(wildcard < edit, 'edit: deny must come after "*": allow');
});

test('shouldNotDependOnRemovedRoutingSkillWhenContractIsShort', () => {
  // Given
  const section = registrySection(AGENTS);
  // Then
  assert.ok(!AGENTS.includes('oc-routing'), 'global/AGENTS.md must not name oc-routing');
  assert.ok(!existsSync(new URL('skills/oc-routing', ROOT)), 'skills/oc-routing must not exist');
  for (const legacy of ['Skill ID', 'Location', 'Trigger']) {
    assert.ok(!section.includes(legacy), `the section must not restate the snapshot schema (${legacy})`);
  }
});
