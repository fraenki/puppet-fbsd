# @summary Manage a FreeBSD VLAN interface via rc.conf(5)
#
# Adds the VLAN to `cloned_interfaces`, sets `create_args_<vlan>` with tag and
# parent and writes the address in `ifconfig_<vlan>`.
#
# @param vlan_id
#   The 802.1Q VLAN tag.
# @param vlandev
#   The parent interface the VLAN is attached to.
# @param ensure
#   Whether the variables should be present or absent.
# @param pcp
#   The 802.1p priority code point.
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
#   Run `service netif restart <vlan>` and `service routing restart` when a
#   variable changes or when Puppet restarts a lagg, VLAN or bridge given as
#   `vlandev`. Not done for a VLAN with `onboot => false`. With
#   `ensure => absent`, the VLAN is stopped with `service netif stop` before
#   its variables are removed.
# @param target
#   The rc.conf(5) style file that contains the variables.
#
# @example A VLAN on a lagg
#   fbsd::vlan { 'vlan10':
#     vlan_id   => 10,
#     vlandev   => 'lagg0',
#     ipaddress => '192.0.2.10',
#     netmask   => 24,
#   }
#
define fbsd::vlan (
  Integer[1, 4094]                                       $vlan_id,
  String[1]                                              $vlandev,
  Enum['present', 'absent']                              $ensure    = 'present',
  Optional[Integer[0, 7]]                                $pcp       = undef,
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
  $create_args = $pcp ? {
    undef   => "vlan ${vlan_id} vlandev ${vlandev}",
    default => "vlan ${vlan_id} vlandev ${vlandev} vlanpcp ${pcp}",
  }
  $clone = "cloned_interfaces+${name}@${target}"
  $create = "create_args_${var}@${target}"
  $ifconfig = "ifconfig_${var}@${target}"

  fbsd_sysrc { $clone:
    ensure => $ensure,
  }

  if $ensure == 'absent' {
    fbsd_sysrc { [$create, $ifconfig]:
      ensure => absent,
    }
  } else {
    fbsd_sysrc { $create:
      value => $create_args,
    }

    fbsd_sysrc { $ifconfig:
      value => fbsd::interface_tokens([], $method, $family, $ipaddress, $netmask, $mtu, $options, $onboot),
    }
  }

  if $apply {
    $variables = Fbsd_sysrc[$clone, $create, $ifconfig]

    if $ensure == 'absent' {
      include fbsd::routing

      # Stops and destroys the VLAN while its configuration still exists.
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

      # Destroying a cloned parent detaches the VLAN, netif start does not
      # attach an existing VLAN again.
      Exec <| title == "fbsd netif restart ${vlandev}" and tag == 'fbsd_netif_clone' |> ~> Exec["fbsd netif restart ${name}"]
    }
  }
}
