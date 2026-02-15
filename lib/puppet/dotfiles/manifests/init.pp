class dotfiles {
  file { "${facts['basedir']}/.config/systemd/user/x-session.target.wants/urxvtd.service":
    ensure => absent,
  }

  if $facts['os']['family'] == 'windows' {
    $localappdata = $facts['env_localappdata'] ? {
      undef   => "C:/Users/${facts['identity']['user']}/AppData/Local",
      default => $facts['env_localappdata'],
    }

    $windows_terminal_source = "${facts['basedir']}/.config/windows-terminal/settings.json"
    $windows_terminal_paths = [
      "${localappdata}/Microsoft/Windows Terminal/settings.json",
      "${localappdata}/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json",
      "${localappdata}/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json",
    ]
    $windows_terminal_parent_dirs = [
      "${localappdata}/Microsoft/Windows Terminal",
      "${localappdata}/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState",
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
