#!/usr/bin/env bats
# Tests for generate-report.mjs (markdown → HTML conversion)

load "../helpers/setup"

REPORT_SCRIPT="${PLUGIN_ROOT}/scripts/generate-report.mjs"

setup() {
  if ! command -v bun >/dev/null 2>&1; then
    skip "bun not available"
  fi
  setup_test_dir
}

run_report() {
  run bash -c 'printf "%s" "$1" | bun "$2"' _ "$1" "$REPORT_SCRIPT"
}

@test "outputs DOCTYPE html" {
  run_report "# Hello"
  assert_success
  assert_output --partial "<!DOCTYPE html>"
}

@test "renders h1 heading" {
  run_report "# My Title"
  assert_success
  assert_output --partial "<h1>My Title</h1>"
}

@test "renders h2 heading" {
  run_report "## Section"
  assert_success
  assert_output --partial "<h2>Section</h2>"
}

@test "renders h3 heading" {
  run_report "### Subsection"
  assert_success
  assert_output --partial '<h3 id="subsection">Subsection</h3>'
}

@test "renders bold as strong" {
  run_report "This is **bold** text"
  assert_success
  assert_output --partial "<strong>bold</strong>"
}

@test "renders italic as em" {
  run_report "This is *italic* text"
  assert_success
  assert_output --partial "<em>italic</em>"
}

@test "renders links as anchor tags" {
  run_report "Visit [Example](https://example.com) now"
  assert_success
  assert_output --partial '<a href="https://example.com">Example</a>'
}

@test "renders blockquotes" {
  run_report "> This is a quote"
  assert_success
  assert_output --partial "<blockquote>"
}

@test "renders tables" {
  local md="| Col A | Col B |
| --- | --- |
| val1 | val2 |"
  run_report "$md"
  assert_success
  assert_output --partial "<table>"
  assert_output --partial "<th>Col A</th>"
  assert_output --partial "<td>val1</td>"
}

@test "Executive Summary gets executive-summary class" {
  local md="## Executive Summary

This is the summary.

## Next Section"
  run_report "$md"
  assert_success
  assert_output --partial 'class="executive-summary"'
}

@test "extracts title from h1 for page title" {
  run_report "# Anvil Analysis: Test Question"
  assert_success
  assert_output --partial "<title>Anvil Analysis: Test Question</title>"
}

@test "renders inline code" {
  run_report "Use \`foo()\` here"
  assert_success
  assert_output --partial "<code>foo()</code>"
}

@test "renders unordered lists" {
  local md="- item one
- item two"
  run_report "$md"
  assert_success
  assert_output --partial "<ul>"
  assert_output --partial "<li>item one</li>"
}

@test "renders ordered lists" {
  local md="1. first
2. second"
  run_report "$md"
  assert_success
  assert_output --partial "<ol>"
  assert_output --partial "<li>first</li>"
}

@test "renders horizontal rules" {
  run_report "---"
  assert_success
  assert_output --partial "<hr>"
}

@test "self-contained with embedded CSS" {
  run_report "# Test"
  assert_success
  assert_output --partial "<style>"
  assert_output --partial "</style>"
}

@test "escapes HTML entities in text" {
  run_report "This has <script>alert(1)</script> in it"
  assert_success
  assert_output --partial "&lt;script&gt;"
  refute_output --partial "<script>alert"
}

@test "escapes HTML in headings" {
  run_report "# Title with <b>html</b>"
  assert_success
  assert_output --partial "&lt;b&gt;"
}

@test "sanitizes javascript: URLs in links" {
  run_report '[click](javascript:alert(1))'
  assert_success
  assert_output --partial "#blocked"
  refute_output --partial "javascript:"
}

@test "reads from file argument" {
  local md_file="${TEST_DIR}/input.md"
  printf '# File Input Test\n\nContent here.' > "$md_file"
  run bun "$REPORT_SCRIPT" "$md_file"
  assert_success
  assert_output --partial "<h1>File Input Test</h1>"
}
