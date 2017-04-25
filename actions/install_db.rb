module BarkestServerPrep
  module InstallDb

    def install_db(shell)
      case host_id
        when :centos
          centos_install_mariadb shell
        when :ubuntu, :raspbian, :debian
          debian_install_mariadb shell
        else
          raise 'not implemented'
      end
    end

    private

    def centos_install_mariadb(shell)
      shell.sudo_exec 'yum -y install mariadb-server mariadb-devel'
      shell.sudo_exec 'systemctl stop mariadb.service' rescue nil
      shell.sudo_exec 'systemctl start mariadb.service'
      shell.sudo_exec 'systemctl enable mariadb.service'
    end

    def debian_install_mariadb(shell)
      shell.sudo_exec 'debconf-set-selections <<< \'mariadb-server mysql-server/root_password password root\''
      shell.sudo_exec 'debconf-set-selections <<< \'mariadb-server mysql-server/root_password_again password root\''

      shell.sudo_exec 'apt-get -y -q install mariadb-server mariadb-client libmysqlclient-dev'
      shell.sudo_exec 'systemctl stop mysql.service' rescue nil
      shell.sudo_exec 'systemctl start mysql.service'
      shell.sudo_exec 'systemctl enable mysql.service'
    end


  end
end