# frozen_string_literal: true

require 'minitest/autorun'

class AgentRequestFollowthroughSemanticsTest < Minitest::Test
  AGENTS_GUIDE = File.expand_path('../AGENTS.md', __dir__)

  def guide
    @guide ||= File.read(AGENTS_GUIDE)
  end

  def test_review_handoffs_require_explicit_followthrough_mode
    assert_includes guide, 'merge only; no live deploy intended'
    assert_includes guide, 'merge + deploy/apply/refresh and verify live state'
    assert_includes guide, 'merge, then block/ask Joy before deploy/apply/refresh'
  end

  def test_vague_deploy_wording_blocks_for_clarification
    assert_includes guide, 'run any desired dotfiles deployment/apply/refresh'
    assert_match(/block for clarification/i, guide)
  end

  def test_static_file_rendering_and_live_materialization_are_separate
    assert_includes guide, 'Is ERB render/template validation needed for source correctness?'
    assert_includes guide, 'Is live `refresh-dotfiles`/dotfiles deployment needed'
    assert_includes guide, 'Is Puppet or Bolt apply needed on a host?'
    assert_match(/plain tracked file.*not `\*\.erb`.*may still need\s+live dotfiles refresh\/deploy/im, guide)
  end

  def test_canary_regression_case_is_documented
    assert_includes guide, 'ar-20260614-060229-d94936 / t_5727f50d'
    assert_includes guide, 'joy/dotfiles!3'
    assert_includes guide, '.beryl-hello.txt'
    assert_match(/Joy later asked who made that decision/i, guide)
  end
end
