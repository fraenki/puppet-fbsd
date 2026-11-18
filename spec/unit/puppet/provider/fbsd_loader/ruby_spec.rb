# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/fbsd/key_value_file'

describe Puppet::Type.type(:fbsd_loader).provider(:ruby) do
  let(:type_class) { Puppet::Type.type(:fbsd_loader) }
  let(:file) { PuppetX::Fbsd::KeyValueFile }
  let(:resource) { type_class.new(title: 'autoboot_delay', value: 3, provider: :ruby) }
  let(:provider) { resource.provider }

  it 'formats lines in loader.conf syntax' do
    expect(described_class.format_line('autoboot_delay', '3')).to eq('autoboot_delay="3"')
  end

  it 'exists if the key is assigned' do
    allow(file).to receive(:value).with('/boot/loader.conf', 'autoboot_delay', '=').and_return('10')
    expect(provider.exists?).to be true
    expect(provider.value).to eq('10')
  end

  it 'does not exist if the key is not assigned' do
    allow(file).to receive(:value).with('/boot/loader.conf', 'autoboot_delay', '=').and_return(nil)
    expect(provider.exists?).to be false
  end

  it 'writes the key on create' do
    allow(file).to receive(:value).and_return(nil)
    expect(file).to receive(:set).with('/boot/loader.conf', 'autoboot_delay', 'autoboot_delay="3"', '=')
    provider.create
  end

  it 'removes the key on destroy' do
    expect(file).to receive(:remove).with('/boot/loader.conf', 'autoboot_delay', '=')
    provider.destroy
  end

  it 'returns one instance per key and file' do
    allow(described_class).to receive(:target_files).and_return(['/boot/loader.conf'])
    allow(file).to receive(:entries).with('/boot/loader.conf', '=').and_return('zfs_load' => 'YES')
    expect(described_class.instances.map(&:title)).to eq(['zfs_load@/boot/loader.conf'])
  end
end
