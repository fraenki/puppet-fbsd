# @summary Manage the rc.conf(5) variables of a service in /etc/rc.conf.d
#
# Writes the variables of a service, including its enable variable, to
# /etc/rc.conf.d/<service>, which only the rc.d script of that service
# reads. Each variable is a separate fbsd_sysrc resource.
#
# @param enable
#   Whether the service should be started at boot. Sets the enable variable
#   to `YES` or `NO`. Leave undefined to not manage the enable variable.
#
# @param enable_variable
#   The name of the enable variable (`rcvar`) of the rc.d script.
#
# @param ensure
#   Whether the variables should be present or absent. With `absent`, the
#   enable variable and all variables in `variables` are removed.
#
# @param target
#   The file that contains the variables.
#
# @param variables
#   Hash of variables to set, e.g. `<service>_flags`. Each key is the
#   variable name, each value the value of the variable. `true` and `false`
#   are converted to `YES` and `NO`.
#
# @example Start ntpd at boot and sync the time on startup
#   fbsd::service { 'ntpd':
#     enable    => true,
#     variables => {
#       'ntpd_sync_on_start' => true,
#     },
#   }
#   ~> service { 'ntpd':
#     ensure => running,
#   }
#
define fbsd::service (
  Optional[Boolean] $enable = undef,
  Pattern[/\A[A-Za-z_][A-Za-z0-9_]*\z/] $enable_variable = "${title}_enable",
  Enum['absent', 'present'] $ensure = 'present',
  Stdlib::Absolutepath $target = "/etc/rc.conf.d/${title}",
  Hash[Pattern[/\A[A-Za-z_][A-Za-z0-9_]*\z/], Variant[String, Integer, Boolean]] $variables = {},
) {
  if $ensure == 'absent' {
    fbsd_sysrc { "${enable_variable}@${target}":
      ensure => absent,
    }
  } elsif $enable =~ Boolean {
    fbsd_sysrc { "${enable_variable}@${target}":
      ensure => present,
      value  => $enable,
    }
  }

  $variables.each |String $variable_name, $variable_value| {
    fbsd_sysrc { "${variable_name}@${target}":
      ensure => $ensure,
      value  => $variable_value,
    }
  }
}
