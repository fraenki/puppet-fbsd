# frozen_string_literal: true

require 'spec_helper'

describe 'fbsd::lagg' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:title) { 'lagg0' }

      context 'with members and a static address' do
        let(:params) { { members: ['em0', 'em1'], ipaddress: '192.0.2.10', netmask: 24 } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_fbsd_sysrc('cloned_interfaces+lagg0@/etc/rc.conf').with_ensure('present') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_lagg0@/etc/rc.conf').with_value('laggproto failover laggport em0 laggport em1 inet 192.0.2.10/24 up') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0@/etc/rc.conf').with_value('up') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_em1@/etc/rc.conf').with_value('up') }
        it { is_expected.to contain_exec('fbsd netif restart lagg0').with(command: '/usr/sbin/service netif restart lagg0', refreshonly: true, tag: 'fbsd_netif_clone') }
        it { is_expected.to contain_exec('fbsd netif restart lagg0').that_notifies('Exec[fbsd routing restart]') }
        it { is_expected.to contain_fbsd_sysrc('cloned_interfaces+lagg0@/etc/rc.conf').that_notifies('Exec[fbsd netif restart lagg0]') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_lagg0@/etc/rc.conf').that_notifies('Exec[fbsd netif restart lagg0]') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_em1@/etc/rc.conf').that_notifies('Exec[fbsd netif restart lagg0]') }
      end

      context 'with apply false' do
        let(:params) { { members: ['em0'], method: 'manual', apply: false } }

        it { is_expected.to have_exec_resource_count(0) }
      end

      context 'with onboot false' do
        let(:params) { { members: ['em0'], method: 'manual', onboot: false } }

        it { is_expected.to have_exec_resource_count(0) }
      end

      context 'with lacp' do
        let(:params) { { members: ['em0'], laggproto: 'lacp', method: 'manual' } }

        it { is_expected.to contain_fbsd_sysrc('ifconfig_lagg0@/etc/rc.conf').with_value('laggproto lacp laggport em0 up') }
      end

      context 'with ensure absent' do
        let(:params) { { ensure: 'absent', members: ['em0'] } }

        it { is_expected.to contain_fbsd_sysrc('cloned_interfaces+lagg0@/etc/rc.conf').with_ensure('absent') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_lagg0@/etc/rc.conf').with_ensure('absent') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0@/etc/rc.conf').with_ensure('absent') }
        it { is_expected.to contain_exec('fbsd netif stop lagg0').with_onlyif('/usr/sbin/sysrc -c -f /etc/rc.conf ifconfig_lagg0') }
        it { is_expected.to contain_exec('fbsd netif stop lagg0').that_comes_before('Fbsd_sysrc[cloned_interfaces+lagg0@/etc/rc.conf]') }
        it { is_expected.to contain_fbsd_sysrc('cloned_interfaces+lagg0@/etc/rc.conf').that_notifies('Exec[fbsd routing restart]') }
      end
    end
  end
end
