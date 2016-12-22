module BarkestServerPrep
  module UpdateSystem

    def update_system(shell)
      case host_id
        when :centos
          centos_update_system shell
        when :ubuntu, :raspbian
          debian_update_system shell
        else
          raise 'not implemented'
      end
    end

    private

    def centos_update_system(shell)
      shell.sudo_exec('yum -y update')
    end

    def debian_update_system(shell)
      shell.sudo_exec 'apt-get -q update'
      shell.sudo_exec 'apt-get -y -q upgrade'
    end

  end
end