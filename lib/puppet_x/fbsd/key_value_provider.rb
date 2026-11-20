# frozen_string_literal: true

require_relative '../fbsd'
require_relative 'key_value_file'

# Shared implementation of the providers that manage single keys in
# `key=value` files. A provider including this module must implement the
# class methods `delimiters`, `target_files` and `format_line`.
module PuppetX::Fbsd::KeyValueProvider
  # Adds the class methods to the including provider.
  #
  # @param base [Class] the provider class
  # @return [void]
  def self.included(base)
    base.extend(ClassMethods)
  end

  # Class methods of the providers.
  module ClassMethods
    # Returns one provider per key of all files listed by `target_files`.
    #
    # @return [Array<Puppet::Provider>] the providers of all existing keys
    def instances
      target_files.flat_map do |path|
        PuppetX::Fbsd::KeyValueFile.entries(path, delimiters).map do |key, value|
          new(name: key, target: path, ensure: :present, value: value)
        end
      end
    end
  end

  # @return [String] the resource title in the form `name@target`
  def title
    "#{@property_hash[:name]}@#{@property_hash[:target]}"
  end

  # @return [Boolean] whether the key is assigned in the target file
  def exists?
    !file_value.nil?
  end

  # Writes the key with the requested value to the target file.
  #
  # @return [void]
  # @raise [Puppet::Error] if no value is given
  def create
    raise Puppet::Error, "#{resource.ref}: value is required when ensure is present" if resource[:value].nil?

    write_value(resource[:value])
  end

  # Removes every assignment of the key from the target file.
  #
  # @return [void]
  def destroy
    PuppetX::Fbsd::KeyValueFile.remove(resource[:target], resource[:name], self.class.delimiters)
  end

  # @return [String, nil] the value in the target file
  def value
    file_value
  end

  # @param should [String] the requested value
  # @return [void]
  def value=(should)
    write_value(should)
  end

  private

  # @return [String, nil] the value of the last assignment in the target file
  def file_value
    PuppetX::Fbsd::KeyValueFile.value(resource[:target], resource[:name], self.class.delimiters)
  end

  # Writes the key unless the target file already contains the value.
  #
  # @param should [String] the requested value
  # @return [void]
  def write_value(should)
    return if file_value == should

    line = self.class.format_line(resource[:name], should)
    PuppetX::Fbsd::KeyValueFile.set(resource[:target], resource[:name], line, self.class.delimiters)
  end
end
