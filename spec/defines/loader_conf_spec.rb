# frozen_string_literal: true

require 'spec_helper'

describe 'fbsd::loader_conf' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:title) { 'zfs' }

      context 'with settings' do
        let(:params) { { settings: { 'vfs.zfs.arc.max' => '8G', 'cryptodev_load' => true } } }

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/boot/loader.conf.d/zfs.conf').with(
            ensure: 'file',
            owner: 'root',
            group: 'wheel',
            mode: '0644',
            content: "# This file is managed by Puppet.\ncryptodev_load=\"YES\"\nvfs.zfs.arc.max=\"8G\"\n",
          )
        }
      end

      context 'with ensure absent' do
        let(:params) { { ensure: 'absent' } }

        it { is_expected.to contain_file('/boot/loader.conf.d/zfs.conf').with_ensure('absent') }
      end

      context 'with a value containing double quotes' do
        let(:params) { { settings: { 'kernel_options' => 'a"b' } } }

        it { is_expected.to compile.and_raise_error(%r{settings}) }
      end
    end
  end
end
