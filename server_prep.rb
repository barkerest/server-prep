#!/usr/bin/env ruby

require 'barkest_ssh'
require 'io/console'
require 'securerandom'

raise "Requires 'barkest_ssh' version 1.1.0 or greater." unless BarkestSsh::VERSION.to_f >= 1.1

require_relative './actions/get_config.rb'
require_relative './actions/update_system.rb'
require_relative './actions/add_deploy_user.rb'
require_relative './actions/install_prereqs.rb'
require_relative './actions/install_rbenv.rb'
require_relative './actions/install_ruby.rb'
require_relative './actions/install_rails.rb'
require_relative './actions/install_db.rb'
require_relative './actions/install_passenger.rb'
require_relative './actions/configure_passenger.rb'

class ServerPrep

  include BarkestServerPrep::GetConfig
  include BarkestServerPrep::UpdateSystem
  include BarkestServerPrep::AddDeployUser
  include BarkestServerPrep::InstallPrereqs
  include BarkestServerPrep::InstallRbenv
  include BarkestServerPrep::InstallRuby
  include BarkestServerPrep::InstallRails
  include BarkestServerPrep::InstallDb
  include BarkestServerPrep::InstallPassenger
  include BarkestServerPrep::ConfigurePassenger

  def perform
    admin_shell do |shell|
      print "Updating system software...\n"
      update_system shell

      print "Installing prerequisites...\n"
      install_prereqs shell

      print "Creating deployment user...\n"
      add_deploy_user shell
    end
    deploy_shell do |shell|
      print "Installing rbenv...\n"
      install_rbenv shell
    end
    deploy_shell do |shell|
      print "Installing Ruby #{ruby_version} (this will take a while)...\n"
      install_ruby shell

      print "Installing Rails #{rails_version} (this will take a while)...\n"
      install_rails shell
    end
    admin_shell do |shell|
      print "Installing database engine...\n"
      install_db shell

      print "Installing Phusion Passenger...\n"
      install_passenger shell

      print "Configuring nginx & passenger...\n"
      configure_passenger shell
    end

    print "Server prep is complete.\nThe deployment user details are as follows:\nUser: #{deploy_user}\nPassword: #{deploy_password}\nHome: #{deploy_home}\n\n"

  end

  private

  def enable_echo(shell)

    def shell.enable_echo
      @enable_echo
    end
    def shell.enable_echo=(value)
      @enable_echo = value
    end

    def shell.exec(command, &block)
      if enable_echo
        super command do |data,type|
          print data
          if block
            block.call(data, type)
          else
            nil
          end
        end
      else
        super command, &block
      end
    end

  end

  def enable_sudo(shell)
    shell.instance_variable_set(:@sudo_password, admin_password)

    def shell.sudo_exec(command, &block)
      sudo_prompt = "sudo_password:"
      sudo_regex = /sudo_password:\w*$/

      self.exec("sudo -p \"#{sudo_prompt}\" bash -c \"#{command.gsub('"','\\"')}\"") do |data,type|
        if sudo_regex.match(data)
          @sudo_password
        else
          if block
            block.call(data, type)
          else
            nil
          end
        end
      end

    end

  end

  def admin_shell(&block)
    BarkestSsh::SecureShell.new(
        host: host,
        user: admin_user,
        password: admin_password,
        silence_wait: 0,
    ) do |shell|

      enable_echo shell
      enable_sudo shell

      yield shell
    end
  end

  def deploy_shell(&block)
    BarkestSsh::SecureShell.new(
        host: host,
        user: deploy_user,
        password: deploy_password,
        silence_wait: 0,
    ) do |shell|

      enable_echo shell

      yield shell
    end
  end

end


if $0 == __FILE__
  prep = ServerPrep.new
  if ARGV[0] == '-auto'
    prep.use_default_config ARGV[1], ARGV[2], ARGV[3]
  else
    prep.get_config

    print "\nRuby #{prep.ruby_version} with Rails #{prep.rails_version}.\nPlease ensure that the Rails version is compatible with the Ruby version.\n"
    print 'Press <ENTER> to start the configuration, or <CTRL>+<C> to cancel.'
    STDIN.gets
  end

  print "\n"

  prep.perform
end
