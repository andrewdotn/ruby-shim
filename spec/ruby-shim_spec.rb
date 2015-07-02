require 'fileutils'
require 'tmpdir'

describe 'ruby-shim' do

  def prepend_ruby_shim_to_path_as_ruby_in_tmpdir
    tmpdir = Dir.mktmpdir('ruby-shim-rspec')
    File.symlink(File.expand_path('../../lib/ruby-shim.rb', __FILE__),
                 File.expand_path('ruby', tmpdir))
    ENV['PATH'] = "#{tmpdir}:#{ENV['PATH']}"
    tmpdir
  end

  before :all do
    @tmpdir = prepend_ruby_shim_to_path_as_ruby_in_tmpdir
  end

  after :all do
    FileUtils.remove_entry_secure @tmpdir
  end

  %w[2.0 2.2].each do |version|

    context "--ruby-version=#{version}" do
      it "runs ruby version #{version}" do
        expect(`ruby --ruby-version=#{version} -e 'puts RUBY_VERSION'`
              ).to start_with(version)
      end
    end

    context "current directory has .ruby-version=#{version}" do
      it "runs ruby version #{version}" do
        Dir.mktmpdir('ruby-shim-spec') do |tmpdir|
          Dir.chdir(tmpdir) do
            IO.write('.ruby-version', version)
            expect(`ruby -e 'puts RUBY_VERSION'`).to start_with(version)
          end
        end
      end
    end

    context "script’s folder has .ruby-version=#{version}" do
      it "runs ruby version #{version}" do
        Dir.mktmpdir('ruby-shim-spec') do |tmpdir|
          IO.write(Pathname.new(tmpdir).join('.ruby-version'), version)
          test_script = Pathname.new(tmpdir).join('test')
          IO.write(test_script.to_s, "#!/usr/bin/env ruby
puts RUBY_VERSION")
          test_script.chmod(0700)
          expect(`#{test_script}`).to start_with(version)
        end
        end
    end

  end

end
