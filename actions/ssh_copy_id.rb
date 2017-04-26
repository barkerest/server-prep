module BarkestServerPrep
  module SshCopyId

    def ssh_copy_id(shell)
      stat = shell.instance_variable_get(:@stat_console)

      # read the local RSA ID if possible.
      id_file = File.expand_path('~/.ssh/id_rsa.pub')
      data = File.exist?(id_file) ? File.read(id_file) : nil

      if data
        # we should be adding this to a blank account, so ...
        shell.exec "if [ ! -d #{deploy_home}/.ssh ]; then mkdir #{deploy_home}/.ssh; fi"
        shell.exec "chmod 700 #{deploy_home}/.ssh"

        # authorized_keys will simply be our public key.
        shell.write_file "#{deploy_home}/.ssh/authorized_keys", data
        shell.exec "chmod 600 #{deploy_home}/.ssh/authorized_keys"

        stat.append_data "\033[0;32;1mDone.\033[0m Public key setup.\n"
      else
        stat.append_data "\033[0;31mSkipped!\033[0m No rsa id for current user.\n"
      end

    end

  end
end