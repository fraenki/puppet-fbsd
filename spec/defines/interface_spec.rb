# frozen_string_literal: true

require 'spec_helper'

describe 'fbsd::interface' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:title) { 'em0' }

      context 'with a static address' do
        let(:params) { { ipaddress: '192.0.2.10', netmask: 24 } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0@/etc/rc.conf').with_value('inet 192.0.2.10/24 up') }
        it { is_expected.to contain_class('fbsd::routing') }
        it { is_expected.to contain_exec('fbsd netif restart em0').with(command: '/usr/sbin/service netif restart em0', refreshonly: true) }
        it { is_expected.to contain_exec('fbsd netif restart em0').that_notifies('Exec[fbsd routing restart]') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0@/etc/rc.conf').that_notifies('Exec[fbsd netif restart em0]') }
        it { is_expected.not_to contain_exec('fbsd netif stop em0') }
      end

      context 'with apply false' do
        let(:params) { { ipaddress: '192.0.2.10', netmask: 24, apply: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to have_exec_resource_count(0) }
        it { is_expected.not_to contain_class('fbsd::routing') }
      end

      context 'with dhcp' do
        let(:params) { { method: 'dhcp' } }

        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0@/etc/rc.conf').with_value('DHCP up') }
      end

      context 'with mtu and options' do
        let(:params) { { ipaddress: '192.0.2.10', netmask: 24, mtu: 9000, options: ['-rxcsum'] } }

        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0@/etc/rc.conf').with_value('inet 192.0.2.10/24 mtu 9000 -rxcsum up') }
      end

      context 'with onboot false' do
        let(:params) { { ipaddress: '192.0.2.10', netmask: 24, onboot: false } }

        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0@/etc/rc.conf').with_value('NOAUTO inet 192.0.2.10/24 up') }
        it { is_expected.to have_exec_resource_count(0) }
      end

      context 'with aliases and ipv6 autoconf' do
        let(:params) { { method: 'manual', ipv6_auto: true, aliases: ['inet 192.0.2.5/32', 'inet 192.0.2.6/32'] } }

        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0_ipv6@/etc/rc.conf').with_value('inet6 accept_rtadv') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0_alias0@/etc/rc.conf').with_value('inet 192.0.2.5/32') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0_alias1@/etc/rc.conf').with_value('inet 192.0.2.6/32') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0_ipv6@/etc/rc.conf').that_notifies('Exec[fbsd netif restart em0]') }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0_alias1@/etc/rc.conf').that_notifies('Exec[fbsd netif restart em0]') }
      end

      context 'with a name that needs translation' do
        let(:title) { 'em0.102' }
        let(:params) { { ipaddress: '192.0.2.10', netmask: 24 } }

        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0_102@/etc/rc.conf') }
        it { is_expected.to contain_exec('fbsd netif restart em0.102').with_command('/usr/sbin/service netif restart em0.102') }
      end

      context 'with ensure absent' do
        let(:params) { { ensure: 'absent', ipaddress: '192.0.2.10', netmask: 24 } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0@/etc/rc.conf').with_ensure('absent') }
        it { is_expected.not_to contain_exec('fbsd netif restart em0') }

        it do
          is_expected.to contain_exec('fbsd netif stop em0').with(
            command: '/usr/sbin/service netif stop em0',
            onlyif: '/usr/sbin/sysrc -c -f /etc/rc.conf ifconfig_em0',
          ).that_comes_before('Fbsd_sysrc[ifconfig_em0@/etc/rc.conf]')
        end

        it { is_expected.to contain_fbsd_sysrc('ifconfig_em0@/etc/rc.conf').that_notifies('Exec[fbsd routing restart]') }
      end

      context 'with a static address but no netmask' do
        let(:params) { { ipaddress: '192.0.2.10' } }

        it { is_expected.to compile.and_raise_error(%r{netmask}) }
      end
    end
  end
end
