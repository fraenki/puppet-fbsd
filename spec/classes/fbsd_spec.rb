# frozen_string_literal: true

require 'spec_helper'

describe 'fbsd' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('fbsd') }
        it { is_expected.to have_fbsd_sysrc_resource_count(0) }
        it { is_expected.to have_fbsd_sysctl_resource_count(0) }
        it { is_expected.to have_fbsd_loader_resource_count(0) }
      end

      context 'with all hashes' do
        let(:params) do
          {
            klds: {
              'if_bridge' => { 'load' => false },
            },
            loader_confs: {
              'zfs' => { 'settings' => { 'vfs.zfs.arc.max' => '8G' } },
            },
            loader_settings: {
              'autoboot_delay' => 3,
              'cryptodev_load@/boot/loader.conf.local' => { 'ensure' => 'absent' },
            },
            periodic_settings: {
              'daily_output' => '/var/log/daily.log',
              'daily_scrub_zfs_enable' => { 'value' => 'YES' },
              'daily_show_success@/etc/periodic.conf.local' => 'NO',
            },
            rc_settings: {
              'syslogd_flags' => '-ss',
              'cloned_interfaces' => { 'value' => 'bridge0', 'target' => '/etc/rc.conf.local' },
            },
            services: {
              'ntpd' => { 'enable' => true },
            },
            sysctls: {
              'kern.logsigexit' => 0,
              'kern.ipc.somaxconn@/etc/sysctl.conf.local' => { 'value' => 1024, 'apply' => false },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_fbsd__kld('if_bridge').with_load(false) }
        it { is_expected.to contain_fbsd__loader_conf('zfs').with_settings('vfs.zfs.arc.max' => '8G') }
        it { is_expected.to contain_fbsd_loader('autoboot_delay').with_value(3) }
        it { is_expected.to contain_fbsd_loader('cryptodev_load@/boot/loader.conf.local').with_ensure('absent') }
        it { is_expected.to contain_fbsd_sysrc('daily_output@/etc/periodic.conf').with_value('/var/log/daily.log') }
        it { is_expected.to contain_fbsd_sysrc('daily_scrub_zfs_enable@/etc/periodic.conf').with_value('YES') }
        it { is_expected.to contain_fbsd_sysrc('daily_show_success@/etc/periodic.conf.local').with_value('NO') }
        it { is_expected.to contain_fbsd_sysrc('syslogd_flags').with_value('-ss') }
        it { is_expected.to contain_fbsd_sysrc('cloned_interfaces').with(value: 'bridge0', target: '/etc/rc.conf.local') }
        it { is_expected.to contain_fbsd__service('ntpd').with_enable(true) }
        it { is_expected.to contain_fbsd_sysctl('kern.logsigexit').with_value(0) }
        it { is_expected.to contain_fbsd_sysctl('kern.ipc.somaxconn@/etc/sysctl.conf.local').with(value: 1024, apply: false) }
      end

      context 'with network hashes' do
        let(:params) do
          {
            interfaces: { 'em0' => { 'ipaddress' => '192.0.2.10', 'netmask' => 24 } },
            laggs: { 'lagg0' => { 'members' => ['em2', 'em3'] } },
            vlans: { 'vlan10' => { 'vlan_id' => 10, 'vlandev' => 'lagg0' } },
            bridges: { 'bridge0' => { 'members' => ['em4'] } },
            routes: { 'to_dmz' => { 'network' => '198.51.100.0/24', 'gateway' => '192.0.2.1' } },
            defaultrouter: '192.0.2.1',
            ipv6_defaultrouter: '2001:db8::1',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_fbsd__interface('em0') }
        it { is_expected.to contain_fbsd__lagg('lagg0') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_em2@/etc/rc.conf').with_value('up').that_notifies('Exec[fbsd netif restart lagg0]') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_em3@/etc/rc.conf').with_value('up').that_notifies('Exec[fbsd netif restart lagg0]') }
        it { is_expected.to contain_fbsd__vlan('vlan10') }
        it { is_expected.to contain_fbsd__bridge('bridge0') }
        it { is_expected.to contain_fbsd__route('to_dmz') }
        it { is_expected.to contain_fbsd_sysrc('defaultrouter').with_value('192.0.2.1') }
        it { is_expected.to contain_fbsd_sysrc('ipv6_defaultrouter').with_value('2001:db8::1') }

        it { is_expected.to contain_fbsd__lagg('lagg0').that_comes_before('Fbsd::Vlan[vlan10]') }
        it { is_expected.to contain_fbsd__vlan('vlan10').that_comes_before('Fbsd::Bridge[bridge0]') }

        it { is_expected.to contain_fbsd_sysrc('defaultrouter').that_notifies('Exec[fbsd routing restart]') }
        it { is_expected.to contain_fbsd_sysrc('ipv6_defaultrouter').that_notifies('Exec[fbsd routing restart]') }
        it { is_expected.to contain_exec('fbsd netif restart em0').that_notifies('Exec[fbsd routing restart]') }
        it { is_expected.to contain_exec('fbsd netif restart lagg0').that_notifies('Exec[fbsd netif restart vlan10]') }
        it { is_expected.to contain_exec('fbsd netif restart lagg0').that_comes_before('Exec[fbsd routing restart]') }
        it { is_expected.to contain_exec('fbsd netif restart vlan10').that_comes_before('Exec[fbsd routing restart]') }
      end

      context 'with apply_routing false' do
        let(:params) { { apply_routing: false, defaultrouter: '192.0.2.1' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_fbsd_sysrc('defaultrouter').without_notify }
        it { is_expected.not_to contain_class('fbsd::routing') }
      end
    end
  end
end
