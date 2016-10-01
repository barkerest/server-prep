module BarkestServerPrep
  module InstallRuby

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