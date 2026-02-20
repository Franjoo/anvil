#!/usr/bin/env bats
# Static analysis of all Anvil shell scripts

load "../helpers/setup"

@test "shellcheck: setup-anvil.sh passes" {
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi
  run shellcheck -s bash "$SETUP_SCRIPT"
  assert_success
}

@test "shellcheck: stop-hook.sh passes" {
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi
  run shellcheck -s bash "$STOP_HOOK"
  assert_success
}
