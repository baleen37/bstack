# Testing Guide

This project uses BATS (Bash Automated Testing System) for testing plugin structure, configuration, and components.

## Running Tests

### All Tests (Root + Plugins)

```bash
bash tests/run-all-tests.sh
```

This script runs:

1. Root tests in `tests/`
2. All plugin tests in `plugins/*/tests/`

### Root Tests Only

```bash
bats tests/
```

### Individual Test Files

```bash
# Unit tests
bats tests/directory_structure.bats
bats tests/marketplace_json.bats
bats tests/plugin_json.bats
bats tests/frontmatter_tests.bats
bats tests/github_workflows.bats
bats tests/hooks_json.bats

# Error handling and edge cases
bats tests/error_handling.bats
bats tests/edge_cases.bats

# Integration tests
bats tests/integration/plugin_loading.bats

# Performance tests
bats tests/performance/benchmarks.bats
```

### Test Count

- Unit Tests: 148 tests
- Integration Tests: 20 tests (10 plugin loading + 10 cross-plugin interactions)
- Performance Tests: 10 tests
- Error Handling Tests: 23 tests
- Edge Case Tests: 17 tests
- Negative Tests: 17 tests
- **Total: 178 tests**

### Individual Plugin Tests

```bash
bats plugins/git-guard/tests/
bats plugins/me/tests/
bats plugins/ralph-loop/tests/
bats plugins/strategic-compact/tests/
```

### Verbose Output

```bash
bats --verbose tests/
bats --print-output-on-failure tests/
```

## Test Organization

Tests are organized into four categories:

1. **Unit Tests** (`tests/`) - Test individual components and functions
2. **Integration Tests** (`tests/integration/`) - Test end-to-end scenarios
3. **Performance Tests** (`tests/performance/`) - Benchmark critical operations
4. **Error Handling & Edge Case Tests** - Test error conditions and boundary values

## Test Files

### Unit Tests (tests/)

#### directory_structure.bats

Validates the overall plugin structure:

- Required directories exist (`.claude-plugin/`, `plugins/`)
- Each plugin has required subdirectories
- Plugin directories follow naming convention

### fixture_factory.bats

Tests the fixture factory helper functions:

- `create_minimal_plugin()` creates minimal plugin structure
- `create_full_plugin()` creates complete plugin with all components
- `create_command_file()`, `create_agent_file()`, `create_skill_file()` create valid component files
- `cleanup_fixtures()` properly removes test fixtures

### frontmatter_tests.bats

Validates YAML frontmatter in all component files (consolidated from command/agent/skill file tests):

- Command files have valid frontmatter delimiter
- Agent files have valid frontmatter delimiter
- SKILL.md files have valid frontmatter with name and description fields

### github_workflows.bats

Validates GitHub Actions workflow files:

- CI workflow has correct triggers and permissions
- Release workflow has proper configuration
- Marketplace sync workflow is valid

### hooks_json.bats

Validates hooks.json configuration:

- Valid JSON structure
- Required top-level fields
- Hook entries have required type field
- Uses portable CLAUDE_PLUGIN_ROOT paths

### marketplace_json.bats

Validates `.claude-plugin/marketplace.json`:

- File exists and is valid JSON
- Contains required fields
- Plugins array matches actual plugins directory
- Owner information is present

### plugin_json.bats

Validates individual `.claude-plugin/plugin.json` files:

- File exists for each plugin
- Valid JSON format
- Required fields present
- Only allowed fields are used
- Field types are correct

### validate_paths.bats

Validates that no hardcoded absolute paths exist:

- JSON files use portable ${CLAUDE_PLUGIN_ROOT} paths
- Shell scripts use portable paths
- Markdown files use portable paths

### validate_plugin_manifest.bats

Comprehensive plugin.json validation:

- Schema validation
- Field type validation
- Author field validation (string or object)

### new_assertions.bats

Tests for new assertion helper functions:

- Negative assertions (file/dir not exists)
- String comparison (contains, not contains)
- Numeric comparison (greater than, less than)
- Array operations
- File operations (executable, size, line count)

### Integration Tests (tests/integration/)

#### plugin_loading.bats

End-to-end plugin loading and validation:

- All plugins have valid manifests
- Plugin names are unique
- Marketplace configuration is complete
- No hardcoded paths
- All workflows are valid YAML

### Performance Tests (tests/performance/)

#### benchmarks.bats

Performance benchmarks for critical operations:

- Plugin list caching effectiveness
- JSON parsing speed
- File operation efficiency
- Test execution timing

### Error Handling Tests (tests/)

#### error_handling.bats

Tests for error conditions and error messages:

- Malformed JSON handling
- Missing file handling
- Invalid input validation
- Error message clarity

#### edge_cases.bats

Tests for boundary conditions:

- Empty configuration files
- Unicode and special characters
- Very long field values
- Minimal/maximum valid configurations

Performance benchmarks for critical operations:

- Plugin list caching effectiveness
- JSON parsing speed
- File operation efficiency
- Test execution timing

## Test Helpers

Tests use `tests/helpers/bats_helper.bash` which provides:

- Project root detection and path exports
- Automatic setup/teardown (TEST_TEMP_DIR creation/cleanup)
- JSON validation and parsing helpers
- Assertion functions with clear error messages
- Plugin validation helpers

Tests can also use `tests/helpers/fixture_factory.bash` for creating test fixtures.

### Core Helpers

- `assert_eq <actual> <expected> <message>`: Assert equality with custom message
- `assert_not_empty <value> <message>`: Assert value is not empty
- `assert_file_exists <path> <message>`: Assert file exists
- `assert_dir_exists <path> <message>`: Assert directory exists
- `assert_matches <value> <regex> <message>`: Assert matches regex pattern
- `assert_success`: Assert exit code is 0
- `assert_failure`: Assert exit code is not 0
- `assert_output [--partial] <expected>`: Assert output matches

### JSON Helpers

- `validate_json <file>`: Validate JSON syntax
- `json_has_field <file> <field>`: Check if JSON field exists
- `json_get <file> <field>`: Get JSON field value
- `json_field_has_type <file> <field> <type>`: Check JSON field type
- `is_valid_semver <version>`: Validate semantic version format

### Frontmatter Helpers

- `has_frontmatter_delimiter <file>`: Check for YAML frontmatter delimiter
- `has_frontmatter_field <file> <field>`: Check for frontmatter field

### Plugin Helpers

- `is_valid_plugin_name <name>`: Validate plugin name format
- `for_each_plugin_manifest <callback>`: Iterate over all plugin manifests
- `get_all_plugins()`: Get cached plugin list
- `parse_plugin_json <plugin_path>`: Parse and cache plugin JSON

### Fixture Factory (`tests/helpers/fixture_factory.bash`)

- `create_minimal_plugin <base_dir> <name> [version] [author]`: Create minimal plugin
- `create_full_plugin <base_dir> <name> [version] [author]`: Create complete plugin
- `create_command_file <commands_dir> <name> <description>`: Create command file
- `create_agent_file <agents_dir> <name> <description> [model]`: Create agent file
- `create_skill_file <skills_dir> <name> <description> [content]`: Create skill directory
- `cleanup_fixtures <fixture_root>`: Clean up test fixtures

## CI/CD

Tests run automatically on:

- Pull requests
- Push to main branch
- Releases

See `.github/workflows/` for workflow definitions.

## Pre-commit Hooks

Pre-commit hooks run additional checks:

- YAML validation
- JSON validation
- ShellCheck (shell script linting)
- markdownlint (Markdown linting)

Run pre-commit manually:

```bash
pre-commit run --all-files
```

## Writing New Tests

When adding a new component type or validation:

1. Create a new `.bats` file in `tests/`
2. Source the helper: `load bats_helper.bash`
3. Write test functions using BATS syntax:

```bash
#!/usr/bin/env bats

load helpers/bats_helper

@test "example test" {
    # Arrange
    local result
    result="$(some_function)"

    # Assert
    [ "$result" == "expected" ]
}
```

1. Run the new test to verify it works
2. Update this documentation if needed

## Troubleshooting

### Tests Fail Locally But Pass in CI

- Ensure you're running tests from the repository root
- Check that BATS is installed: `bats --version`
- Try running with verbose output: `bats --verbose tests/`

### YAML Frontmatter Errors

- Ensure proper YAML syntax in frontmatter
- Use `|` or `>` for multi-line values
- Escape special characters properly

### Path Issues

- Use absolute paths in tests
- Use `${CLAUDE_PLUGIN_ROOT}` for portability
- Don't hardcode repository paths

## Plugin Testing

### Directory Structure

All plugins should follow this test structure:

```text
plugins/{plugin-name}/
├── tests/                    # Optional: Test files directory
│   ├── {plugin-name}.bats   # Main plugin test file
│   ├── fixtures/            # Optional: Test fixtures
│   └── helpers/             # Optional: Plugin-specific helpers
└── .claude-plugin/
    └── plugin.json
```

### Using Shared Helpers

Plugin tests can load the root bats_helper:

```bash
#!/usr/bin/env bats
# From plugins/{name}/tests/{name}.bats
load ../../../../tests/helpers/bats_helper

@test "example plugin test" {
    [ -d "${PROJECT_ROOT}" ]
}
```

### Plugin Test Example

```bash
#!/usr/bin/env bats

load ../../../../tests/helpers/bats_helper

@test "plugin directory exists" {
    [ -d "${PROJECT_ROOT}/plugins/my-plugin" ]
}

@test "plugin.json exists" {
    [ -f "${PROJECT_ROOT}/plugins/my-plugin/.claude-plugin/plugin.json" ]
}

@test "plugin.json is valid JSON" {
    validate_json "${PROJECT_ROOT}/plugins/my-plugin/.claude-plugin/plugin.json"
}
```

### Test Naming Conventions

- Main test file: `{plugin-name}.bats`
- Helper tests: `{feature}-helper.bats`
- Component tests: `{component}-test.bats`
- Integration tests: `integration-{feature}.bats`
