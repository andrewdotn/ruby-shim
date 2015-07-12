require 'fileutils'
require 'timeout'
require 'tmpdir'

describe 'ruby-shim' do

  def prepend_ruby_shim_to_path_as_ruby_in_tmpdir
    tmpdir = Dir.mktmpdir('ruby-shim-rspec')
    %w[bundle ri ruby irb gem].each do |f|
      File.symlink(File.expand_path('../../lib/ruby-shim.rb', __FILE__),
                   File.expand_path(f, tmpdir))
    end
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
        expect(`ruby --ruby-version=#{version} -e 'puts RUBY_VERSION'`).to(
            start_with(version))
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

      it "runs irb under ruby version #{version}" do
        Dir.mktmpdir('ruby-shim-spec') do |tmpdir|
          Dir.chdir(tmpdir) do
            IO.write('.ruby-version', version)
            expect(`echo 'irb_jobs && puts(RUBY_VERSION)' | irb -f`).to(
                match(/^#{version}/))
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

    %w[2.0 2.2].each do |version|
      context "--ruby-version=#{version}" do
        it "works with rails" do
          Dir.mktmpdir('ruby-shim-spec') do |tmpdir|
            Dir.chdir(tmpdir) do
              File.open('.ruby-version', 'w') do |w|
                w.write(version)
              end
              File.open('Gemfile', 'w') do |w|
                w.puts("gem 'railties', '~> 4.2.3'")
              end

              to_put_back = {}
              ENV.keys.grep /^BUNDLE/ do |k|
                to_put_back[k] = ENV.delete k unless k == 'BUNDLE_JOBS'
              end
              begin
                system("bundle install --local")
                system("bundle exec rails new testapp")
                Dir.chdir('testapp') do
                  begin
                    Timeout.timeout(10) do
                      expect(`bin/rails generate --help`)
                          .to include('integration_test')
                    end
                    ensure
                    system("bin/spring stop")
                  end
                end
              ensure
                to_put_back.each { |k, v| ENV[k] = v }
              end
            end
          end
        end
      end
    end
  end
end
