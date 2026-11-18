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
    end
  end
end
