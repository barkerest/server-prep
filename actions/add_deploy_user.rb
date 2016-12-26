module BarkestServerPrep
  module AddDeployUser

    attr_accessor :deploy_home

    def add_deploy_user(shell)
      # clean up first
      shell.sudo_exec "userdel -fr #{deploy_user}" rescue nil
      shell.sudo_exec "groupdel #{deploy_user}" rescue nil
      shell.sudo_exec "if [ -f /var/spool/cron/crontabs/#{deploy_user} ]; then rm -r /var/spool/cron/crontabs/#{deploy_user}; fi"

      # recreate the user.
      shell.sudo_exec "useradd -mU -s /bin/bash #{deploy_user}"
      shell.sudo_exec "printf \"#{deploy_password}\\n#{deploy_password}\\n\" | passwd #{deploy_user}"

      # add the user's group to the admin user.
      shell.sudo_exec "usermod -G #{deploy_user} -a #{admin_user}"

      # set the permissions on the user's home directory.
      # it should be /home/deploy or some such, but let's not assume so.
      self.deploy_home = shell.exec("eval echo \"~#{deploy_user}\"").split("\n").first.strip
      shell.sudo_exec "chown -R #{deploy_user}:#{deploy_user} #{deploy_home} && chmod 755 #{deploy_home}"

    end

  end
end