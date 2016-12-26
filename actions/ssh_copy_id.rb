module BarkestServerPrep
  module SshCopyId

    def ssh_copy_id(shell)
      stat = shell.instance_variable_get(:@stat_console)

      # read the local RSA ID if possible.
      data = File.read('~/.ssh/id_rsa.pub') rescue nil

      if data
        # we should be adding this to a blank account, so ...
        shell.exec 'if [ ! -d ~/.ssh ]; then mkdir ~/.ssh; fi'
        shell.exec 'chmod 700 ~/.ssh'

        # authorized_keys will simply be our public key.
        shell.write_file "#{deploy_home}/authorized_keys", data
        shell.exec 'chmod 600 ~/.ssh/authorized_keys'

        stat.append_data "\033[0;32;1mDone.\033[0m Public key setup.\n"
      else
        stat.append_data "\033[0;31mSkipped!\033[0m No rsa id for current user.\n"
      end

    end

  end
end