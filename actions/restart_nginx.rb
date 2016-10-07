module BarkestServerPrep
  module RestartNginx

    def restart_nginx(shell)

      # test the configuration.
      shell.sudo_exec('nginx -t')

      # stop the service.
      shell.sudo_exec 'systemctl stop nginx.service' rescue nil

      # start the service.
      shell.sudo_exec 'systemctl start nginx.service'

    end

  end
end