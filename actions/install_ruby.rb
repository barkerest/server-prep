module BarkestServerPrep
  module InstallRuby

    def global_ruby?
      host_id == :raspbian
    end

    def install_ruby_global(shell)
      mm = (/^(\d+\.\d+)\./).match(ruby_version)[1]

      result = shell.exec('ruby -v').to_s.partition("\n")[0].strip
      ver = ((/^ruby\s(#{ruby_version.gsub('.', '\.')})[^\d]*/).match(result) || [])[1]
      return nil if ver == ruby_version

      shell.exec "wget http://ftp.ruby-lang.org/pub/ruby/#{mm}/ruby-#{ruby_version}.tar.gz"
      shell.exec "tar -xzvf ruby-#{ruby_version}.tar.gz"
      shell.exec "cd ruby-#{ruby_version}"
      shell.exec "./configure --prefix=/usr"
      shell.exec "make"
      shell.sudo_exec "make install"

      result = shell.exec('ruby -v').to_s.partition("\n")[0].strip
      ver = ((/^ruby\s(#{ruby_version.gsub('.', '\.')})[^\d]*/).match(result) || [])[1]
      raise "ruby version mismatch '#{ver}' <> '#{ruby_version}'" unless ver == ruby_version

      shell.exec "echo 'gem: --no-ri --no-rdoc' > ~/.gemrc"
      shell.sudo_exec "echo 'gem: --no-ri --no-rdoc' > ~/.gemrc"
      shell.sudo_exec "gem install bundler"

      # get the path to the ruby gems libraries
      result = shell.exec('gem which bundler').to_s.partition("\n")[0].strip.partition("/gems/bundler-")[0]

      # now make it possible for the deploy user to install gems.
      # at least those that don't need to create a symlink to /usr/local/bin.
      shell.sudo_exec "chown -R :#{deploy_user} #{result}"
      shell.sudo_exec "chmod 2775 #{result}/*"

    end

    def install_ruby(shell)
      result = shell.exec('which rbenv').to_s.strip
      raise 'failed to install rbenv' if result == ''

      shell.exec "rbenv install #{ruby_version}"
      shell.exec "rbenv global #{ruby_version}"

      result = shell.exec('which ruby').to_s.partition("\n")[0].strip
      raise 'ruby not where expected' unless result == deploy_home + '/.rbenv/shims/ruby' || result == '~/.rbenv/shims/ruby'

      shell.exec "echo 'gem: --no-ri --no-rdoc' > ~/.gemrc"
      shell.exec 'gem install bundler'
      shell.exec 'rbenv rehash'
    end

  end
end