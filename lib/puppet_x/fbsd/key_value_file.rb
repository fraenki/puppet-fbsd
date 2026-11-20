# frozen_string_literal: true

require 'puppet/util'
require_relative '../fbsd'

# Reads and updates files with one `key=value` assignment per line, such as
# sysctl.conf(5) and loader.conf(5). Comments, empty lines and assignments of
# other keys are preserved unchanged.
module PuppetX::Fbsd::KeyValueFile
  # Splits a line into key and value.
  #
  # @param line [String] a line of the file
  # @param delimiters [String] the characters that separate key and value
  # @return [Array<String>, nil] the key and the unquoted value, or nil if the
  #   line is empty, a comment or not an assignment
  def self.parse_line(line, delimiters)
    content = line.strip
    return nil if content.empty? || content.start_with?('#')

    separators = Regexp.escape(delimiters)
    match = content.match(%r{\A([^#{separators}\s#]+)\s*[#{separators}]\s*(.*)\z})
    return nil if match.nil?

    [match[1], parse_value(match[2])]
  end

  # Removes one pair of surrounding quotes or, for unquoted values, a trailing
  # comment that starts with an unescaped `#`.
  #
  # @param raw [String] the value part of an assignment
  # @return [String] the value
  def self.parse_value(raw)
    quote = raw[0]
    if ['"', "'"].include?(quote)
      closing = raw.index(quote, 1)
      return raw[1...closing] unless closing.nil?
    end
    raw.sub(%r{\s*(?<!\\)#.*\z}, '').strip
  end

  # Reads all lines of a file.
  #
  # @param path [String] the absolute path of the file
  # @return [Array<String>] the lines including line endings, or an empty array
  #   if the file does not exist
  # @raise [Puppet::Error] if the file cannot be read
  def self.read(path)
    return [] unless File.exist?(path)

    File.readlines(path)
  rescue SystemCallError => e
    raise Puppet::Error, "Unable to read #{path}: #{e.message}"
  end

  # Returns all assignments of a file. If a key is assigned more than once,
  # the last assignment wins.
  #
  # @param path [String] the absolute path of the file
  # @param delimiters [String] the characters that separate key and value
  # @return [Hash{String => String}] the values by key
  def self.entries(path, delimiters)
    read(path).each_with_object({}) do |line, result|
      parsed = parse_line(line, delimiters)
      result[parsed[0]] = parsed[1] unless parsed.nil?
    end
  end

  # Returns the effective value of a key.
  #
  # @param path [String] the absolute path of the file
  # @param key [String] the key to look up
  # @param delimiters [String] the characters that separate key and value
  # @return [String, nil] the value of the last assignment, or nil if the key
  #   is not assigned
  def self.value(path, key, delimiters)
    entries(path, delimiters)[key]
  end

  # Replaces every assignment of a key with the given line, or appends the
  # line if the key is not assigned yet.
  #
  # @param path [String] the absolute path of the file
  # @param key [String] the key to set
  # @param line [String] the complete assignment without line ending
  # @param delimiters [String] the characters that separate key and value
  # @return [void]
  def self.set(path, key, line, delimiters)
    replaced = false
    lines = read(path).map do |current|
      parsed = parse_line(current, delimiters)
      next current unless parsed && parsed[0] == key

      replaced = true
      "#{line}\n"
    end
    unless replaced
      lines[-1] = "#{lines[-1]}\n" unless lines.empty? || lines[-1].end_with?("\n")
      lines << "#{line}\n"
    end
    write(path, lines)
  end

  # Removes every assignment of a key.
  #
  # @param path [String] the absolute path of the file
  # @param key [String] the key to remove
  # @param delimiters [String] the characters that separate key and value
  # @return [void]
  def self.remove(path, key, delimiters)
    lines = read(path).reject do |current|
      parsed = parse_line(current, delimiters)
      parsed && parsed[0] == key
    end
    write(path, lines)
  end

  # Writes a file atomically. A new file is created with mode 0644, an
  # existing file keeps its mode and owner.
  #
  # @param path [String] the absolute path of the file
  # @param lines [Array<String>] the lines including line endings
  # @return [void]
  def self.write(path, lines)
    Puppet::Util.replace_file(path, '0644') do |file|
      file.write(lines.join)
    end
  end
end
