# ruby-shim: A Non-magical Ruby Version Manager

### Andrew Neitsch • [andrew@neitsch.ca](mailto:andrew@neitsch.ca)

ruby-shim is a non-magical Ruby version manager that lets you easily invoke
different installed Ruby versions. It never changes your `$PATH` and never
hooks `cd`. It’s a replacement for [chruby][], [rbenv][], and [rvm][], with
a test suite to ensure correct behaviour in corner cases those tools can’t
handle.

[chruby]: https://github.com/postmodern/chruby
[rbenv]: https://github.com/sstephenson/rbenv
[rvm]: https://rvm.io

## Installation

 1. Create symlinks to `lib/ruby-shim.rb` named `bundle`, `ruby`, `gem`,
    `irb`, and `ri` somewhere early in your `$PATH`.
 2. Add other Rubies you’d like to run later in `$PATH`.
 3. Add `.ruby-version` files to `~/.gem/ruby/*/bin`.
 4. Add `install: --user-install --env-shebang` to `~/.gemrc`, to prevent
    RubyGems from hard-coding paths to specific Ruby interpreters in the
    wrapper scripts it generates.

For example, suppose you’re on a Mac that comes with Ruby 2.0 installed
in `/usr`, and you’ve installed Ruby 2.2 in `/opt/homebrew`. You can set
your PATH as:
  - ~/bin
  - ...
  - ~/.gem/ruby/2.2.0/bin
  - ~/.gem/ruby/2.0.0/bin
  - ...
  - /opt/homebrew/bin
  - ...
  - /usr/bin
  - ...

Your default Ruby will be 2.2, but you can get 2.0 with `ruby
--ruby-version=2.0`. Gem commands from Ruby 2.2 take precedence, but the
ones you installed under Ruby 2.0 still work.

## How it works

ruby-shim pretends to be `ruby` so that it gets called by any script
starting with `#!/usr/bin/env ruby`. Then it does the following:

 1. It determines which Ruby version is being requested by checking for the
    following items, in order, and using the first one it finds:

     1. `--ruby-version` as the first command-line argument
     2. A `.ruby-version` file in the script directory or a parent
     3. A `.ruby-version` file in the current directory or a parent
     4. The next `ruby` in `$PATH` that isn’t `ruby-shim`

 2. It runs the first matching version of Ruby that it finds on `$PATH`, or
    exits with an error message.

## Advantages

 - No dynamic changes to `$PATH`, which can suddenly place commands from
   random gems at the front of your `$PATH`.
 - No need to try to hook `cd`, which makes commands typed at the shell
   behave differently than when run from shell scripts or other programs.
 - You can run gem commands installed under different versions of Ruby,
   without knowing what version they were installed under, and without
   doing anything extra after installing new gems.
