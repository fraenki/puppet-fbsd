# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:fbsd_loader) do
  let(:resource) { described_class.new(title: 'autoboot_delay', value: 3) }

  it 'uses name and target as namevars' do
    expect(described_class.key_attributes.sort).to eq([:name, :target])
  end

  it 'defaults ensure to present' do
    expect(resource[:ensure]).to eq(:present)
  end

  it 'defaults target to /boot/loader.conf' do
    expect(resource[:target]).to eq('/boot/loader.conf')
  end

  it 'converts integers to strings' do
    expect(resource[:value]).to eq('3')
  end

  it 'converts booleans to YES and NO' do
    expect(described_class.new(title: 'cryptodev_load', value: true)[:value]).to eq('YES')
  end

  it 'parses name and target from the title' do
    res = described_class.new(title: 'vfs.zfs.arc.max@/boot/loader.conf.d/zfs.conf', value: '8G')
    expect(res[:name]).to eq('vfs.zfs.arc.max')
    expect(res[:target]).to eq('/boot/loader.conf.d/zfs.conf')
  end

  it 'rejects other targets' do
    expect {
      described_class.new(title: 'autoboot_delay@/etc/loader.conf', value: 3)
    }.to raise_error(Puppet::ResourceError, %r{target must be /boot/loader.conf})
  end

  it 'rejects values with double quotes' do
    expect {
      described_class.new(title: 'kernel_options', value: 'a"b')
    }.to raise_error(Puppet::ResourceError, %r{value must not contain double quotes})
  end
end
