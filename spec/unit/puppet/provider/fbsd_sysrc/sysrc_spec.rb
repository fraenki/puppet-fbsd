# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:fbsd_sysrc).provider(:sysrc) do
  let(:type_class) { Puppet::Type.type(:fbsd_sysrc) }
  let(:resource) { type_class.new(title: 'ntpd_flags@/etc/rc.conf.d/ntpd', value: '-g', provider: :sysrc) }
  let(:provider) { resource.provider }
  let(:sysrc) { '/usr/sbin/sysrc' }
  let(:options) { { failonfail: true, combine: false } }

  def output(text, status = 0)
    Puppet::Util::Execution::ProcessOutput.new(text, status)
  end

  describe '#exists?' do
    it 'is false if the target file does not exist' do
      allow(File).to receive(:file?).with('/etc/rc.conf.d/ntpd').and_return(false)
      expect(provider.exists?).to be false
    end

    it 'is true if sysrc reports the target file' do
      allow(File).to receive(:file?).with('/etc/rc.conf.d/ntpd').and_return(true)
      allow(described_class).to receive(:execute)
        .with([sysrc, '-f', '/etc/rc.conf.d/ntpd', '-i', '-n', '-F', 'ntpd_flags'], failonfail: false, combine: false)
        .and_return(output("/etc/rc.conf.d/ntpd\n"))
      expect(provider.exists?).to be true
    end

    it 'is false if the variable is only set in the defaults' do
      allow(File).to receive(:file?).with('/etc/rc.conf.d/ntpd').and_return(true)
      allow(described_class).to receive(:execute)
        .with([sysrc, '-f', '/etc/rc.conf.d/ntpd', '-i', '-n', '-F', 'ntpd_flags'], failonfail: false, combine: false)
        .and_return(output("/etc/defaults/rc.conf\n"))
      expect(provider.exists?).to be false
    end

    it 'is false if the variable is not set' do
      allow(File).to receive(:file?).with('/etc/rc.conf.d/ntpd').and_return(true)
      allow(described_class).to receive(:execute)
        .with([sysrc, '-f', '/etc/rc.conf.d/ntpd', '-i', '-n', '-F', 'ntpd_flags'], failonfail: false, combine: false)
        .and_return(output('', 1))
      expect(provider.exists?).to be false
    end
  end

  it 'reads the value with sysrc -n' do
    allow(described_class).to receive(:execute)
      .with([sysrc, '-f', '/etc/rc.conf.d/ntpd', '-n', 'ntpd_flags'], options)
      .and_return(output("-g\n"))
    expect(provider.value).to eq('-g')
  end

  it 'sets the value on create' do
    expect(described_class).to receive(:execute)
      .with([sysrc, '-f', '/etc/rc.conf.d/ntpd', 'ntpd_flags=-g'], options)
      .and_return(output(''))
    provider.create
  end

  it 'fails on create without a value' do
    res = type_class.new(title: 'ntpd_flags@/etc/rc.conf.d/ntpd', provider: :sysrc)
    expect { res.provider.create }.to raise_error(Puppet::Error, %r{value is required})
  end

  it 'removes the variable with sysrc -x' do
    expect(described_class).to receive(:execute)
      .with([sysrc, '-f', '/etc/rc.conf.d/ntpd', '-x', 'ntpd_flags'], options)
      .and_return(output(''))
    provider.destroy
  end

  describe 'with item' do
    let(:resource) { type_class.new(title: 'kld_list+if_bridge', provider: :sysrc) }

    before(:each) do
      allow(File).to receive(:file?).with('/etc/rc.conf').and_return(true)
      allow(described_class).to receive(:execute)
        .with([sysrc, '-f', '/etc/rc.conf', '-i', '-n', 'kld_list'], failonfail: false, combine: false)
        .and_return(output("fusefs if_bridge\n"))
    end

    it 'exists if the item is part of the value' do
      expect(provider.exists?).to be true
    end

    it 'does not exist if the item is missing' do
      res = type_class.new(title: 'kld_list+cuse', provider: :sysrc)
      expect(res.provider.exists?).to be false
    end

    it 'adds the item with +=' do
      expect(described_class).to receive(:execute)
        .with([sysrc, '-f', '/etc/rc.conf', 'kld_list+=if_bridge'], options)
        .and_return(output(''))
      provider.create
    end

    it 'removes the item with -=' do
      expect(described_class).to receive(:execute)
        .with([sysrc, '-f', '/etc/rc.conf', 'kld_list-=if_bridge'], options)
        .and_return(output(''))
      provider.destroy
    end
  end

  it 'lists the existing rc.conf and periodic.conf files' do
    allow(Dir).to receive(:glob).with(['/etc/rc.conf.d/*', '/etc/rc.conf.d/*/*']).and_return(['/etc/rc.conf.d/ntpd'])
    allow(File).to receive(:file?).and_return(false)
    ['/etc/rc.conf', '/etc/rc.conf.d/ntpd', '/etc/periodic.conf'].each do |path|
      allow(File).to receive(:file?).with(path).and_return(true)
    end
    expect(described_class.target_files).to eq(['/etc/rc.conf', '/etc/rc.conf.d/ntpd', '/etc/periodic.conf'])
  end

  it 'returns one instance per variable and file' do
    allow(described_class).to receive(:target_files).and_return(['/etc/rc.conf'])
    allow(described_class).to receive(:execute)
      .with([sysrc, '-f', '/etc/rc.conf', '-a', '-N'], options)
      .and_return(output("hostname\nsshd_enable\n"))
    instances = described_class.instances
    expect(instances.map(&:title)).to eq(['hostname@/etc/rc.conf', 'sshd_enable@/etc/rc.conf'])
  end
end
