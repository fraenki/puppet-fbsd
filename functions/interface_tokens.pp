# @summary Build the value of an rc.conf(5) `ifconfig_<interface>` variable
#
# @api private
#
# @param prefix
#   Tokens placed before the address, e.g. `laggproto`/`laggport` or `addm`.
# @param method
#   `static` uses `ipaddress`/`netmask`, `dhcp` uses the `DHCP` keyword,
#   `manual` sets no address.
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
#   When false, the `NOAUTO` keyword is added.
#
# @return [String] the ifconfig_<interface> value
function fbsd::interface_tokens(
  Array[String[1]]                                      $prefix,
  Enum['static', 'dhcp', 'manual']                      $method,
  Enum['inet', 'inet6']                                 $family,
  Optional[String[1]]                                   $ipaddress,
  Optional[Variant[Integer[0, 128], Pattern[/\A\d+\z/]]] $netmask,
  Optional[Integer[42, 65536]]                          $mtu,
  Array[String[1]]                                      $options,
  Boolean                                               $onboot,
) >> String {
  if $method == 'static' and $ipaddress and $netmask =~ Undef {
    fail("fbsd::interface_tokens: a static address requires a netmask (got ipaddress ${ipaddress})")
  }

  $address = $method ? {
    'dhcp'   => ['DHCP'],
    'manual' => [],
    default  => $ipaddress ? {
      undef   => [],
      default => ["${family} ${ipaddress}/${netmask}"],
    },
  }
  $mtu_tokens = $mtu ? { undef => [], default => ["mtu ${mtu}"] }
  $keywords = $onboot ? { false => ['NOAUTO'], default => [] }
  $up = ('down' in $options) ? { true => [], default => ['up'] }

  join($prefix + $keywords + $address + $mtu_tokens + $options + $up, ' ')
}
