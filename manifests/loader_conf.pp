# @summary Manage a loader.conf(5) drop-in file in /boot/loader.conf.d
#
# Writes the settings to /boot/loader.conf.d/<title>.conf. The file is
# managed completely: settings missing from `settings` are removed. The
# loader reads the drop-in files after /boot/loader.conf and before
# /boot/loader.conf.local. Changes take effect on the next boot.
#
# @param ensure
#   Whether the drop-in file should be present or absent.
#
# @param settings
#   Hash of loader variables. Each key is the variable name, each value the
#   value of the variable. `true` and `false` are converted to `YES` and
#   `NO`. The variables are written in sorted order.
#
# @example Limit the ZFS ARC to 8 GB
#   fbsd::loader_conf { 'zfs':
#     settings => {
#       'vfs.zfs.arc.max' => '8G',
#     },
#   }
#
define fbsd::loader_conf (
  Enum['absent', 'present'] $ensure = 'present',
  Hash[Pattern[/\A[A-Za-z0-9_][A-Za-z0-9_.%-]*\z/], Variant[Pattern[/\A[^"\n]*\z/], Integer, Boolean]] $settings = {},
) {
  assert_type(Pattern[/\A[A-Za-z0-9_.-]+\z/], $title)

  $lines = $settings.keys.sort.map |String $setting_name| {
    $setting_value = $settings[$setting_name] ? {
      true    => 'YES',
      false   => 'NO',
      default => String($settings[$setting_name]),
    }
    "${setting_name}=\"${setting_value}\"\n"
  }

  $file_ensure = $ensure ? {
    'present' => file,
    default   => absent,
  }

  file { "/boot/loader.conf.d/${title}.conf":
    ensure  => $file_ensure,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    content => "# This file is managed by Puppet.\n${lines.join}",
  }
}
