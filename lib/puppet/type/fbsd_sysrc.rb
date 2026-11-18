# frozen_string_literal: true

Puppet::Type.newtype(:fbsd_sysrc) do
  desc <<-DOC
    @summary Manages a single variable in an rc.conf(5) style file with sysrc(8).

    The variable is identified by its name and the file (`target`) it is
    written to. Besides /etc/rc.conf, any file that is sourced by sh(1) can be
    used, e.g. /etc/rc.conf.local, /etc/rc.conf.d/<service> or
    /etc/periodic.conf. sysrc(8) writes the variable as `name="value"`,
    replaces an existing assignment in place and checks the syntax of the
    resulting file before it is written.

    With `item`, the resource manages a single entry of a whitespace-separated
    list variable such as `kld_list` or `cloned_interfaces` instead of the
    whole value. The entry is added with `sysrc name+=item` and removed with
    `sysrc name-=item`, other entries stay in place.

    The title has the form `name`, `name@target`, `name+item` or
    `name+item@target`, e.g. `sshd_flags@/etc/rc.conf.d/sshd` or
    `kld_list+if_bridge`. Without a target in the title or the `target`
    attribute, the variable is managed in /etc/rc.conf.

    @example Enable a gateway in /etc/rc.conf
      fbsd_sysrc { 'gateway_enable':
        value => 'YES',
      }

    @example Set service flags in /etc/rc.conf.d/syslogd
      fbsd_sysrc { 'syslogd_flags@/etc/rc.conf.d/syslogd':
        value => '-ss',
      }

    @example Add a kernel module to kld_list
      fbsd_sysrc { 'kld_list+if_bridge':
        ensure => present,
      }
  DOC

  ensurable do
    desc 'Whether the variable, or with `item` the list entry, should be present or absent.'

    defaultvalues
    defaultto :present
  end

  # @return [Array<Array>] the patterns that split a title into name, item
  #   and target
  def self.title_patterns
    [
      [%r{\A([^@+]+)\+([^@]+)@(/.*)\z}m, [[:name], [:item], [:target]]],
      [%r{\A([^@+]+)\+([^@]+)\z}m, [[:name], [:item]]],
      [%r{\A([^@]+)@(/.*)\z}m, [[:name], [:target]]],
      [%r{\A(.*)\z}m, [[:name]]],
    ]
  end

  newparam(:name, namevar: true) do
    desc 'The name of the variable. Only letters, digits and underscores are allowed, the first character must not be a digit.'

    validate do |value|
      raise ArgumentError, "name must be a valid sh(1) variable name, got '#{value}'" unless value.is_a?(String) && value.match?(%r{\A[A-Za-z_][A-Za-z0-9_]*\z})
    end
  end

  newparam(:item, namevar: true) do
    desc <<-DOC
      A single entry of a whitespace-separated list variable. The entry must
      start with a letter, a digit, a dot or a slash, other first characters
      are treated as list delimiter by sysrc(8). Whitespace, quotes,
      backticks, dollar signs and backslashes are not allowed.
    DOC

    validate do |value|
      valid = value.is_a?(String) && value.match?(%r{\A[A-Za-z0-9./][^\s"'`$\\]*\z})
      raise ArgumentError, "item must start with a letter, digit, dot or slash and must not contain whitespace, quotes, backticks, dollar signs or backslashes, got '#{value}'" unless valid
    end
  end

  newparam(:target, namevar: true) do
    desc 'The absolute path of the file that contains the variable.'

    defaultto '/etc/rc.conf'

    validate do |value|
      raise ArgumentError, "target must be an absolute path, got '#{value}'" unless value.is_a?(String) && value.match?(%r{\A/[^@]*[^/@]\z})
    end
  end

  newproperty(:value) do
    desc <<-DOC
      The value of the variable. `true` and `false` are converted to `YES`
      and `NO`, integers are converted to strings. The value is compared with
      the value reported by sysrc(8), which evaluates the file with sh(1).
      Therefore double quotes, backticks, dollar signs, backslashes and line
      breaks are not allowed.
    DOC

    munge do |value|
      case value
      when true then 'YES'
      when false then 'NO'
      else value.to_s
      end
    end

    validate do |value|
      raise ArgumentError, "value must be a string, an integer or a boolean, got #{value.class}" unless [String, Integer, TrueClass, FalseClass].any? { |klass| value.is_a?(klass) }
      raise ArgumentError, "value must not contain double quotes, backticks, dollar signs, backslashes or line breaks, got '#{value}'" if value.to_s.match?(%r{["`$\\\n]})
    end
  end

  validate do
    raise ArgumentError, 'value must not be set together with item' if self[:item] && !self[:value].nil?
  end

  autorequire(:file) do
    [self[:target], File.dirname(self[:target])]
  end
end
