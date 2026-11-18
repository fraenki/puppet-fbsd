# frozen_string_literal: true

Puppet::Type.newtype(:fbsd_sysctl) do
  desc <<-DOC
    @summary Manages a sysctl(8) variable in sysctl.conf(5) and in the running kernel.

    The variable is identified by its name and the file (`target`) it is
    written to: /etc/sysctl.conf, /etc/sysctl.conf.local or
    /etc/sysctl.kld.d/<module>.conf. Settings in /etc/sysctl.kld.d are applied
    at boot after the kernel module <module> was loaded via `kld_list`.

    With `apply` enabled (default), the value in the running kernel is
    compared with the requested value and set with sysctl(8) if it differs.
    Variables that do not exist in the running kernel, e.g. because the
    kernel module is not loaded yet, are only written to the file.

    The title has the form `name` or `name@target`, e.g.
    `net.link.bridge.pfil_member@/etc/sysctl.kld.d/if_bridge.conf`. Without
    a target in the title or the `target` attribute, the variable is managed
    in /etc/sysctl.conf.

    @example Disable logging of fatal signals
      fbsd_sysctl { 'kern.logsigexit':
        value => 0,
      }

    @example Host-specific value in /etc/sysctl.conf.local
      fbsd_sysctl { 'kern.ipc.somaxconn@/etc/sysctl.conf.local':
        value => 1024,
      }
  DOC

  ensurable do
    desc 'Whether the variable should be present or absent in the target file. Removing the variable does not change the value in the running kernel.'

    defaultvalues
    defaultto :present
  end

  # @return [Array<Array>] the patterns that split a title into name and target
  def self.title_patterns
    [
      [%r{\A([^@]+)@(/.*)\z}m, [[:name], [:target]]],
      [%r{\A(.*)\z}m, [[:name]]],
    ]
  end

  newparam(:name, namevar: true) do
    desc 'The name of the sysctl(8) variable, e.g. `kern.logsigexit`.'

    validate do |value|
      raise ArgumentError, "name must be a valid sysctl name, got '#{value}'" unless value.is_a?(String) && value.match?(%r{\A[A-Za-z0-9_][A-Za-z0-9_.%-]*\z})
    end
  end

  newparam(:target, namevar: true) do
    desc 'The file that contains the variable: /etc/sysctl.conf, /etc/sysctl.conf.local or /etc/sysctl.kld.d/<module>.conf.'

    defaultto '/etc/sysctl.conf'

    validate do |value|
      valid = value.is_a?(String) && value.match?(%r{\A(/etc/sysctl\.conf(\.local)?|/etc/sysctl\.kld\.d/[A-Za-z0-9_.-]+\.conf)\z})
      raise ArgumentError, "target must be /etc/sysctl.conf, /etc/sysctl.conf.local or /etc/sysctl.kld.d/<module>.conf, got '#{value}'" unless valid
    end
  end

  newparam(:apply, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc <<-DOC
      Whether the value in the running kernel should be managed as well. Set
      to `false` for variables that cannot be changed at runtime or whose
      value is reported in a different format than it is configured.
    DOC

    defaultto true
  end

  newproperty(:value) do
    desc <<-DOC
      The value of the variable. Integers are converted to strings. Double
      quotes and line breaks are not allowed. Values are equal if they are
      identical strings or represent the same integer.
    DOC

    munge(&:to_s)

    validate do |value|
      raise ArgumentError, "value must be a string or an integer, got #{value.class}" unless value.is_a?(String) || value.is_a?(Integer)
      raise ArgumentError, "value must not contain double quotes or line breaks, got '#{value}'" if value.to_s.match?(%r{["\n]})
    end

    # Compares the value in the file and, if `apply` is enabled, the value in
    # the running kernel with the requested value.
    #
    # @param is [String] the value in the file
    # @return [Boolean] whether no change is needed
    def insync?(is)
      @runtime_is = nil
      return false unless provider.class.values_equal?(is, should)
      return true unless resource[:apply]

      runtime = provider.runtime_value
      return true if runtime.nil? || provider.class.values_equal?(runtime, should)

      @runtime_is = runtime
      false
    end

    # @param current [String] the value in the file
    # @param newvalue [String] the requested value
    # @return [String] the change message, naming the runtime value if only
    #   the running kernel differs
    def change_to_s(current, newvalue)
      return super if @runtime_is.nil?

      "runtime value changed '#{@runtime_is}' to '#{newvalue}'"
    end
  end

  autorequire(:file) do
    [self[:target], File.dirname(self[:target])]
  end
end
