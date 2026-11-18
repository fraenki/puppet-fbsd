# @summary Manage a FreeBSD link aggregation interface via rc.conf(5)
#
# Adds the lagg to `cloned_interfaces` and writes its `ifconfig_<lagg>`
# (protocol, ports and address) and `ifconfig_<member>="up"` for each member.
#
# @param members
#   The physical member interfaces.
# @param ensure
#   Whether the variables should be present or absent.
# @param laggproto
#   The aggregation protocol.
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
#   Run `service netif restart <lagg>` and `service routing restart` when a
#   variable changes. Not done for a lagg with `onboot => false`. With
#   `ensure => absent`, the lagg is stopped with `service netif stop` before
#   its variables are removed.
# @param target
#   The rc.conf(5) style file that contains the variables.
#
# @example A failover lagg over two NICs
#   fbsd::lagg { 'lagg0':
#     members   => ['em0', 'em1'],
#     ipaddress => '192.0.2.10',
#     netmask   => 24,
#   }
#
define fbsd::lagg (
  Array[String[1], 1]                                    $members,
  Enum['present', 'absent']                              $ensure    = 'present',
  Enum['failover', 'lacp', 'loadbalance', 'roundrobin', 'broadcast', 'none'] $laggproto = 'failover',
  Enum['static', 'dhcp', 'manual']                       $method    = 'static',
  Enum['inet', 'inet6']                                  $family    = 'inet',
  Optional[String[1]]                                    $ipaddress = undef,
  Optional[Variant[Integer[0, 128], Pattern[/\A\d+\z/]]] $netmask   = undef,
  Optional[Integer[42, 65536]]                           $mtu       = undef,
  Array[String[1]]                                       $options   = [],
  Boolean                                                $onboot    = true,
  Boolean                                                $apply     = true,
  Stdlib::Absolutepath                                   $target    = '/etc/rc.conf',
) {
  $var = regsubst($name, '[./+-]', '_', 'G')
  $prefix = ["laggproto ${laggproto}"] + $members.map |$member| { "laggport ${member}" }
  $clone = "cloned_interfaces+${name}@${target}"
  $ifconfig = "ifconfig_${var}@${target}"
  $member_titles = $members.map |String[1] $member| { "ifconfig_${regsubst($member, '[./+-]', '_', 'G')}@${target}" }

  fbsd_sysrc { $clone:
    ensure => $ensure,
  }

  if $ensure == 'absent' {
    fbsd_sysrc { $ifconfig:
      ensure => absent,
    }
  } else {
    fbsd_sysrc { $ifconfig:
      value => fbsd::interface_tokens($prefix, $method, $family, $ipaddress, $netmask, $mtu, $options, $onboot),
    }
  }

  fbsd_sysrc { $member_titles:
    ensure => $ensure,
    value  => 'up',
  }

  if $apply {
    $variables = Fbsd_sysrc[[$clone, $ifconfig] + $member_titles]

    if $ensure == 'absent' {
      include fbsd::routing

      # Stops and destroys the lagg while its configuration still exists.
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
        tag         => 'fbsd_netif_clone',
        notify      => Exec['fbsd routing restart'],
      }
      $variables ~> Exec["fbsd netif restart ${name}"]
    }
  }
}
