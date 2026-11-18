# @summary Restart the routing service once per run
#
# Declares the refresh-only exec that runs `service routing restart`, which
# flushes the routing table and adds `defaultrouter`, `ipv6_defaultrouter`,
# `static_routes` and `ipv6_static_routes` again.
#
# @api private
#
class fbsd::routing {
  assert_private()

  exec { 'fbsd routing restart':
    command     => '/usr/sbin/service routing restart',
    refreshonly => true,
  }
}
