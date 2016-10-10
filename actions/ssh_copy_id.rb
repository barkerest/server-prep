module BarkestServerPrep
  module SshCopyId

    def ssh_copy_id(shell)

      if File.exist?('~/.ssh/rsa_id.pub')
        data = File.read('~/.ssh/rsa_id.pub')

        # we should be adding this to a blank account, so ...
        shell.exec 'if [ ! -d ~/.ssh ]; then mkdir ~/.ssh; fi'
        shell.exec 'chmod 700 ~/.ssh'

        # authorized_keys will simply be our public key.
        shell.write_file "#{deploy_home}/authorized_keys", data
        shell.exec 'chmod 600 ~/.ssh/authorized_keys'

        @status_console.append_data "\033[0;32;1mDone.\033[0m Key based authentication should be enabled.\n"
      else
        @status_console.append_data "\033[0;31mSkipped!\033[0m No rsa id for current user.\n"
      end

    end

  end
end