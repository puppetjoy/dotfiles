class dotfiles {
  if $facts['kernel'] == 'Linux' {
    $resolve_config = "${facts['basedir']}/.local/share/DaVinciResolve/configs/config.user.xml"
    $resolve_scale_helper = "${facts['basedir']}/.local/bin/ensure-davinci-resolve-display-scale"

    File <| title == $resolve_scale_helper |> {
      mode => '0700',
    }

    exec { 'ensure-davinci-resolve-display-scale':
      command => [$resolve_scale_helper, '--require-stopped', $resolve_config],
      require => File[$resolve_scale_helper],
    }
  }
}
