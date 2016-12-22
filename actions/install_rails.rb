module BarkestServerPrep
  module InstallRails

    def install_rails(shell)
      if global_ruby?
        shell.sudo_exec "gem install rails -v #{rails_version}"
      else
        shell.exec "gem install rails -v #{rails_version}"
        shell.exec 'rbenv rehash'
      end
    end

  end
end