#!/usr/bin/ruby

require 'pathname'

class RubyShim

  RUBY_SHIM_PATH = Pathname.new(__FILE__).realpath

  # Find and execuate appropriate version of ruby.
  def main(args=ARGV)

    # If there are two ruby-shims on PATH, they will try to probe each other
    # recursively, resulting in livelock.
    if ENV.has_key?("RUBY_SHIM_PROBING")
      puts "ruby-shim\nn/a\n"
      exit 11 # EDEADLK
    end
    ENV["RUBY_SHIM_PROBING"] = "true"

    from_args = nil
    from_script = nil
    from_pwd = nil
    finder = RubyFinder.new
    if (args[0] || '').start_with? '--ruby-version'
      from_args = args.shift.split('=', 2)[1]
    end

    if from_args.nil? || from_args == 'help'
      from_script = version_from_dir(find_script(args))
      if from_script.nil?
        from_pwd = version_from_dir(Dir.pwd)
      end
    end

    desired_version = (from_args != 'help' ? from_args : nil) ||
                                  from_script ||
                                  from_pwd
    ruby = finder.for_version(desired_version)
    ruby ||= finder.available_versions[0]

    if from_args == 'help'
      puts 'ruby-shim usage: ruby [--ruby-version=VERSION|help] [ruby args]'
      puts
      puts 'Available versions from $PATH:'
      finder.available_versions.each do |v|
        selected = ruby[:ruby] == v[:ruby] ? '*' : ' '
        puts "#{selected} #{v[:RUBY_VERSION]} #{v[:ruby]}"
      end
      exit 0
    end

    if ruby.nil?
      STDERR.puts "No ruby version #{desired_version} available"
      exit 75 # EPROGMISMATCH
    end

    # These dev tools are special-cased to use the Ruby version inferred
    # from the current directory, instead of from the script directory.
    dev_script = File.basename($0)
    if %w[bundle gem irb ri].include? dev_script
      if File.exist? "/usr/bin/#{dev_script}"
        dev_script = "/usr/bin/#{dev_script}"
      else
        dev_script = ENV['PATH'].split(':')
                           .reverse
                           .map { |p| Pathname.new(p).join(dev_script) }
                           .find(&:executable?)
                           .to_s
      end
      args.insert(0, dev_script)
    end

    ENV.delete("RUBY_SHIM_PROBING")

    ENV["GEM_HOME"] = ruby[:GEM_HOME]
    exec *([ruby[:ruby]] + args), close_others: false
    exit 8 # ENOEXEC
  end

  # Find the script file in the ruby command line by looking for the first
  # argument that is a file that exists.
  # This would be more accurate but harder to maintain if it tried to
  # interpret ruby’s command-line arguments.
  def find_script(args)
    args.each { |arg| return arg if File.file?(arg) }
    return nil
  end

  # Return contents of first .ruby-version file in path or one of its parent
  # directories, or nil if there is none.
  def version_from_dir(path)
    return nil if path.nil?
    unless Pathname === path
      path = Pathname.new(path)
    end
    path = path.expand_path unless path.absolute?
    ruby_version = path.join('.ruby-version')
    if ruby_version.exist?
      return ruby_version.read.strip
    end
    parent = path.parent
    return nil if path == parent
    version_from_dir(path.parent)
  end

  class RubyFinder

    def available_versions
      (ENV['PATH'].split(':').map { |p| Pathname.new(p).join('ruby') }
                    .find_all(&:executable?)
                    .map(&:realpath)
                    .uniq
                    .reject { |r| r == RUBY_SHIM_PATH }
                    .map(&:to_s)
                    .map { |r| version_info(r) })
    end

    # Return first ruby in PATH matching supplied version spec.
    # Currently, matching is done by prefix testing on RUBY_VERSION.
    def for_version(version)
      return nil if version.nil?
      available_versions.each do |r|
        next if r.nil?
        if r[:RUBY_VERSION].start_with? version
          return r
        end
      end
      return nil
    end

    def version_info(ruby)
      output = IO.popen([ruby, '-e', 'puts RUBY_VERSION; puts Gem.user_dir'],
          in: '/dev/null', err: [:child, :out]) { |pipe| pipe.read }
      return nil unless $?.success?
      output_pieces = output.split("\n").map(&:strip)
      return {ruby: ruby,
              RUBY_VERSION: output_pieces[0],
              GEM_HOME: output_pieces[1]}
    end

  end

end

if __FILE__ == $0
  RubyShim.new.main
end
