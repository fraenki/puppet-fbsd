# frozen_string_literal: true

require 'spec_helper'

describe 'fbsd::route' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:title) { 'to_dmz' }

      context 'with an inet route' do
        let(:params) { { network: '198.51.100.0/24', gateway: '192.0.2.1' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_fbsd_sysrc('static_routes+to_dmz@/etc/rc.conf').with_ensure('present') }
        it { is_expected.to contain_fbsd_sysrc('route_to_dmz@/etc/rc.conf').with_value('-net 198.51.100.0/24 192.0.2.1') }
        it { is_expected.to contain_exec('fbsd routing restart').with(command: '/usr/sbin/service routing restart', refreshonly: true) }
        it { is_expected.to contain_fbsd_sysrc('static_routes+to_dmz@/etc/rc.conf').that_notifies('Exec[fbsd routing restart]') }
        it { is_expected.to contain_fbsd_sysrc('route_to_dmz@/etc/rc.conf').that_notifies('Exec[fbsd routing restart]') }
      end

      context 'with apply false' do
        let(:params) { { network: '198.51.100.0/24', gateway: '192.0.2.1', apply: false } }

        it { is_expected.not_to contain_class('fbsd::routing') }
      end

      context 'with an inet6 route' do
        let(:params) { { network: '2001:db8:1::/48', gateway: '2001:db8::1', family: 'inet6' } }

        it { is_expected.to contain_fbsd_sysrc('ipv6_static_routes+to_dmz@/etc/rc.conf').with_ensure('present') }
        it { is_expected.to contain_fbsd_sysrc('ipv6_route_to_dmz@/etc/rc.conf').with_value('-net 2001:db8:1::/48 2001:db8::1') }
      end

      context 'with ensure absent' do
        let(:params) { { ensure: 'absent', network: '198.51.100.0/24', gateway: '192.0.2.1' } }

        it { is_expected.to contain_fbsd_sysrc('static_routes+to_dmz@/etc/rc.conf').with_ensure('absent') }
        it { is_expected.to contain_fbsd_sysrc('route_to_dmz@/etc/rc.conf').with_ensure('absent') }
        it { is_expected.to contain_fbsd_sysrc('route_to_dmz@/etc/rc.conf').that_notifies('Exec[fbsd routing restart]') }
      end
    end
  end
end
