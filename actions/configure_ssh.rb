module BarkestServerPrep
  module ConfigureSsh

    def configure_ssh(shell)


      pa_rex = /[# \t]*PubkeyAuthentication[ \t][^\n]*\n/
      rl_rex = /[# \t]*PermitRootLogin[ \t][^\n]*\n/

      admin_home = shell.exec("eval echo \"~#{admin_user}\"").split("\n").first.strip

      shell.sudo_exec "cp -f /etc/ssh/sshd_config #{admin_home}/tmp_sshd_conf && chown #{admin_user}:#{admin_user} #{admin_home}/tmp_sshd_conf"

      contents = shell.read_file "#{admin_home}/tmp_sshd_conf"
      contents = contents
                     .gsub(pa_rex, "PubkeyAuthentication yes\n")      # enable public key
                     .gsub(rl_rex, "PermitRootLogin no\n")            # disable root login

      shell.write_file "#{admin_home}/tmp_sshd_conf", contents
      shell.sudo_exec "chown root:root #{admin_home}/tmp_sshd_conf"
      shell.sudo_exec "chmod 644 #{admin_home}/tmp_sshd_conf"
      shell.sudo_exec "mv -f #{admin_home}/tmp_sshd_conf /etc/ssh/sshd_config"

      # shouldn't disconnect us ... but who knows...
      shell.sudo_exec_ignore 'systemctl restart sshd.service'

    end

  end
end