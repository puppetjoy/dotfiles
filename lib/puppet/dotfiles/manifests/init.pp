class dotfiles {
  file { "${facts['basedir']}/.config/systemd/user/x-session.target.wants/urxvtd.service":
    ensure => absent,
  }

  if $facts['os']['family'] == 'windows' {
    # identity.user may include a machine/domain prefix on Windows (for
    # example "CARACARA\\joy"), so trim everything up to the final slash.
    $windows_username = regsubst($facts['identity']['user'], '.*[\\\\/]', '')
    $localappdata_raw = $facts['env_localappdata'] ? {
      undef   => "C:/Users/${windows_username}/AppData/Local",
      default => $facts['env_localappdata'],
    }
    $localappdata = regsubst($localappdata_raw, '\\\\', '/', 'G')

    $windows_terminal_source = "${facts['basedir']}/.config/windows-terminal/settings.json"
    $windows_terminal_paths = [
      "${localappdata}/Microsoft/Windows Terminal/settings.json",
      "${localappdata}/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json",
      "${localappdata}/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json",
    ]
    $windows_terminal_parent_dirs = [
      "${localappdata}",
      "${localappdata}/Microsoft",
      "${localappdata}/Microsoft/Windows Terminal",
      "${localappdata}/Packages",
      "${localappdata}/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe",
      "${localappdata}/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState",
      "${localappdata}/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe",
      "${localappdata}/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState",
    ]

    file { $windows_terminal_parent_dirs:
      ensure => directory,
    }

    file { $windows_terminal_paths:
      ensure  => file,
      source  => $windows_terminal_source,
      replace => true,
      require => [
        File[$windows_terminal_source],
        File[$windows_terminal_parent_dirs],
      ],
    }
  }
}
