module BarkestServerPrep
  module InstallPassenger

    def install_passenger(shell)
      case host_id
        when :centos
          centos_install_passenger shell
        when :ubuntu
          ubuntu_install_passenger shell
        when :raspbian
          raspbian_install_passenger shell
        else
          raise 'not implemented'
      end
    end

    private

    def centos_install_passenger(shell)
      # epel is already enabled from install_prereqs.
      shell.sudo_exec 'yum -y install pygpgme curl'
      shell.sudo_exec 'curl --fail -sSLo /etc/yum.repos.d/passenger.repo https://oss-binaries.phusionpassenger.com/yum/definitions/el-passenger.repo'
      shell.sudo_exec 'yum -y install nginx passenger'
      shell.sudo_exec 'systemctl stop nginx' rescue nil
      shell.sudo_exec 'systemctl start nginx'
      shell.sudo_exec 'systemctl enable nginx'
    end

    def ubuntu_install_passenger(shell)
      distros = {
          '12.04' => 'precise',
          '12.10' => 'quantal',
          '13.04' => 'raring',
          '13.10' => 'saucy',
          '14.04' => 'trusty',
          '14.10' => 'utopic',
          '15.04' => 'vivid',
          '15.10' => 'wily',
          '16.04' => 'xenial',
          '16.10' => 'yakkety',
      }

      distro = distros[host_info['VERSION_ID']]

      shell.sudo_exec 'apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7'
      shell.sudo_exec 'apt-get -y -q install apt-transport-https ca-certificates'
      shell.sudo_exec "echo deb https://oss-binaries.phusionpassenger.com/apt/passenger #{distro} main > /etc/apt/sources.list.d/passenger.list"
      shell.sudo_exec 'apt-get -q update'
      shell.sudo_exec 'apt-get -y -q install nginx-extras passenger'
      shell.sudo_exec 'systemctl stop nginx' rescue nil
      shell.sudo_exec 'systemctl start nginx'
      shell.sudo_exec 'systemctl enable nginx'
    end

    def raspbian_install_passenger(shell)

      # get the home path for the current user.
      home_path = shell.exec("eval echo ~#{admin_user}").to_s.split("\n").first.to_s.strip
      raise 'failed to locate admin user\'s home path' if home_path == ''

      shell.sudo_exec 'gem install passenger'
      shell.sudo_exec 'passenger-install-nginx-module --auto --auto-download --languages ruby'

      shell.write_file "#{home_path}/nginx.service",
          <<-EOSCRIPT
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/opt/nginx/sbin/nginx -t
ExecStart=/opt/nginx/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
      EOSCRIPT

      shell.sudo_exec "mv #{home_path}/nginx.service /lib/systemd/system/nginx.service"

      shell.sudo_exec 'systemctl daemon-reload'
      shell.sudo_exec 'systemctl enable nginx'

      shell.exec 'export PATH="/opt/nginx/sbin:$PATH"'
    end

  end
end