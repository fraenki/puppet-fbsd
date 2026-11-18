# @summary Manage a FreeBSD static route via rc.conf(5)
#
# Adds the route to `static_routes` (or `ipv6_static_routes`) and writes
# `route_<name>` (or `ipv6_route_<name>`).
#
# @param network
#   The destination network in CIDR notation, e.g. `198.51.100.0/24`.
# @param gateway
#   The gateway address.
# @param ensure
#   Whether the variables should be present or absent.
# @param family
#   Address family of the route.
# @param apply
#   Run `service routing restart` when a variable changes.
# @param target
#   The rc.conf(5) style file that contains the variables.
#
# @example A static route
#   fbsd::route { 'to_dmz':
#     network => '198.51.100.0/24',
#     gateway => '192.0.2.1',
#   }
#
define fbsd::route (
  String[1]                 $network,
  Stdlib::IP::Address       $gateway,
  Enum['present', 'absent'] $ensure  = 'present',
  Enum['inet', 'inet6']     $family  = 'inet',
  Boolean                   $apply   = true,
  Stdlib::Absolutepath      $target  = '/etc/rc.conf',
) {
  $var = regsubst($name, '[./+-]', '_', 'G')
  $list_variable = $family ? {
    'inet6' => 'ipv6_static_routes',
    default => 'static_routes',
  }
  $route_variable = $family ? {
    'inet6' => "ipv6_route_${var}",
    default => "route_${var}",
  }

  $list_entry = "${list_variable}+${name}@${target}"
  $route = "${route_variable}@${target}"

  fbsd_sysrc { $list_entry:
    ensure => $ensure,
  }

  if $ensure == 'absent' {
    fbsd_sysrc { $route:
      ensure => absent,
    }
  } else {
    fbsd_sysrc { $route:
      value => "-net ${network} ${gateway}",
    }
  }

  if $apply {
    include fbsd::routing

    Fbsd_sysrc[$list_entry, $route] ~> Exec['fbsd routing restart']
  }
}
