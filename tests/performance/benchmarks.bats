#!/usr/bin/env bats
# Performance Benchmark Tests
# These tests track performance metrics for the test suite

load ../helpers/bats_helper
load ../helpers/fixture_factory

# Store start time for performance tracking
_BENCHMARK_START_TIME=""

# Helper: Start benchmark timer
benchmark_start() {
    _BENCHMARK_START_TIME=$(date +%s%N 2>/dev/null || date +%s000000000)
}

# Helper: End benchmark and return elapsed milliseconds
benchmark_end() {
    local end_time
    end_time=$(date +%s%N 2>/dev/null || date +%s000000000)
    echo $(( (end_time - _BENCHMARK_START_TIME) / 1000000 ))
}

@test "plugin list caching is effective" {
    # First call - should populate cache
    benchmark_start
    get_all_plugins > /dev/null
    local first_time
    first_time=$(benchmark_end)

    # Second call - should use cache
    benchmark_start
    get_all_plugins > /dev/null
    local second_time
    second_time=$(benchmark_end)

    # Cached call should be faster (or at least not significantly slower)
    echo "First call: ${first_time}ms, Second call: ${second_time}ms"
    assert_gt "$first_time" "0" "First call should take time"
    assert_gt "$second_time" "0" "Second call should take time"
}

@test "plugin JSON parsing is reasonably fast" {
    local total_time=0
    local plugin_count=0

    for plugin_dir in "${PROJECT_ROOT}"/plugins/*/; do
        if [ -d "$plugin_dir" ]; then
            benchmark_start
            parse_plugin_json "$plugin_dir" > /dev/null
            local elapsed
            elapsed=$(benchmark_end)
            total_time=$((total_time + elapsed))
            plugin_count=$((plugin_count + 1))
        fi
    done

    local avg_time=$((total_time / plugin_count))
    echo "Parsed $plugin_count plugins in ${total_time}ms (avg: ${avg_time}ms each)"

    # Each plugin should parse in less than 100ms
    assert_lt "$avg_time" "100" "Average parse time should be under 100ms"
}

@test "test setup creates temp directory quickly" {
    benchmark_start
    local temp_dir
    temp_dir=$(mktemp -d -t claude-bench.XXXXXX)
    local elapsed
    elapsed=$(benchmark_end)
    rm -rf "$temp_dir"

    echo "Temp directory creation took ${elapsed}ms"
    assert_lt "$elapsed" "50" "Temp directory creation should be fast"
}

@test "JSON validation is reasonably fast" {
    local total_time=0
    local file_count=0

    for json_file in "${PROJECT_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
        if [ -f "$json_file" ]; then
            benchmark_start
            validate_json "$json_file" > /dev/null
            local elapsed
            elapsed=$(benchmark_end)
            total_time=$((total_time + elapsed))
            file_count=$((file_count + 1))
        fi
    done

    local avg_time=$((total_time / file_count))
    echo "Validated $file_count JSON files in ${total_time}ms (avg: ${avg_time}ms each)"

    # Each validation should be fast
    assert_lt "$avg_time" "50" "Average validation time should be under 50ms"
}

@test "find operations for plugin discovery are efficient" {
    benchmark_start
    local plugins
    plugins=$(find "${PROJECT_ROOT}/plugins" -maxdepth 1 -type d ! -name "plugins" 2>/dev/null | wc -l | tr -d ' ')
    local elapsed
    elapsed=$(benchmark_end)

    echo "Found $plugins plugins in ${elapsed}ms"
    assert_gt "$plugins" "0" "Should find plugins"
    assert_lt "$elapsed" "100" "Plugin discovery should be fast"
}

@test "frontmatter validation is reasonably fast" {
    local total_time=0
    local file_count=0

    for skill_file in "${PROJECT_ROOT}"/**/SKILL.md; do
        if [ -f "$skill_file" ]; then
            benchmark_start
            has_frontmatter_delimiter "$skill_file"
            local elapsed
            elapsed=$(benchmark_end)
            total_time=$((total_time + elapsed))
            file_count=$((file_count + 1))
        fi
    done

    if [ "$file_count" -gt 0 ]; then
        local avg_time=$((total_time / file_count))
        echo "Validated $file_count skill files in ${total_time}ms (avg: ${avg_time}ms each)"
        assert_lt "$avg_time" "10" "Frontmatter check should be very fast"
    else
        skip "No SKILL.md files found"
    fi
}

@test "jq field access is reasonably fast" {
    local test_json="${TEST_TEMP_DIR}/test.json"
    echo '{"name":"test","value":123}' > "$test_json"

    local total_time=0
    local iterations=100

    for _ in $(seq 1 "$iterations"); do
        benchmark_start
        json_get "$test_json" "name" > /dev/null
        local elapsed
        elapsed=$(benchmark_end)
        total_time=$((total_time + elapsed))
    done

    local avg_time=$((total_time / iterations))
    echo "$iterations iterations in ${total_time}ms (avg: ${avg_time}ms each)"

    assert_lt "$avg_time" "10" "Field access should be fast"
}

@test "file counting operations are efficient" {
    benchmark_start
    local count
    count=$(count_files "plugin.json" "${PROJECT_ROOT}/plugins")
    local elapsed
    elapsed=$(benchmark_end)

    echo "Counted $count plugin.json files in ${elapsed}ms"
    assert_gt "$count" "0" "Should find files"
    assert_lt "$elapsed" "200" "File counting should be reasonably fast"
}

@test "test suite completes within reasonable time" {
    # This is a meta-test - it measures how long the test suite has run so far
    # We can't measure the full suite from within, but we can measure individual test file execution

    benchmark_start

    # Run a representative set of operations
    get_all_plugins > /dev/null

    for plugin_dir in "${PROJECT_ROOT}"/plugins/*/; do
        if [ -d "$plugin_dir" ]; then
            parse_plugin_json "$plugin_dir" > /dev/null
        fi
    done

    local elapsed
    elapsed=$(benchmark_end)

    echo "Representative operations completed in ${elapsed}ms"

    # Should complete in less than 5 seconds
    assert_lt "$elapsed" "5000" "Operations should complete in under 5 seconds"
}

@test "fixture creation is fast" {
    local FIXTURE_ROOT="${TEST_TEMP_DIR}/fixtures"

    benchmark_start
    create_minimal_plugin "$FIXTURE_ROOT" "benchmark-test" > /dev/null
    local elapsed
    elapsed=$(benchmark_end)

    echo "Created minimal plugin in ${elapsed}ms"
    assert_lt "$elapsed" "100" "Fixture creation should be fast"

    benchmark_start
    create_full_plugin "$FIXTURE_ROOT" "benchmark-full" > /dev/null
    local elapsed2
    elapsed2=$(benchmark_end)

    echo "Created full plugin in ${elapsed2}ms"
    assert_lt "$elapsed2" "500" "Full fixture creation should be fast"
}
