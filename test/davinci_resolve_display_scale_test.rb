# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'tmpdir'

class DavinciResolveDisplayScaleTest < Minitest::Test
  TEMPLATE = File.expand_path('../.local/bin/ensure-davinci-resolve-display-scale.erb', __dir__)
  MANIFEST = File.expand_path('../lib/puppet/dotfiles/manifests/init.pp', __dir__)

  def setup
    @tmpdir = Dir.mktmpdir
    @helper = File.join(@tmpdir, 'ensure-davinci-resolve-display-scale')
    rendered = ERB.new(File.read(TEMPLATE)).result
    File.write(@helper, rendered)
    FileUtils.chmod(0o700, @helper)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def run_helper(path)
    Open3.capture3(@helper, path)
  end

  def write_config(body, mode: 0o600)
    path = File.join(@tmpdir, 'config.user.xml')
    File.write(path, body)
    FileUtils.chmod(mode, path)
    path
  end

  def test_changes_100_to_200_and_preserves_unrelated_xml_and_mode
    original = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <UserConfig>
        <Unrelated id="stable">keep exactly this</Unrelated>
        <DisplayScale>100</DisplayScale>
        <AnotherPreference enabled="true" />
      </UserConfig>
    XML
    expected = original.sub('<DisplayScale>100</DisplayScale>', '<DisplayScale>200</DisplayScale>')
    path = write_config(original, mode: 0o640)

    _stdout, stderr, status = run_helper(path)

    assert status.success?, stderr
    assert_equal expected, File.binread(path)
    assert_equal 0o640, File.stat(path).mode & 0o777
  end

  def test_already_200_is_idempotent
    contents = '<UserConfig><DisplayScale>200</DisplayScale></UserConfig>'
    path = write_config(contents)
    before = File.stat(path)

    _stdout, stderr, status = run_helper(path)

    assert status.success?, stderr
    assert_equal contents, File.binread(path)
    assert_equal before.ino, File.stat(path).ino
    assert_equal before.mtime, File.stat(path).mtime
  end

  def test_missing_file_is_a_no_op
    path = File.join(@tmpdir, 'missing.xml')

    _stdout, stderr, status = run_helper(path)

    assert status.success?, stderr
    refute_path_exists path
  end

  def test_malformed_xml_fails_closed
    contents = '<UserConfig><DisplayScale>100</DisplayScale>'
    path = write_config(contents)

    _stdout, _stderr, status = run_helper(path)

    refute status.success?
    assert_equal contents, File.binread(path)
  end

  def test_duplicate_display_scale_fails_closed
    contents = '<UserConfig><DisplayScale>100</DisplayScale><DisplayScale>100</DisplayScale></UserConfig>'
    path = write_config(contents)

    _stdout, _stderr, status = run_helper(path)

    refute status.success?
    assert_equal contents, File.binread(path)
  end

  def test_display_scale_text_in_comment_cannot_mask_unsupported_real_element
    contents = '<UserConfig><DisplayScale kind="ui">100</DisplayScale><!-- <DisplayScale>200</DisplayScale> --></UserConfig>'
    path = write_config(contents)

    _stdout, _stderr, status = run_helper(path)

    refute status.success?
    assert_equal contents, File.binread(path)
  end

  def test_symlink_target_fails_closed
    target = write_config('<UserConfig><DisplayScale>100</DisplayScale></UserConfig>')
    link = File.join(@tmpdir, 'linked-config.user.xml')
    File.symlink(target, link)

    _stdout, _stderr, status = run_helper(link)

    refute status.success?
    assert File.symlink?(link)
    assert_equal '<UserConfig><DisplayScale>100</DisplayScale></UserConfig>', File.binread(target)
  end

  def test_successful_change_preserves_target_inode
    path = write_config('<UserConfig><DisplayScale>100</DisplayScale></UserConfig>')
    inode = File.stat(path).ino

    _stdout, stderr, status = run_helper(path)

    assert status.success?, stderr
    assert_equal inode, File.stat(path).ino
  end

  def test_require_stopped_refuses_to_edit_while_resolve_is_running
    contents = '<UserConfig><DisplayScale>100</DisplayScale></UserConfig>'
    path = write_config(contents)
    resolve = File.join(@tmpdir, 'resolve')
    FileUtils.cp('/bin/sleep', resolve)
    pid = Process.spawn(resolve, '10')
    100.times do
      break if File.read("/proc/#{pid}/comm").chomp.casecmp('resolve').zero?

      sleep 0.01
    end

    _stdout, _stderr, status = Open3.capture3(@helper, '--require-stopped', path)

    refute status.success?
    assert_equal contents, File.binread(path)
  ensure
    Process.kill('TERM', pid) if pid
    Process.wait(pid) if pid
  end

  def test_manifest_runs_helper_only_for_linux_existing_config_and_stopped_resolve
    manifest = File.read(MANIFEST)

    assert_includes manifest, "if $facts['kernel'] == 'Linux'"
    assert_includes manifest, 'ensure-davinci-resolve-display-scale'
    assert_includes manifest, '.local/share/DaVinciResolve/configs/config.user.xml'
    assert_match(/File <\| title == \$resolve_scale_helper \|> \{\s+mode => '0700'/m, manifest)
    assert_includes manifest, "command => [$resolve_scale_helper, '--require-stopped', $resolve_config]"
    refute_match(/\b(?:onlyif|unless)\s+=>/, manifest)
  end
end
