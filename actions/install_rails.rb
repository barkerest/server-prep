module BarkestServerPrep
  module InstallRails

    def install_rails(shell)
      shell.exec "gem install rails -v #{rails_version}"
      shell.exec 'rbenv rehash'
    end

  end
end