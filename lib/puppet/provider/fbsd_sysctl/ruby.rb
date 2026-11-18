# frozen_string_literal: true

require 'puppet_x/fbsd/key_value_provider'

Puppet::Type.type(:fbsd_sysctl).provide(:ruby) do
  desc 'Manages sysctl.conf(5) variables by editing the target file and sets them in the running kernel with sysctl(8).'

  # @return [String] the absolute path of sysctl(8)
  def self.sysctl_path
    '/sbin/sysctl'
  end

  commands sysctl: sysctl_path
  confine 'os.name' => :freebsd
  defaultfor 'os.name' => :freebsd

  include PuppetX::Fbsd::KeyValueProvider

  # @return [String] the characters that separate key and value
  def self.delimiters
    '=:'
  end

  # @return [Array<String>] the existing files that are read at boot:
  #   /etc/sysctl.conf, /etc/sysctl.conf.local and /etc/sysctl.kld.d/*.conf
  def self.target_files
    files = ['/etc/sysctl.conf', '/etc/sysctl.conf.local'] + Dir.glob('/etc/sysctl.kld.d/*.conf').sort
    files.select { |path| File.file?(path) }
  end

  # Values that are empty or contain whitespace, `#` or `'` are written in
  # double quotes.
  #
  # @param key [String] the variable name
  # @param value [String] the value
  # @return [String] the assignment in sysctl.conf(5) syntax
  def self.format_line(key, value)
    (value.empty? || value.match?(%r{[\s#']})) ? "#{key}=\"#{value}\"" : "#{key}=#{value}"
  end

  # @param first [String, nil] a value
  # @param second [String, nil] another value
  # @return [Boolean] whether both values are identical strings or represent
  #   the same integer
  def self.values_equal?(first, second)
    return false if first.nil? || second.nil?
    return true if first == second

    integer = %r{\A-?\d+\z}
    first.match?(integer) && second.match?(integer) && Integer(first, 10) == Integer(second, 10)
  end

  # @return [String, nil] the value in the running kernel, or nil if the
  #   variable does not exist in the running kernel
  def runtime_value
    output = execute([self.class.sysctl_path, '-n', resource[:name]], failonfail: false, combine: false)
    return nil unless output.exitstatus.zero?

    output.to_s.chomp
  end

  # Writes the value to the target file and, if `apply` is enabled, to the
  # running kernel.
  #
  # @return [void]
  def create
    super
    apply_runtime(resource[:value])
  end

  # @param should [String] the requested value
  # @return [void]
  def value=(should)
    super
    apply_runtime(should)
  end

  private

  # Sets the value in the running kernel unless `apply` is disabled, the
  # variable does not exist in the running kernel or already has the value.
  #
  # @param should [String] the requested value
  # @return [void]
  def apply_runtime(should)
    return unless resource[:apply]

    runtime = runtime_value
    return if runtime.nil? || self.class.values_equal?(runtime, should)

    execute([self.class.sysctl_path, "#{resource[:name]}=#{should}"], failonfail: true, combine: true)
  end
end
