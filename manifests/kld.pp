# @summary Load a kernel module at boot via kld_list
#
# Adds the module to `kld_list` in /etc/rc.conf with `sysrc kld_list+=`,
# other entries of `kld_list` stay in place. Optionally loads the module
# right away and manages its sysctl(8) variables in
# /etc/sysctl.kld.d/<module>.conf, which are applied at boot after the
# module is loaded.
#
# @param ensure
#   Whether the module should be loaded at boot. With `absent`, the module
#   is removed from `kld_list` and the variables in `sysctls` are removed.
#   The module is not unloaded.
#
# @param load
#   Whether the module should be loaded immediately with kldload(8) if it
#   is not loaded yet.
#
# @param sysctls
#   Hash of module-specific sysctl(8) variables. Each key is the variable
#   name, each value the value of the variable. The values are also set in
#   the running kernel when the module is loaded.
#
# @example Load if_bridge with packet filtering on member interfaces
#   fbsd::kld { 'if_bridge':
#     sysctls => {
#       'net.link.bridge.pfil_bridge' => 0,
#       'net.link.bridge.pfil_member' => 1,
#     },
#   }
#
define fbsd::kld (
  Enum['absent', 'present'] $ensure = 'present',
  Boolean $load = true,
  Hash[Pattern[/\A[A-Za-z0-9_][A-Za-z0-9_.%-]*\z/], Variant[String, Integer]] $sysctls = {},
) {
  # kld_list takes module names without path and without .ko extension.
  assert_type(Pattern[/\A[A-Za-z0-9][A-Za-z0-9_.-]*\z/], $title)
  if $title =~ /\.ko\z/ {
    fail("fbsd::kld: '${title}' must be a module name without .ko extension")
  }

  fbsd_sysrc { "kld_list+${title}":
    ensure => $ensure,
  }

  if $ensure == 'present' and $load {
    exec { "kldload ${title}":
      command => "/sbin/kldload -n ${title}",
      unless  => [
        "/sbin/kldstat -q -m ${title}",
        "/sbin/kldstat -q -n ${title}",
      ],
    }
    $sysctl_require = Exec["kldload ${title}"]
  } else {
    $sysctl_require = undef
  }

  $sysctls.each |String $sysctl_name, $sysctl_value| {
    fbsd_sysctl { "${sysctl_name}@/etc/sysctl.kld.d/${title}.conf":
      ensure  => $ensure,
      value   => $sysctl_value,
      require => $sysctl_require,
    }
  }
}
