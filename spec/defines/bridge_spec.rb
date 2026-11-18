# frozen_string_literal: true

require 'spec_helper'

describe 'fbsd::bridge' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:title) { 'bridge0' }

      context 'with members' do
        let(:params) { { members: ['em0', 'em1'] } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_fbsd_sysrc('cloned_interfaces+bridge0@/etc/rc.conf').with_ensure('present') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_bridge0@/etc/rc.conf').with_value('addm em0 addm em1 up') }
        it { is_expected.to contain_exec('fbsd netif restart bridge0').with(refreshonly: true, tag: 'fbsd_netif_clone') }
        it { is_expected.to contain_exec('fbsd netif restart bridge0').that_notifies('Exec[fbsd routing restart]') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_bridge0@/etc/rc.conf').that_notifies('Exec[fbsd netif restart bridge0]') }
      end

      context 'with a VLAN member managed by Puppet' do
        let(:pre_condition) { "fbsd::vlan { 'vlan10': vlan_id => 10, vlandev => 'em1', method => 'manual' }" }
        let(:params) { { members: ['em0', 'vlan10'] } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('fbsd netif restart vlan10').that_notifies('Exec[fbsd netif restart bridge0]') }
      end

      context 'with apply false' do
        let(:params) { { members: ['em0'], apply: false } }

        it { is_expected.to have_exec_resource_count(0) }
      end

      context 'with members and a static address' do
        let(:params) { { members: ['em0'], ipaddress: '192.0.2.10', netmask: 24 } }

        it { is_expected.to contain_fbsd_sysrc('ifconfig_bridge0@/etc/rc.conf').with_value('addm em0 inet 192.0.2.10/24 up') }
      end

      context 'with ensure absent' do
        let(:params) { { ensure: 'absent', members: ['em0'] } }

        it { is_expected.to contain_fbsd_sysrc('cloned_interfaces+bridge0@/etc/rc.conf').with_ensure('absent') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_bridge0@/etc/rc.conf').with_ensure('absent') }
        it { is_expected.to contain_exec('fbsd netif stop bridge0').that_comes_before('Fbsd_sysrc[cloned_interfaces+bridge0@/etc/rc.conf]') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_bridge0@/etc/rc.conf').that_notifies('Exec[fbsd routing restart]') }
      end
    end
  end
end
