module BarkestServerPrep
  module RestartNginx

    def restart_nginx(shell)

      # test the configuration.
      shell.sudo_exec('/usr/local/bin/nginx-test')

      # stop the service.
      shell.sudo_exec_ignore 'systemctl stop nginx.service'

      # start the service.
      shell.sudo_exec 'systemctl start nginx.service'

    end

  end
end