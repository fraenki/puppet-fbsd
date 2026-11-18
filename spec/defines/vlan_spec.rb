# frozen_string_literal: true

require 'spec_helper'

describe 'fbsd::vlan' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:title) { 'vlan10' }

      context 'on a lagg with a static address' do
        let(:params) { { vlan_id: 10, vlandev: 'lagg0', ipaddress: '192.0.2.10', netmask: 24 } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_fbsd_sysrc('cloned_interfaces+vlan10@/etc/rc.conf').with_ensure('present') }
        it { is_expected.to contain_fbsd_sysrc('create_args_vlan10@/etc/rc.conf').with_value('vlan 10 vlandev lagg0') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_vlan10@/etc/rc.conf').with_value('inet 192.0.2.10/24 up') }
        it { is_expected.to contain_exec('fbsd netif restart vlan10').with(refreshonly: true, tag: 'fbsd_netif_clone') }
        it { is_expected.to contain_exec('fbsd netif restart vlan10').that_notifies('Exec[fbsd routing restart]') }
        it { is_expected.to contain_fbsd_sysrc('create_args_vlan10@/etc/rc.conf').that_notifies('Exec[fbsd netif restart vlan10]') }
      end

      context 'on a lagg managed by Puppet' do
        let(:pre_condition) { "fbsd::lagg { 'lagg0': members => ['em0'], method => 'manual' }" }
        let(:params) { { vlan_id: 10, vlandev: 'lagg0', method: 'manual' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('fbsd netif restart lagg0').that_notifies('Exec[fbsd netif restart vlan10]') }
      end

      context 'on an interface managed by Puppet' do
        let(:pre_condition) { "fbsd::interface { 'em0': method => 'manual' }" }
        let(:params) { { vlan_id: 10, vlandev: 'em0', method: 'manual' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_exec('fbsd netif restart em0').that_notifies('Exec[fbsd netif restart vlan10]') }
      end

      context 'with apply false' do
        let(:params) { { vlan_id: 10, vlandev: 'lagg0', method: 'manual', apply: false } }

        it { is_expected.to have_exec_resource_count(0) }
      end

      context 'with a priority code point' do
        let(:params) { { vlan_id: 10, vlandev: 'em0', pcp: 3, method: 'manual' } }

        it { is_expected.to contain_fbsd_sysrc('create_args_vlan10@/etc/rc.conf').with_value('vlan 10 vlandev em0 vlanpcp 3') }
      end

      context 'with ensure absent' do
        let(:params) { { ensure: 'absent', vlan_id: 10, vlandev: 'lagg0' } }

        it { is_expected.to contain_fbsd_sysrc('cloned_interfaces+vlan10@/etc/rc.conf').with_ensure('absent') }
        it { is_expected.to contain_fbsd_sysrc('create_args_vlan10@/etc/rc.conf').with_ensure('absent') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_vlan10@/etc/rc.conf').with_ensure('absent') }
        it { is_expected.to contain_exec('fbsd netif stop vlan10').that_comes_before('Fbsd_sysrc[create_args_vlan10@/etc/rc.conf]') }
        it { is_expected.to contain_fbsd_sysrc('create_args_vlan10@/etc/rc.conf').that_notifies('Exec[fbsd routing restart]') }
      end
    end
  end
end
