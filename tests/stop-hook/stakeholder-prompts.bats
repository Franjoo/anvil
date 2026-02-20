#!/usr/bin/env bats
# Tests for stakeholder-specific prompt construction

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

@test "stakeholder prompt contains next stakeholder name" {
  create_state_file phase="stakeholder" mode="stakeholders" round="1" max_rounds="3" \
    stakeholders="Engineering,Product,Business"
  setup_hook_input "Engineering perspective"
  run_stop_hook
  assert_block_decision
  assert_reason_contains "Product"
}

@test "stakeholder prompt contains stakeholder count" {
  create_state_file phase="stakeholder" mode="stakeholders" round="1" max_rounds="3" \
    stakeholders="Engineering,Product,Business"
  setup_hook_input "Engineering perspective"
  run_stop_hook
  assert_reason_contains "2 of 3"
}

@test "stakeholder system message shows stakeholder name" {
  create_state_file phase="stakeholder" mode="stakeholders" round="1" max_rounds="3" \
    stakeholders="Engineering,Product,Business"
  setup_hook_input "Engineering perspective"
  run_stop_hook
  assert_system_message_contains "STAKEHOLDER"
  assert_system_message_contains "Product"
}

@test "stakeholder transcript labels by stakeholder name" {
  create_state_file phase="stakeholder" mode="stakeholders" round="1" max_rounds="3" \
    stakeholders="Engineering,Product,Business"
  setup_hook_input "Engineering perspective output"
  run_stop_hook
  assert_state_body_contains "## Stakeholder 1: Engineering"
}

@test "stakeholder synthesizer prompt mentions stakeholder simulation" {
  create_state_file phase="stakeholder" mode="stakeholders" round="3" max_rounds="3" \
    stakeholders="Engineering,Product,Business"
  setup_hook_input "Business perspective"
  run_stop_hook
  assert_block_decision
  assert_reason_contains "stakeholder simulation"
}

@test "stakeholder with leading/trailing spaces trimmed" {
  create_state_file phase="stakeholder" mode="stakeholders" round="1" max_rounds="2" \
    stakeholders=" Engineering , Product "
  setup_hook_input "Engineering perspective"
  run_stop_hook
  assert_block_decision
  assert_reason_contains "Product"
}

@test "stakeholder synthesizer system message correct" {
  create_state_file phase="stakeholder" mode="stakeholders" round="3" max_rounds="3" \
    stakeholders="Engineering,Product,Business"
  setup_hook_input "Business perspective"
  run_stop_hook
  assert_system_message_contains "SYNTHESIZER"
}

@test "stakeholder_index updated alongside round" {
  create_state_file phase="stakeholder" mode="stakeholders" round="1" max_rounds="3" \
    stakeholders="Engineering,Product,Business" stakeholder_index="1"
  setup_hook_input "Engineering perspective"
  run_stop_hook
  assert_frontmatter "stakeholder_index" "2"
}

@test "stakeholder_index tracks to 3 on third round" {
  create_state_file phase="stakeholder" mode="stakeholders" round="2" max_rounds="3" \
    stakeholders="Engineering,Product,Business" stakeholder_index="2"
  setup_hook_input "Product perspective"
  run_stop_hook
  assert_frontmatter "stakeholder_index" "3"
}
