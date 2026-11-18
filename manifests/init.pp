# @summary Manage the FreeBSD base system configuration
#
# Creates resources for rc.conf(5) and periodic.conf(5) variables, services,
# kernel modules, sysctl(8) variables, loader.conf(5) settings, network
# interfaces and static routes from hashes, e.g. from Hiera.
#
# @param apply_routing
#   Run `service routing restart` when `defaultrouter` or `ipv6_defaultrouter`
#   changes.
#
# @param bridges
#   Hash of bridge interfaces. Each key is the bridge interface name, each value
#   a hash of parameters for fbsd::bridge.
#
# @param defaultrouter
#   The default IPv4 gateway, set as rc.conf(5) `defaultrouter`.
#
# @param interfaces
#   Hash of network interfaces. Each key is the interface name, each value a hash
#   of parameters for fbsd::interface.
#
# @param ipv6_defaultrouter
#   The default IPv6 gateway, set as rc.conf(5) `ipv6_defaultrouter`.
#
# @param klds
#   Hash of kernel modules to load at boot via `kld_list`.
#   Each key is the module name. Each value is a hash of parameters for
#   fbsd::kld (`ensure`, `load`, `sysctls`).
#
# @param laggs
#   Hash of link aggregation interfaces. Each key is the lagg interface name,
#   each value a hash of parameters for fbsd::lagg.
#
# @param loader_confs
#   Hash of loader.conf(5) drop-in files in /boot/loader.conf.d.
#   Each key is the file name without `.conf`. Each value is a hash of
#   parameters for fbsd::loader_conf (`ensure`, `settings`).
#
# @param loader_settings
#   Hash of single loader.conf(5) variables.
#   Each key is a fbsd_loader title (`name` or `name@target`). Each value is
#   either the value of the variable or a hash of fbsd_loader attributes
#   (`ensure`, `value`, `name`, `target`).
#
# @param periodic_settings
#   Hash of single periodic.conf(5) variables.
#   Each key is a fbsd_sysrc title (`name` or `name@target`). A key without
#   target is managed in /etc/periodic.conf, other files read by periodic(8)
#   are /etc/periodic.conf.local and /usr/local/etc/periodic.conf. Each value
#   is either the value of the variable or a hash of fbsd_sysrc attributes
#   (`ensure`, `value`).
#
# @param rc_settings
#   Hash of single rc.conf(5) style variables or list entries.
#   Each key is a fbsd_sysrc title (`name`, `name@target`, `name+item` or
#   `name+item@target`). Each value is either the value of the variable or a
#   hash of fbsd_sysrc attributes (`ensure`, `item`, `name`, `target`,
#   `value`).
#
# @param routes
#   Hash of static routes. Each key is the route name, each value a hash of
#   parameters for fbsd::route.
#
# @param services
#   Hash of service configurations in /etc/rc.conf.d.
#   Each key is the name of the rc.d script. Each value is a hash of
#   parameters for fbsd::service (`ensure`, `enable`, `enable_variable`,
#   `target`, `variables`).
#
# @param sysctls
#   Hash of sysctl(8) variables.
#   Each key is a fbsd_sysctl title (`name` or `name@target`). Each value is
#   either the value of the variable or a hash of fbsd_sysctl attributes
#   (`apply`, `ensure`, `value`, `name`, `target`).
#
# @param vlans
#   Hash of VLAN interfaces. Each key is the VLAN interface name, each value a
#   hash of parameters for fbsd::vlan.
#
# @example Configure a host with Puppet DSL
#   class { 'fbsd':
#     periodic_settings => {
#       'daily_scrub_zfs_enable' => 'YES',
#     },
#     rc_settings       => {
#       'syslogd_flags' => '-ss',
#     },
#     services          => {
#       'ntpd' => {
#         'enable'    => true,
#         'variables' => {
#           'ntpd_sync_on_start' => true,
#         },
#       },
#     },
#     sysctls           => {
#       'kern.logsigexit' => 0,
#     },
#   }
#
class fbsd (
  Hash $bridges,
  Hash $interfaces,
  Hash $klds,
  Hash $laggs,
  Hash $loader_confs,
  Hash $loader_settings,
  Hash $periodic_settings,
  Hash $rc_settings,
  Hash $routes,
  Hash $services,
  Hash $sysctls,
  Hash $vlans,
  Boolean $apply_routing = true,
  Optional[String[1]] $defaultrouter = undef,
  Optional[String[1]] $ipv6_defaultrouter = undef,
) {
  $klds.each |String $kld_name, Hash $kld_options| {
    fbsd::kld { $kld_name:
      * => $kld_options,
    }
  }

  $loader_confs.each |String $conf_name, Hash $conf_options| {
    fbsd::loader_conf { $conf_name:
      * => $conf_options,
    }
  }

  $loader_settings.each |String $setting_title, $setting_options| {
    $_setting_options = $setting_options ? {
      Hash    => $setting_options,
      default => { 'value' => $setting_options },
    }
    fbsd_loader { $setting_title:
      * => $_setting_options,
    }
  }

  $periodic_settings.each |String $setting_title, $setting_options| {
    $_setting_options = $setting_options ? {
      Hash    => $setting_options,
      default => { 'value' => $setting_options },
    }
    # Titles without target get `@/etc/periodic.conf` to avoid clashes with
    # rc_settings titles.
    $_setting_title = '@' in $setting_title ? {
      true    => $setting_title,
      default => "${setting_title}@/etc/periodic.conf",
    }
    fbsd_sysrc { $_setting_title:
      * => $_setting_options,
    }
  }

  $rc_settings.each |String $setting_title, $setting_options| {
    $_setting_options = $setting_options ? {
      Hash    => $setting_options,
      default => { 'value' => $setting_options },
    }
    fbsd_sysrc { $setting_title:
      * => $_setting_options,
    }
  }

  $services.each |String $service_name, Hash $service_options| {
    fbsd::service { $service_name:
      * => $service_options,
    }
  }

  $sysctls.each |String $sysctl_title, $sysctl_options| {
    $_sysctl_options = $sysctl_options ? {
      Hash    => $sysctl_options,
      default => { 'value' => $sysctl_options },
    }
    fbsd_sysctl { $sysctl_title:
      * => $_sysctl_options,
    }
  }

  $interfaces.each |String $if_name, Hash $if_options| {
    fbsd::interface { $if_name:
      * => $if_options,
    }
  }

  $laggs.each |String $lagg_name, Hash $lagg_options| {
    fbsd::lagg { $lagg_name:
      * => $lagg_options,
    }
  }

  $vlans.each |String $vlan_name, Hash $vlan_options| {
    fbsd::vlan { $vlan_name:
      * => $vlan_options,
    }
  }

  $bridges.each |String $bridge_name, Hash $bridge_options| {
    fbsd::bridge { $bridge_name:
      * => $bridge_options,
    }
  }

  $routes.each |String $route_name, Hash $route_options| {
    fbsd::route { $route_name:
      * => $route_options,
    }
  }

  if $apply_routing and ($defaultrouter or $ipv6_defaultrouter) {
    include fbsd::routing
    $routing_notify = Exec['fbsd routing restart']
  } else {
    $routing_notify = undef
  }

  if $defaultrouter {
    fbsd_sysrc { 'defaultrouter':
      value  => $defaultrouter,
      notify => $routing_notify,
    }
  }

  if $ipv6_defaultrouter {
    fbsd_sysrc { 'ipv6_defaultrouter':
      value  => $ipv6_defaultrouter,
      notify => $routing_notify,
    }
  }

  # cloned_interfaces lists parents before dependents: lagg -> vlan -> bridge.
  Fbsd::Lagg <| |> -> Fbsd::Vlan <| |> -> Fbsd::Bridge <| |>
}
