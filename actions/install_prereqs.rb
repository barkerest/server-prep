module BarkestServerPrep
  module InstallPrereqs

    def install_prereqs(shell)
      case host_id
        when :centos
          centos_install_prereqs shell
        when :ubuntu
          ubuntu_install_prereqs shell
        else
          raise 'not implemented'
      end
    end

    private

    def centos_install_prereqs(shell)
      shell.sudo_exec 'yum -y install git-core zlib zlib-devel gcc gcc-c++ patch readline readline-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison curl sqlite-devel policycoreutils-python'
      shell.sudo_exec 'yum -y install epel-release yum-utils'
      shell.sudo_exec 'yum-config-manager --enable epel'
      shell.sudo_exec 'yum -y install nodejs'
    end

    def ubuntu_install_prereqs(shell)
      shell.sudo_exec 'apt-get -y install git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev python-software-properties libffi-dev'
    end

  end
end