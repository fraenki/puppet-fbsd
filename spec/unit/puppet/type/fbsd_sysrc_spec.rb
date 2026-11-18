# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:fbsd_sysrc) do
  let(:resource) { described_class.new(title: 'gateway_enable', value: 'YES') }

  it 'uses name, item and target as namevars' do
    expect(described_class.key_attributes.sort).to eq([:item, :name, :target])
  end

  it 'parses name and item from the title' do
    res = described_class.new(title: 'kld_list+if_bridge')
    expect(res[:name]).to eq('kld_list')
    expect(res[:item]).to eq('if_bridge')
    expect(res[:target]).to eq('/etc/rc.conf')
  end

  it 'parses name, item and target from the title' do
    res = described_class.new(title: 'cloned_interfaces+bridge0@/etc/rc.conf.local')
    expect(res[:name]).to eq('cloned_interfaces')
    expect(res[:item]).to eq('bridge0')
    expect(res[:target]).to eq('/etc/rc.conf.local')
  end

  it 'rejects an item that sysrc would treat as delimiter' do
    expect {
      described_class.new(title: 'kld_list+_foo')
    }.to raise_error(Puppet::ResourceError, %r{item must start with a letter})
  end

  it 'rejects an item with whitespace' do
    expect {
      described_class.new(title: 'kld_list', item: 'a b')
    }.to raise_error(Puppet::ResourceError, %r{item must start with a letter})
  end

  it 'rejects value together with item' do
    expect {
      described_class.new(title: 'kld_list+if_bridge', value: 'x')
    }.to raise_error(Puppet::ResourceError, %r{value must not be set together with item})
  end

  it 'defaults ensure to present' do
    expect(resource[:ensure]).to eq(:present)
  end

  it 'defaults target to /etc/rc.conf' do
    expect(resource[:target]).to eq('/etc/rc.conf')
  end

  it 'parses name and target from the title' do
    res = described_class.new(title: 'sshd_flags@/etc/rc.conf.d/sshd', value: '-4')
    expect(res[:name]).to eq('sshd_flags')
    expect(res[:target]).to eq('/etc/rc.conf.d/sshd')
  end

  it 'converts booleans to YES and NO' do
    expect(described_class.new(title: 'a_enable', value: true)[:value]).to eq('YES')
    expect(described_class.new(title: 'b_enable', value: false)[:value]).to eq('NO')
  end

  it 'converts integers to strings' do
    expect(described_class.new(title: 'counter', value: 3)[:value]).to eq('3')
  end

  it 'rejects an invalid variable name' do
    expect {
      described_class.new(title: 'net.inet.ip.forwarding', value: '1')
    }.to raise_error(Puppet::ResourceError, %r{name must be a valid sh\(1\) variable name})
  end

  it 'rejects a relative target' do
    expect {
      described_class.new(title: 'foo', target: 'rc.conf', value: '1')
    }.to raise_error(Puppet::ResourceError, %r{target must be an absolute path})
  end

  it 'rejects values with shell expansion characters' do
    expect {
      described_class.new(title: 'foo', value: 'a$b')
    }.to raise_error(Puppet::ResourceError, %r{value must not contain})
  end

  it 'autorequires the target file and its directory' do
    res = described_class.new(title: 'ntpd_enable@/etc/rc.conf.d/ntpd', value: 'YES')
    catalog = Puppet::Resource::Catalog.new
    file = Puppet::Type.type(:file).new(name: '/etc/rc.conf.d', ensure: :directory)
    catalog.add_resource(file)
    catalog.add_resource(res)
    expect(res.autorequire.map { |rel| rel.source.ref }).to include('File[/etc/rc.conf.d]')
  end
end
