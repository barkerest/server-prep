module BarkestServerPrep
  module UpdateSystem

    def update_system(shell)
      case host_id
        when :centos
          centos_update_system shell
        when :ubuntu
          ubuntu_update_system shell
        else
          raise 'not implemented'
      end
    end

    private

    def centos_update_system(shell)
      shell.sudo_exec('yum -y update') { |data,_| print data }
    end

    def ubuntu_update_system(shell)
      shell.sudo_exec('apt-get update && apt-get -y upgrade')
    end

  end
end