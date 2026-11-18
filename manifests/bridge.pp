# @summary Manage a FreeBSD bridge interface via rc.conf(5)
#
# Adds the bridge to `cloned_interfaces` and writes its `ifconfig_<bridge>`
# with the member interfaces (`addm`) and address.
#
# @param members
#   The interfaces to add to the bridge.
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
#   Run `service netif restart <bridge>` and `service routing restart` when a
#   variable changes or when Puppet restarts a lagg, VLAN or bridge given in
#   `members`. Not done for a bridge with `onboot => false`. With
#   `ensure => absent`, the bridge is stopped with `service netif stop` before
#   its variables are removed.
# @param target
#   The rc.conf(5) style file that contains the variables.
#
# @example A bridge over two interfaces
#   fbsd::bridge { 'bridge0':
#     members => ['em0', 'em1'],
#   }
#
define fbsd::bridge (
  Array[String[1]]                                       $members   = [],
  Enum['present', 'absent']                              $ensure    = 'present',
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
  $prefix = $members.map |$member| { "addm ${member}" }
  $clone = "cloned_interfaces+${name}@${target}"
  $ifconfig = "ifconfig_${var}@${target}"

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

  if $apply {
    $variables = Fbsd_sysrc[$clone, $ifconfig]

    if $ensure == 'absent' {
      include fbsd::routing

      # Stops and destroys the bridge while its configuration still exists.
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

      # Destroying a cloned member removes it from the bridge.
      $members.each |String[1] $member| {
        Exec <| title == "fbsd netif restart ${member}" and tag == 'fbsd_netif_clone' |> ~> Exec["fbsd netif restart ${name}"]
      }
    }
  }
}
