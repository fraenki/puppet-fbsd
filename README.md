# puppet-fbsd

#### Table of Contents

1. [Overview](#overview)
1. [Design](#design)
1. [Requirements](#requirements)
1. [Usage](#usage)
    - [Basic usage](#basic-usage)
    - [Managing rc.conf variables](#managing-rcconf-variables)
    - [Managing network configuration](#managing-network-configuration)
    - [Configuring services](#configuring-services)
    - [Loading kernel modules](#loading-kernel-modules)
    - [Managing sysctl variables](#managing-sysctl-variables)
    - [Managing loader.conf](#managing-loaderconf)
    - [Managing periodic.conf](#managing-periodicconf)
    - [Using types directly](#using-types-directly)
    - [Importing an existing configuration](#importing-an-existing-configuration)
1. [Limitations](#limitations)
1. [Reference](#reference)
1. [Development](#development)
    - [Contributing](#contributing)
1. [License](#license)

## Overview

A Puppet module to manage the configuration of the FreeBSD base system: rc.conf(5) variables, service settings in `/etc/rc.conf.d`, kernel modules in `kld_list`, sysctl(8) variables, loader.conf(5) settings, periodic.conf(5) settings, network interfaces and static routes.

It is the FreeBSD counterpart to [puppet-systemd](https://github.com/voxpupuli/puppet-systemd) and covers parts of the base system that the built-in types don't handle. Packages, users, groups and service state are left to the built-in types.

Functionality that is already provided by other modules for FreeBSD is intentionally not covered.

The module provides the following resource types and defined types:

| Type | Manages |
|------|---------|
| `fbsd_sysrc` | A variable or a single entry of a list variable in `/etc/rc.conf`, `/etc/rc.conf.local`, `/etc/rc.conf.d/*`, `/etc/periodic.conf`, `/etc/periodic.conf.local` or any other rc.conf(5) style file, using sysrc(8) |
| `fbsd_sysctl` | A variable in `/etc/sysctl.conf`, `/etc/sysctl.conf.local` or `/etc/sysctl.kld.d/<module>.conf`, and its value in the running kernel |
| `fbsd_loader` | A variable in `/boot/loader.conf`, `/boot/loader.conf.local` or `/boot/loader.conf.d/<name>.conf` |
| `fbsd::service` | The variables of a service in `/etc/rc.conf.d/<service>`, including its enable variable |
| `fbsd::kld` | A kernel module in `kld_list`, its module-specific sysctl(8) variables, and loading it immediately |
| `fbsd::loader_conf` | A drop-in file in `/boot/loader.conf.d` |
| `fbsd::interface` | A network interface via `ifconfig_<interface>`, its aliases and IPv6 autoconfiguration |
| `fbsd::lagg` | A link aggregation via `cloned_interfaces` and `ifconfig_<lagg>` |
| `fbsd::vlan` | A VLAN interface via `cloned_interfaces`, `create_args_<vlan>` and `ifconfig_<vlan>` |
| `fbsd::bridge` | A bridge via `cloned_interfaces` and `ifconfig_<bridge>` |
| `fbsd::route` | A static route via `static_routes`/`ipv6_static_routes` and `route_<name>` |

## Design

- One resource per variable, no templates. Entries written by bsdinstall(8), `sysrc` or other modules stay in place
- rc.conf(5) style files are edited with sysrc(8), which updates assignments in place and checks the syntax before writing
- sysctl.conf(5) and loader.conf(5) are edited by the module itself, sysrc(8) can't handle dotted names

## Usage

### Basic usage

The `fbsd` class does nothing until resources are added to its parameters:

```puppet
include fbsd
```

All parameters can be set in Hiera. Variables that only need a value can be written as `title: value`, all other attributes are passed as a hash. Hiera data for a bridge host that synchronizes its time with ntpd:

```yaml
fbsd::klds:
  if_bridge:
    sysctls:
      net.link.bridge.pfil_bridge: 0
      net.link.bridge.pfil_member: 1
fbsd::loader_confs:
  zfs:
    settings:
      vfs.zfs.arc.max: '8G'
fbsd::loader_settings:
  autoboot_delay: 3
fbsd::periodic_settings:
  daily_output: '/var/log/daily.log'
  daily_scrub_zfs_enable: 'YES'
fbsd::rc_settings:
  cloned_interfaces: 'bridge0'
  ifconfig_bridge0: 'addm em0 addm em1 up'
  syslogd_flags: '-ss'
fbsd::services:
  ntpd:
    enable: true
    variables:
      ntpd_sync_on_start: true
fbsd::sysctls:
  kern.ipc.somaxconn@/etc/sysctl.conf.local: 1024
  kern.logsigexit: 0
```

The hashes are deep-merged across the Hiera hierarchy.

### Managing rc.conf variables

rc.conf(5) variables can be managed via the `rc_settings` parameter or directly via the `fbsd_sysrc` type:

```puppet
class { 'fbsd':
  rc_settings => {
    'cloned_interfaces' => 'bridge0',
    'ifconfig_bridge0'  => 'addm em0 addm em1 up',
    'syslogd_flags'     => '-ss',
  },
}
```

`fbsd_sysrc` uses sysrc(8) to read (`-F`, `-n`), set (`name=value`) and remove (`-x`) a variable.

The title has the form `name` or `name@target`. Without a target, the variable is managed in `/etc/rc.conf`. Use a target for host-specific values in `/etc/rc.conf.local` or for other files with the same syntax:

```puppet
class { 'fbsd':
  rc_settings => {
    'hostname@/etc/rc.conf.local' => 'node1.example.com',
  },
}
```

`true` and `false` are converted to `YES` and `NO`.

With `+item` in the title, a single entry of a list variable is managed instead of the whole value. It is added with `sysrc name+=item` and removed with `sysrc name-=item`:

```puppet
class { 'fbsd':
  rc_settings => {
    'cloned_interfaces+bridge0' => { 'ensure' => 'present' },
  },
}
```

### Managing network configuration

Interfaces, link aggregations, VLANs, bridges and static routes can be managed via the `interfaces`, `laggs`, `vlans`, `bridges` and `routes` parameters or directly via the matching defined types:

```puppet
fbsd::lagg { 'lagg0':
  members => ['em0', 'em1'],
}

fbsd::vlan { 'vlan10':
  vlan_id   => 10,
  vlandev   => 'lagg0',
  ipaddress => '192.0.2.10',
  netmask   => 24,
}

fbsd::route { 'to_dmz':
  network => '198.51.100.0/24',
  gateway => '192.0.2.1',
}

class { 'fbsd':
  defaultrouter => '192.0.2.1',
}
```

This sets `cloned_interfaces` to `lagg0 vlan10`, `ifconfig_lagg0="laggproto failover laggport em0 laggport em1 up"` with `ifconfig_em0="up"` and `ifconfig_em1="up"`, `create_args_vlan10="vlan 10 vlandev lagg0"` with `ifconfig_vlan10="inet 192.0.2.10/24 up"`, and the route in `static_routes`/`route_to_dmz`.

The VLAN tag and parent go to `create_args_<vlan>`, the address to `ifconfig_<vlan>`. When the `fbsd` class is declared, `cloned_interfaces` is ordered so that a lagg is created before a VLAN on it and a VLAN before a bridge that uses it.

Addresses use slash notation for both `inet` and `inet6`. `fbsd::interface` also takes `method => 'dhcp'`, `mtu`, `options`, `onboot => false` (`NOAUTO`), `aliases` and `ipv6_auto` for `inet6 accept_rtadv`. Interface names are translated for the variable name, where `.`, `-`, `/` and `+` become `_` (`em0.102` becomes `ifconfig_em0_102`), while `vlandev`, `laggport`, `addm` and `cloned_interfaces` keep the real name.

Changes are applied right away with `service netif restart <interface>` for each changed interface, followed by a single `service routing restart`. A VLAN or bridge is restarted as well when Puppet restarts the lagg, VLAN or bridge it is attached to. Interfaces with `onboot => false` are not restarted. With `ensure => absent`, the interface is stopped before its variables are removed. Restarting the interface that carries the connection to the Puppet server interrupts the connection until the interface is up again. To only write the variables, set `apply => false` on the defined types and `apply_routing => false` on the `fbsd` class.

### Configuring services

The variables of a service can be managed in its own file `/etc/rc.conf.d/<service>` via the `services` parameter or directly via the `fbsd::service` defined type. Only the rc.d script of that service reads this file:

```puppet
fbsd::service { 'ntpd':
  enable    => true,
  variables => {
    'ntpd_sync_on_start' => true,
  },
}
~> service { 'ntpd':
  ensure => running,
}
```

This creates `/etc/rc.conf.d/ntpd` with `ntpd_enable="YES"` and `ntpd_sync_on_start="YES"` and restarts ntpd when a variable changes.

The built-in `service` type only manages `<service>_enable` on FreeBSD, has no `flags` support there and only recognizes `YES` in upper case. `fbsd::service` handles any service variable, e.g. `<service>_flags`, `<service>_user` or `<service>_env` (see rc.subr(8)). If `enable` is set here, don't set it on the `service` resource as well.

The name of the enable variable defaults to `<title>_enable`. If the rc.d script uses a different `rcvar`, set `enable_variable`. With `ensure => absent`, the enable variable and all listed variables are removed.

### Loading kernel modules

Kernel modules can be loaded at boot via the `klds` parameter or directly via the `fbsd::kld` defined type:

```puppet
fbsd::kld { 'if_bridge':
  sysctls => {
    'net.link.bridge.pfil_bridge' => 0,
    'net.link.bridge.pfil_member' => 1,
  },
}
```

The module is added to `kld_list` in `/etc/rc.conf` with `sysrc kld_list+=if_bridge`. It is loaded right away with `kldload -n` unless it is already loaded (`load => false` disables this). The sysctl variables go to `/etc/sysctl.kld.d/if_bridge.conf`, which is applied at boot right after the module is loaded, and are also set in the running kernel. `/etc/sysctl.conf` may be processed before the module is loaded (see BUGS in sysctl.conf(5)).

With `ensure => absent`, the module is removed from `kld_list` (`sysrc kld_list-=if_bridge`) and the variables are removed. The module is not unloaded.

### Managing sysctl variables

sysctl(8) variables can be managed via the `sysctls` parameter or directly via the `fbsd_sysctl` type. The value is written to `/etc/sysctl.conf` and set in the running kernel if it differs:

```puppet
class { 'fbsd':
  sysctls => {
    'kern.logsigexit'                           => 0,
    'kern.ipc.somaxconn@/etc/sysctl.conf.local' => 1024,
  },
}
```

The live value is checked on every run, manual changes are reverted.

Some variables cannot be changed at runtime, and some are reported in a different format than they are configured. For such variables, set `apply` to `false` to only manage the file:

```puppet
fbsd_sysctl { 'kern.ipc.somaxconn':
  value => 1024,
  apply => false,
}
```

### Managing loader.conf

Settings that must be present at boot (loader tunables and kernel modules loaded by the loader) are managed in loader.conf(5). Complete sets of settings can be managed as drop-in files in `/boot/loader.conf.d` via the `loader_confs` parameter or directly via the `fbsd::loader_conf` defined type:

```puppet
fbsd::loader_conf { 'zfs':
  settings => {
    'vfs.zfs.arc.max' => '8G',
  },
}
```

This creates `/boot/loader.conf.d/zfs.conf` with `vfs.zfs.arc.max="8G"`. The file is managed completely, settings missing from `settings` are removed.

`loader_settings` and `fbsd_loader` change single variables in `/boot/loader.conf` or `/boot/loader.conf.local`:

```puppet
class { 'fbsd':
  loader_settings => {
    'autoboot_delay'                         => 3,
    'cryptodev_load@/boot/loader.conf.local' => true,
  },
}
```

The loader reads `/boot/loader.conf`, then the drop-in files in `/boot/loader.conf.d`, then `/boot/loader.conf.local`. Changes take effect on the next boot.

### Managing periodic.conf

periodic(8) runs the daily, weekly, monthly and security maintenance scripts of the base system from `/etc/periodic` and those installed by packages from `/usr/local/etc/periodic`. All of them are configured with variables in periodic.conf(5), which can be managed via the `periodic_settings` parameter:

```puppet
class { 'fbsd':
  periodic_settings => {
    'daily_output'                      => '/var/log/daily.log',
    'daily_scrub_zfs_default_threshold' => 30,
    'daily_scrub_zfs_enable'            => 'YES',
    'daily_show_success'                => 'NO',
    'daily_status_dmidecode_enable'     => 'YES',
    'daily_status_zfs_enable'           => 'YES',
    'monthly_output'                    => '/var/log/monthly.log',
    'weekly_output'                     => '/var/log/weekly.log',
    'weekly_status_pkg_enable'          => 'YES',
  },
}
```

Without a target in the title, the variable is managed in `/etc/periodic.conf`. periodic(8) also reads `/etc/periodic.conf.local` and `/usr/local/etc/periodic.conf`, which can be used as target, e.g. `daily_output@/etc/periodic.conf.local`.

Scripts installed by packages are switched on and off the same way. Custom scripts can be deployed with a `file` resource: periodic(8) runs every executable file in the directory, see periodic(8) for the exit codes. The schedule itself lives in `/etc/crontab` and is out of scope of this module.

### Using types directly

All types and defined types can be used without the `fbsd` class:

```puppet
fbsd_sysrc { 'sshd_flags@/etc/rc.conf.d/sshd':
  ensure => present,
  value  => '-4',
}

fbsd_sysctl { 'net.inet.tcp.blackhole':
  value => 2,
}

fbsd_loader { 'autoboot_delay':
  ensure => absent,
}
```

The types autorequire a `file` resource for the target file and its directory, e.g. `File['/etc/rc.conf.d/sshd']`.

### Importing an existing configuration

All types list the variables of the configuration files they manage:

```shell
puppet resource fbsd_sysrc
puppet resource fbsd_sysctl
puppet resource fbsd_loader
```

`fbsd_sysrc` lists `/etc/rc.conf`, `/etc/rc.conf.local`, all files in `/etc/rc.conf.d`, `/etc/periodic.conf`, `/etc/periodic.conf.local` and `/usr/local/etc/periodic.conf`. `fbsd_sysctl` lists `/etc/sysctl.conf`, `/etc/sysctl.conf.local` and `/etc/sysctl.kld.d/*.conf`. `fbsd_loader` lists `/boot/loader.conf`, `/boot/loader.conf.local` and `/boot/loader.conf.d/*.conf`.

## Limitations

- sysrc(8) evaluates rc.conf(5) style files with sh(1). Values of `fbsd_sysrc` must therefore be literal values: double quotes, backticks, dollar signs, backslashes and line breaks are not allowed
- `fbsd_sysrc` lists variables via `puppet resource` but there is no purge option, because `/etc/rc.conf` may contain variables that are not managed by this module
- The module-specific variables in `/etc/sysctl.kld.d` are applied at boot only for modules that are loaded via `kld_list`, not for modules loaded by the loader
- Don't manage a list variable both as a whole (`value`) and per entry (`item`), the resources would overwrite each other

## Reference

Classes, types and parameters are documented in [REFERENCE.md](REFERENCE.md).

## Development

### Contributing

Please use the GitHub issues functionality to report any bugs or requests for new features. Feel free to fork and submit pull requests for potential contributions.

## License

BSD-2-Clause
