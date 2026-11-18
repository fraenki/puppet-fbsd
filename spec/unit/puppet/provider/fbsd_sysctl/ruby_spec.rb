# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/fbsd/key_value_file'

describe Puppet::Type.type(:fbsd_sysctl).provider(:ruby) do
  let(:type_class) { Puppet::Type.type(:fbsd_sysctl) }
  let(:file) { PuppetX::Fbsd::KeyValueFile }
  let(:resource) { type_class.new(title: 'kern.logsigexit', value: 0, provider: :ruby) }
  let(:provider) { resource.provider }

  def output(text, status = 0)
    Puppet::Util::Execution::ProcessOutput.new(text, status)
  end

  it 'formats lines in sysctl.conf syntax' do
    expect(described_class.format_line('kern.logsigexit', '0')).to eq('kern.logsigexit=0')
    expect(described_class.format_line('kern.hostname', 'a b')).to eq('kern.hostname="a b"')
  end

  it 'compares integers numerically' do
    expect(described_class.values_equal?('01', '1')).to be true
    expect(described_class.values_equal?('a', 'b')).to be false
    expect(described_class.values_equal?(nil, '1')).to be false
  end

  it 'reads the runtime value with sysctl -n' do
    allow(provider).to receive(:execute)
      .with(['/sbin/sysctl', '-n', 'kern.logsigexit'], failonfail: false, combine: false)
      .and_return(output("1\n"))
    expect(provider.runtime_value).to eq('1')
  end

  it 'returns no runtime value for unknown variables' do
    allow(provider).to receive(:execute)
      .with(['/sbin/sysctl', '-n', 'kern.logsigexit'], failonfail: false, combine: false)
      .and_return(output('', 1))
    expect(provider.runtime_value).to be_nil
  end

  it 'writes the file and sets the runtime value on create' do
    allow(file).to receive(:value).and_return(nil)
    allow(provider).to receive(:runtime_value).and_return('1')
    expect(file).to receive(:set).with('/etc/sysctl.conf', 'kern.logsigexit', 'kern.logsigexit=0', '=:')
    expect(provider).to receive(:execute).with(['/sbin/sysctl', 'kern.logsigexit=0'], failonfail: true, combine: true)
    provider.create
  end

  it 'does not set the runtime value if apply is disabled' do
    res = type_class.new(title: 'kern.logsigexit', value: 0, apply: false, provider: :ruby)
    allow(file).to receive(:value).and_return(nil)
    allow(file).to receive(:set)
    expect(res.provider).not_to receive(:execute)
    res.provider.create
  end

  it 'is out of sync if only the runtime value differs' do
    allow(file).to receive(:value).and_return('0')
    allow(provider).to receive(:runtime_value).and_return('1')
    expect(resource.property(:value).insync?('0')).to be false
  end

  it 'is in sync if the variable does not exist in the running kernel' do
    allow(provider).to receive(:runtime_value).and_return(nil)
    expect(resource.property(:value).insync?('0')).to be true
  end
end
