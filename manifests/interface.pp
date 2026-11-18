# @summary Manage a FreeBSD network interface via rc.conf(5)
#
# Writes `ifconfig_<interface>`, its aliases and `ifconfig_<interface>_ipv6`.
# The interface name is translated for the variable name: `.-/+` become `_`
# (`em0.102` -> `ifconfig_em0_102`).
#
# @param ensure
#   Whether the variables should be present or absent.
# @param method
#   `static`, `dhcp` or `manual` addressing.
# @param family
#   Address family for a static address.
# @param ipaddress
#   The static address, without prefix length.
# @param netmask
#   The prefix length for the static address.
# @param mtu
#   The interface MTU.
# @param options
#   Extra ifconfig(8) arguments.
# @param onboot
#   When false, the interface is configured but not started at boot (`NOAUTO`).
# @param apply
#   Run `service netif restart <interface>` and `service routing restart` when
#   a variable changes. Not done for an interface with `onboot => false`. With
#   `ensure => absent`, the interface is stopped with `service netif stop`
#   before its variables are removed.
# @param ipv6_auto
#   Accept IPv6 router advertisements (SLAAC) via `ifconfig_<interface>_ipv6`.
# @param aliases
#   IP alias entries, each a full ifconfig(8) argument such as
#   `inet 192.0.2.5/32`.
# @param target
#   The rc.conf(5) style file that contains the variables.
#
# @example A static interface
#   fbsd::interface { 'em0':
#     ipaddress => '192.0.2.10',
#     netmask   => 24,
#   }
#
define fbsd::interface (
  Enum['present', 'absent']                              $ensure    = 'present',
  Enum['static', 'dhcp', 'manual']                       $method    = 'static',
  Enum['inet', 'inet6']                                  $family    = 'inet',
  Optional[String[1]]                                    $ipaddress = undef,
  Optional[Variant[Integer[0, 128], Pattern[/\A\d+\z/]]] $netmask   = undef,
  Optional[Integer[42, 65536]]                           $mtu       = undef,
  Array[String[1]]                                       $options   = [],
  Boolean                                                $onboot    = true,
  Boolean                                                $apply     = true,
  Boolean                                                $ipv6_auto = false,
  Array[String[1]]                                       $aliases   = [],
  Stdlib::Absolutepath                                   $target    = '/etc/rc.conf',
) {
  $var = regsubst($name, '[./+-]', '_', 'G')
  $ifconfig = "ifconfig_${var}@${target}"
  $ipv6 = $ipv6_auto ? {
    true    => ["ifconfig_${var}_ipv6@${target}"],
    default => [],
  }
  $alias_titles = $aliases.map |Integer $index, String[1] $alias| { "ifconfig_${var}_alias${index}@${target}" }

  if $ensure == 'absent' {
    fbsd_sysrc { $ifconfig:
      ensure => absent,
    }
  } else {
    fbsd_sysrc { $ifconfig:
      value => fbsd::interface_tokens([], $method, $family, $ipaddress, $netmask, $mtu, $options, $onboot),
    }
  }

  $ipv6.each |String[1] $ipv6_title| {
    fbsd_sysrc { $ipv6_title:
      ensure => $ensure,
      value  => 'inet6 accept_rtadv',
    }
  }

  $aliases.each |Integer $index, String[1] $alias| {
    fbsd_sysrc { $alias_titles[$index]:
      ensure => $ensure,
      value  => $alias,
    }
  }

  if $apply {
    $variables = Fbsd_sysrc[[$ifconfig] + $ipv6 + $alias_titles]

    if $ensure == 'absent' {
      include fbsd::routing

      # Stops the interface while its configuration still exists.
      exec { "fbsd netif stop ${name}":
        command => "/usr/sbin/service netif stop ${name}",
        onlyif  => "/usr/sbin/sysrc -c -f ${target} ifconfig_${var}",
        before  => $variables,
      }
      $variables ~> Exec['fbsd routing restart']
    } elsif $onboot {
      include fbsd::routing

      exec { "fbsd netif restart ${name}":
        command     => "/usr/sbin/service netif restart ${name}",
        refreshonly => true,
        notify      => Exec['fbsd routing restart'],
      }
      $variables ~> Exec["fbsd netif restart ${name}"]
    }
  }
}
