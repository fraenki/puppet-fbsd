# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'puppet_x/fbsd/key_value_file'

describe PuppetX::Fbsd::KeyValueFile do
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, 'sysctl.conf') }

  after(:each) do
    FileUtils.rm_rf(dir)
  end

  describe '.parse_line' do
    it 'ignores comments and empty lines' do
      expect(described_class.parse_line("# comment\n", '=')).to be_nil
      expect(described_class.parse_line("\n", '=')).to be_nil
    end

    it 'parses unquoted values with trailing comments' do
      expect(described_class.parse_line("kern.logsigexit=0\t# comment\n", '=:')).to eq(['kern.logsigexit', '0'])
    end

    it 'parses quoted values' do
      expect(described_class.parse_line(%(vfs.zfs.arc.max="8G" # limit\n), '=')).to eq(['vfs.zfs.arc.max', '8G'])
    end

    it 'accepts a colon as delimiter' do
      expect(described_class.parse_line("kern.logsigexit: 0\n", '=:')).to eq(['kern.logsigexit', '0'])
    end
  end

  it 'returns an empty hash for a missing file' do
    expect(described_class.entries(path, '=')).to eq({})
  end

  it 'returns the last assignment of a key' do
    File.write(path, "a=1\nb=2\na=3\n")
    expect(described_class.value(path, 'a', '=')).to eq('3')
  end

  it 'replaces existing assignments and keeps other lines' do
    File.write(path, "# header\na=1\nb=2\n")
    described_class.set(path, 'a', 'a=5', '=')
    expect(File.read(path)).to eq("# header\na=5\nb=2\n")
  end

  it 'appends new keys after a missing final newline' do
    File.write(path, 'a=1')
    described_class.set(path, 'b', 'b=2', '=')
    expect(File.read(path)).to eq("a=1\nb=2\n")
  end

  it 'creates a missing file' do
    described_class.set(path, 'a', 'a=1', '=')
    expect(File.read(path)).to eq("a=1\n")
  end

  it 'removes all assignments of a key' do
    File.write(path, "a=1\nb=2\na=3\n")
    described_class.remove(path, 'a', '=')
    expect(File.read(path)).to eq("b=2\n")
  end
end
