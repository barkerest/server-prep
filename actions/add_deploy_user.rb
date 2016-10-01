module BarkestServerPrep
  module AddDeployUser

    attr_accessor :deploy_home

    def add_deploy_user(shell)
      # clean up first
      shell.sudo_exec "userdel -fr #{deploy_user}"
      shell.sudo_exec "groupdel #{deploy_user}"

      # recreate the user.
      shell.sudo_exec "useradd -mU -s /bin/bash #{deploy_user}"
      shell.sudo_exec "printf \"#{deploy_password}\\n#{deploy_password}\\n\" | passwd #{deploy_user}"

      # add the user's group to the admin user.
      shell.sudo_exec "usermod -G #{deploy_user} -a #{admin_user}"

      # set the permissions on the user's home directory.
      # it should be /home/deploy or some such, but let's not assume so.
      self.deploy_home = shell.exec("eval echo \"~#{deploy_user}\"").partition("\n")[0].strip
      shell.sudo_exec "chown #{deploy_user}:#{deploy_user} \"#{deploy_home}\""
      shell.sudo_exec "chmod 775 \"#{deploy_home}\""

    end

  end
end