# BATS to Vitest Migration Patterns

This document documents the translation patterns discovered during the BATS to Vitest migration.

## Phase 1 Summary (PoC: plugin_json.bats)

### Test Count Comparison

- **BATS**: 7 tests
- **Vitest**: 11 tests (split some tests for better granularity)

### Translation Patterns

#### 1. File Structure

```text
tests/plugin_json.bats → tests/plugin_json.test.ts
tests/helpers/bats_helper.bash → tests/helpers/vitest.ts
```

#### 2. Imports

```bash
# BATS
load helpers/bats_helper
```

```typescript
// Vitest
import { validateJson, getAllPluginManifests, ... } from './helpers/vitest'
```

#### 3. Setup/Teardown

```bash
# BATS
setup() {
    ensure_jq
}
```

```typescript
// Vitest
import { beforeAll } from 'vitest'

beforeAll(() => {
    // Setup code
})
```

#### 4. Test Definition

```bash
# BATS
@test "plugin.json exists" {
    local found=0
    for manifest in "${PROJECT_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
        if [ -f "$manifest" ]; then
            found=$((found + 1))
        fi
    done
    [ "$found" -gt 0 ]
}
```

```typescript
// Vitest
describe('plugin.json exists', () => {
  it('should find at least one plugin.json file', () => {
    expect(manifests.length).toBeGreaterThan(0)
  })
})
```

#### 5. Assertions

```bash
# BATS
assert_not_empty "$name" "plugin.json name field should not be empty in $manifest"
```

```typescript
// Vitest
expect(() => assertNotEmpty(name, `plugin.json name field should not be empty in ${manifest}`)).not.toThrow()
```

#### 6. JSON Validation

```bash
# BATS (using jq)
validate_json "$manifest"
json_has_field "$manifest" "name"
name=$(json_get "$manifest" "name")
```

```typescript
// Vitest (native JSON)
const data = validateJson<PluginManifest>(manifest)
expect(data).toHaveProperty('name')
const name = data.name
```

#### 7. Regex Matching

```bash
# BATS
[[ "$name" =~ ^[a-z0-9-]+$ ]]
```

```typescript
// Vitest
const isValidName = /^[a-z0-9-]+$/.test(name)
expect(isValidName).toBe(true)
```

#### 8. Loops Over Files

```bash
# BATS
for manifest in "${PROJECT_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
    if [ -f "$manifest" ]; then
        validate_json "$manifest"
    fi
done
```

```typescript
// Vitest
const manifests = getAllPluginManifests()
for (const manifest of manifests) {
  expect(() => validateJson(manifest)).not.toThrow()
}
```

### Key Differences

1. **Dynamic Data**: Vitest `it.each()` requires data at test definition time. Use loops inside tests instead.
2. **Error Handling**: Use `expect(() => fn()).not.toThrow()` for functions that throw.
3. **Type Safety**: TypeScript provides compile-time type checking.
4. **Native JSON**: No need for jq - use native JSON.parse().
5. **File System**: Use fs module instead of shell commands.

### Helper Functions Mapping

| BATS Helper | Vitest Helper | Notes |
| ----------- | ------------- | ----- |
| `validate_json(file)` | `validateJson<T>(path)` | Returns typed data |
| `json_has_field(file, field)` | `expect(data).toHaveProperty(field)` | Native Jest match |
| `json_get(file, field)` | `data.field` | Direct property access |
| `is_valid_plugin_name(name)` | `isValidPluginName(name)` | Returns boolean |
| `assert_not_empty(value, msg)` | `assertNotEmpty(value, msg)` | Throws on failure |
| `assert_file_exists(path, msg)` | `assertFileExists(path, msg)` | Throws on failure |
| `assert_dir_exists(path, msg)` | `assertDirExists(path, msg)` | Throws on failure |
| `for_each_plugin_manifest(callback)` | `getAllPluginManifests()` | Returns array of paths |

### Quality Gates Passed

- [x] Vitest test passes
- [x] Original BATS test still passes
- [x] Same test coverage (11 vs 7 - more granular)
- [x] Both suites run successfully

### Next Steps

Phase 2: Migrate marketplace_json.bats and hooks_json.bats using these patterns.
