# frozen_string_literal: true

require 'spec_helper'

describe 'fbsd::kld' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:title) { 'if_bridge' }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_fbsd_sysrc('kld_list+if_bridge').with_ensure('present') }
        it { is_expected.not_to contain_file('/etc/rc.conf.d/kld') }

        it {
          is_expected.to contain_exec('kldload if_bridge').with(
            command: '/sbin/kldload -n if_bridge',
            unless: ['/sbin/kldstat -q -m if_bridge', '/sbin/kldstat -q -n if_bridge'],
          )
        }
      end

      context 'with sysctls' do
        let(:params) { { sysctls: { 'net.link.bridge.pfil_member' => 1 } } }

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_fbsd_sysctl('net.link.bridge.pfil_member@/etc/sysctl.kld.d/if_bridge.conf')
            .with(ensure: 'present', value: 1)
            .that_requires('Exec[kldload if_bridge]')
        }
      end

      context 'with load disabled' do
        let(:params) { { load: false } }

        it { is_expected.not_to contain_exec('kldload if_bridge') }
      end

      context 'with ensure absent' do
        let(:params) { { ensure: 'absent', sysctls: { 'net.link.bridge.pfil_member' => 1 } } }

        it { is_expected.to contain_fbsd_sysrc('kld_list+if_bridge').with_ensure('absent') }
        it { is_expected.not_to contain_exec('kldload if_bridge') }
        it { is_expected.to contain_fbsd_sysctl('net.link.bridge.pfil_member@/etc/sysctl.kld.d/if_bridge.conf').with_ensure('absent') }
      end

      context 'with a .ko file name as title' do
        let(:title) { 'if_bridge.ko' }

        it { is_expected.to compile.and_raise_error(%r{without .ko extension}) }
      end

      context 'with a path as title' do
        let(:title) { '/boot/kernel/if_bridge' }

        it { is_expected.to compile.and_raise_error(%r{expects a match}) }
      end
    end
  end
end
