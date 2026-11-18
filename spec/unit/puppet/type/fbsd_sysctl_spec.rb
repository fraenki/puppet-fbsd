# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:fbsd_sysctl) do
  let(:resource) { described_class.new(title: 'kern.logsigexit', value: 0) }

  it 'uses name and target as namevars' do
    expect(described_class.key_attributes.sort).to eq([:name, :target])
  end

  it 'defaults ensure to present' do
    expect(resource[:ensure]).to eq(:present)
  end

  it 'defaults target to /etc/sysctl.conf' do
    expect(resource[:target]).to eq('/etc/sysctl.conf')
  end

  it 'defaults apply to true' do
    expect(resource[:apply]).to be true
  end

  it 'converts integers to strings' do
    expect(resource[:value]).to eq('0')
  end

  it 'parses name and target from the title' do
    res = described_class.new(title: 'net.link.bridge.pfil_member@/etc/sysctl.kld.d/if_bridge.conf', value: 1)
    expect(res[:name]).to eq('net.link.bridge.pfil_member')
    expect(res[:target]).to eq('/etc/sysctl.kld.d/if_bridge.conf')
  end

  it 'accepts /etc/sysctl.conf.local as target' do
    res = described_class.new(title: 'kern.ipc.somaxconn@/etc/sysctl.conf.local', value: 1024)
    expect(res[:target]).to eq('/etc/sysctl.conf.local')
  end

  it 'rejects other targets' do
    expect {
      described_class.new(title: 'kern.logsigexit@/etc/rc.conf', value: 0)
    }.to raise_error(Puppet::ResourceError, %r{target must be /etc/sysctl.conf})
  end

  it 'rejects an invalid name' do
    expect {
      described_class.new(title: 'kern logsigexit', value: 0)
    }.to raise_error(Puppet::ResourceError, %r{name must be a valid sysctl name})
  end

  it 'rejects values with double quotes' do
    expect {
      described_class.new(title: 'kern.hostname', value: 'a"b')
    }.to raise_error(Puppet::ResourceError, %r{value must not contain double quotes})
  end

  it 'rejects boolean values' do
    expect {
      described_class.new(title: 'kern.logsigexit', value: true)
    }.to raise_error(Puppet::ResourceError, %r{value must be a string or an integer})
  end
end
