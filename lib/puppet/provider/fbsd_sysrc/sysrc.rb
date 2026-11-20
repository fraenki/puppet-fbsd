# frozen_string_literal: true

Puppet::Type.type(:fbsd_sysrc).provide(:sysrc) do
  desc 'Manages rc.conf(5) style variables with sysrc(8).'

  # @return [String] the absolute path of sysrc(8)
  def self.sysrc_path
    '/usr/sbin/sysrc'
  end

  commands sysrc: sysrc_path
  confine 'os.name' => :freebsd
  defaultfor 'os.name' => :freebsd

  # Runs sysrc(8).
  #
  # @param args [Array<String>] the command line arguments
  # @param failonfail [Boolean] whether a non-zero exit code raises an error
  # @return [Puppet::Util::Execution::ProcessOutput] the standard output
  def self.run(*args, failonfail: true)
    execute([sysrc_path] + args, failonfail: failonfail, combine: false)
  end

  # @return [Array<String>] the existing files that are read by rc(8) and
  #   periodic(8): /etc/rc.conf, /etc/rc.conf.local, all files in
  #   /etc/rc.conf.d, /etc/periodic.conf, /etc/periodic.conf.local and
  #   /usr/local/etc/periodic.conf
  def self.target_files
    rc_files = ['/etc/rc.conf', '/etc/rc.conf.local'] + Dir.glob(['/etc/rc.conf.d/*', '/etc/rc.conf.d/*/*']).sort
    periodic_files = ['/etc/periodic.conf', '/etc/periodic.conf.local', '/usr/local/etc/periodic.conf']
    (rc_files + periodic_files).select { |path| File.file?(path) }
  end

  # @param path [String] the absolute path of the file
  # @return [Array<String>] the names of all variables set in the file
  def self.variables(path)
    run('-f', path, '-a', '-N').to_s.split("\n").reject(&:empty?)
  end

  # @return [Array<Puppet::Provider>] one provider per variable of all files
  #   listed by `target_files`
  def self.instances
    target_files.flat_map do |path|
      variables(path).map do |variable|
        new(name: variable, target: path, ensure: :present)
      end
    end
  end

  # @return [String] the resource title in the form `name@target`
  def title
    "#{@property_hash[:name]}@#{@property_hash[:target]}"
  end

  # Without `item`, the variable exists if sysrc(8) reports the target file
  # as the location of its last assignment. Variables that are only set in
  # /etc/defaults/rc.conf do not exist. With `item`, the entry exists if it
  # is part of the value reported by sysrc(8).
  #
  # @return [Boolean] whether the variable or the list entry exists
  def exists?
    return items.include?(resource[:item]) if resource[:item]
    return false unless File.file?(resource[:target])

    self.class.run('-f', resource[:target], '-i', '-n', '-F', resource[:name], failonfail: false).to_s.strip == resource[:target]
  end

  # @return [void]
  # @raise [Puppet::Error] if neither item nor value is given
  def create
    return self.class.run('-f', resource[:target], "#{resource[:name]}+=#{resource[:item]}") if resource[:item]
    raise Puppet::Error, "#{resource.ref}: value is required when ensure is present" if resource[:value].nil?

    self.value = resource[:value]
  end

  # @return [void]
  def destroy
    return self.class.run('-f', resource[:target], "#{resource[:name]}-=#{resource[:item]}") if resource[:item]

    self.class.run('-f', resource[:target], '-x', resource[:name])
  end

  # @return [Array<String>] the whitespace-separated entries of the value
  #   reported by sysrc(8), or an empty array if the variable is not set
  def items
    return [] unless File.file?(resource[:target])

    self.class.run('-f', resource[:target], '-i', '-n', resource[:name], failonfail: false).to_s.split
  end

  # @return [String] the value as evaluated by sysrc(8)
  def value
    self.class.run('-f', resource[:target], '-n', resource[:name]).to_s.chomp
  end

  # @param should [String] the requested value
  # @return [void]
  def value=(should)
    self.class.run('-f', resource[:target], "#{resource[:name]}=#{should}")
  end
end
