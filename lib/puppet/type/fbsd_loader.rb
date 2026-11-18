# frozen_string_literal: true

Puppet::Type.newtype(:fbsd_loader) do
  desc <<-DOC
    @summary Manages a single variable in loader.conf(5).

    The variable is identified by its name and the file (`target`) it is
    written to: /boot/loader.conf, /boot/loader.conf.local or
    /boot/loader.conf.d/<name>.conf. All other lines of the file are left
    untouched, so entries written by the installer are preserved. The
    variable is written as `name="value"`. Changes take effect on the next
    boot.

    The title has the form `name` or `name@target`, e.g.
    `autoboot_delay@/boot/loader.conf.local`. Without a target in the title
    or the `target` attribute, the variable is managed in /boot/loader.conf.

    @example Shorten the boot menu delay
      fbsd_loader { 'autoboot_delay':
        value => 3,
      }

    @example Load a kernel module at boot
      fbsd_loader { 'cryptodev_load@/boot/loader.conf.local':
        value => true,
      }
  DOC

  ensurable do
    desc 'Whether the variable should be present or absent in the target file.'

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
    desc 'The name of the loader variable, e.g. `autoboot_delay` or `vfs.zfs.arc.max`.'

    validate do |value|
      raise ArgumentError, "name must be a valid loader variable name, got '#{value}'" unless value.is_a?(String) && value.match?(%r{\A[A-Za-z0-9_][A-Za-z0-9_.%-]*\z})
    end
  end

  newparam(:target, namevar: true) do
    desc 'The file that contains the variable: /boot/loader.conf, /boot/loader.conf.local or /boot/loader.conf.d/<name>.conf.'

    defaultto '/boot/loader.conf'

    validate do |value|
      valid = value.is_a?(String) && value.match?(%r{\A(/boot/loader\.conf(\.local)?|/boot/loader\.conf\.d/[A-Za-z0-9_.-]+\.conf)\z})
      raise ArgumentError, "target must be /boot/loader.conf, /boot/loader.conf.local or /boot/loader.conf.d/<name>.conf, got '#{value}'" unless valid
    end
  end

  newproperty(:value) do
    desc <<-DOC
      The value of the variable. `true` and `false` are converted to `YES`
      and `NO`, integers are converted to strings. Double quotes and line
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
      raise ArgumentError, "value must not contain double quotes or line breaks, got '#{value}'" if value.to_s.match?(%r{["\n]})
    end
  end

  autorequire(:file) do
    [self[:target], File.dirname(self[:target])]
  end
end
