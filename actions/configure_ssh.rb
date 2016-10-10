module BarkestServerPrep
  module ConfigureSsh

    def configure_ssh(shell)

      pa_rex = /#\s*PubkeyAuthentication\s+[^\n]*\n/
      rl_rex = /#\s*PermitRootLogin\s+[^\n]*\n/

      admin_home = shell.exec("eval echo \"~#{admin_user}\"").split("\n").first.strip

      shell.sudo_exec 'cp -f /etc/ssh/sshd_config ~/tmp_sshd_conf'

      contents = shell.read_file "#{admin_home}/tmp_sshd_conf"
      contents = contents
                     .gsub(pa_rex, "PubkeyAuthentication yes\n")  # enable public key
                     .gsub(rl_rex, "PermitRootLogin no\n")        # disable root login

      shell.write_file "#{admin_home}/tmp_sshd_conf", contents
      shell.sudo_exec 'chown root:root ~/tmp_sshd_conf'
      shell.sudo_exec 'chmod 600 ~/tmp_sshd_conf'
      shell.sudo_exec 'mv -f ~/tmp_sshd_conf /etc/ssh/sshd_config'

      # shouldn't disconnect us ... but who knows...
      shell.sudo_exec 'systemctl restart sshd.service' rescue nil

    end

  end
end