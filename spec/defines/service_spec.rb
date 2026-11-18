# frozen_string_literal: true

require 'spec_helper'

describe 'fbsd::service' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:title) { 'ntpd' }

      context 'with enable and variables' do
        let(:params) { { enable: true, variables: { 'ntpd_sync_on_start' => true } } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_fbsd_sysrc('ntpd_enable@/etc/rc.conf.d/ntpd').with(ensure: 'present', value: true) }
        it { is_expected.to contain_fbsd_sysrc('ntpd_sync_on_start@/etc/rc.conf.d/ntpd').with(ensure: 'present', value: true) }
      end

      context 'without enable' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_fbsd_sysrc('ntpd_enable@/etc/rc.conf.d/ntpd') }
      end

      context 'with a custom enable variable and target' do
        let(:params) { { enable: false, enable_variable: 'ntp_daemon_enable', target: '/etc/rc.conf.local' } }

        it { is_expected.to contain_fbsd_sysrc('ntp_daemon_enable@/etc/rc.conf.local').with_value(false) }
      end

      context 'with ensure absent' do
        let(:params) { { ensure: 'absent', variables: { 'ntpd_flags' => '-g' } } }

        it { is_expected.to contain_fbsd_sysrc('ntpd_enable@/etc/rc.conf.d/ntpd').with_ensure('absent') }
        it { is_expected.to contain_fbsd_sysrc('ntpd_flags@/etc/rc.conf.d/ntpd').with_ensure('absent') }
      end

      context 'with an invalid variable name' do
        let(:params) { { variables: { 'ntpd.flags' => '-g' } } }

        it { is_expected.to compile.and_raise_error(%r{variables}) }
      end
    end
  end
end
