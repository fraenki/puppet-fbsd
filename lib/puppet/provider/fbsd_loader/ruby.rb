# frozen_string_literal: true

require 'puppet_x/fbsd/key_value_provider'

Puppet::Type.type(:fbsd_loader).provide(:ruby) do
  desc 'Manages loader.conf(5) variables by editing the target file.'

  confine 'os.name' => :freebsd
  defaultfor 'os.name' => :freebsd

  include PuppetX::Fbsd::KeyValueProvider

  # @return [String] the characters that separate key and value
  def self.delimiters
    '='
  end

  # @return [Array<String>] the existing files that are read by the loader:
  #   /boot/loader.conf, /boot/loader.conf.local and /boot/loader.conf.d/*.conf
  def self.target_files
    files = ['/boot/loader.conf', '/boot/loader.conf.local'] + Dir.glob('/boot/loader.conf.d/*.conf').sort
    files.select { |path| File.file?(path) }
  end

  # @param key [String] the variable name
  # @param value [String] the value
  # @return [String] the assignment in loader.conf(5) syntax
  def self.format_line(key, value)
    "#{key}=\"#{value}\""
  end
end
