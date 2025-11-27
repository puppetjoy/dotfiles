class dotfiles {
  file { "${facts['basedir']}/.config/systemd/user/x-session.target.wants/urxvtd.service":
    ensure => absent,
  }
}
