#!/usr/bin/env ruby

REQUIRED_SHELLS_VERSION = '0.1.9'

begin
  require 'shells'
  raise "Requires 'shells' gem version #{REQUIRED_SHELLS_VERSION} or greater." unless Gem::Version.new(Shells::VERSION) >= Gem::Version.new(REQUIRED_SHELLS_VERSION)
rescue LoadError
  raise "Requires 'shells' gem version #{REQUIRED_SHELLS_VERSION} or greater."
end


require 'io/console'
require 'securerandom'
require_relative './status_console.rb'

require_relative './actions/get_config.rb'
require_relative './actions/update_system.rb'
require_relative './actions/configure_ssh.rb'
require_relative './actions/add_deploy_user.rb'
require_relative './actions/ssh_copy_id.rb'
require_relative './actions/install_prereqs.rb'
require_relative './actions/install_rbenv.rb'
require_relative './actions/install_ruby.rb'
require_relative './actions/install_rails.rb'
require_relative './actions/install_db.rb'
require_relative './actions/install_passenger.rb'
require_relative './actions/configure_passenger.rb'
require_relative './actions/create_nginx_utils.rb'
require_relative './actions/install_flytrap.rb'
require_relative './actions/restart_nginx.rb'

class ServerPrep

  include BarkestServerPrep::GetConfig
  include BarkestServerPrep::UpdateSystem
  include BarkestServerPrep::ConfigureSsh
  include BarkestServerPrep::AddDeployUser
  include BarkestServerPrep::SshCopyId
  include BarkestServerPrep::InstallPrereqs
  include BarkestServerPrep::InstallRbenv
  include BarkestServerPrep::InstallRuby
  include BarkestServerPrep::InstallRails
  include BarkestServerPrep::InstallDb
  include BarkestServerPrep::InstallPassenger
  include BarkestServerPrep::ConfigurePassenger
  include BarkestServerPrep::CreateNginxUtils
  include BarkestServerPrep::InstallFlytrap
  include BarkestServerPrep::RestartNginx

  def initialize
    @stat_console = StatusConsole.new
  end

  def set_status(value)
    @stat_console.status_line = value
  end

  def perform
    admin_shell do |shell|
      set_status 'Updating system software...'
      update_system shell

      set_status 'Configuring SSH...'
      configure_ssh shell
    end
    admin_shell do |shell|
      set_status 'Installing prerequisites...'
      install_prereqs shell

      set_status 'Installing database engine...'
      install_db shell

      set_status 'Creating deployment user...'
      add_deploy_user shell

      deploy_shell do |shell2|
        set_status 'Installing SSH key...'
        ssh_copy_id shell2

        unless global_ruby?
          set_status 'Installing rbenv...'
          install_rbenv shell2
        end
      end

      if global_ruby?
        set_status "Installing Ruby #{ruby_version} (this will take a while)..."
        install_ruby_global shell

        set_status "Installing Rails #{rails_version} (this will take a while)..."
        install_rails shell
      else
        deploy_shell do |shell2|
          set_status "Installing Ruby #{ruby_version} (this will take a while)..."
          install_ruby shell2

          set_status "Installing Rails #{rails_version} (this will take a while)..."
          install_rails shell2
        end
      end

      deploy_shell do |shell2|
        set_status 'Installing fly_trap...'
        install_flytrap shell2
      end

      set_status 'Installing Phusion Passenger...'
      install_passenger shell

      set_status 'Configuring nginx & passenger...'
      configure_passenger shell

      set_status 'Creating nginx utilities...'
      create_nginx_utils shell

      set_status 'Restarting nginx...'
      restart_nginx shell

      set_status 'Running test against fly_trap...'
      shell.exec_ignore 'curl http://localhost/this-is-a-test'
      shell.exec "curl #{fly_trap_path}"
    end

    set_status ''

    print "\n\033[0m" + (' ' * IO.console_size[1]) + "\r"

    print <<-ENDSUMMARY
\033[0;32;1mServer prep has completed.\033[0m

Deployment User
--------------------------------------------------
User:     \033[0;1m#{deploy_user}\033[0m
Password: \033[0;1m#{deploy_password}\033[0m
Home:     \033[0;1m#{deploy_home}\033[0m

Server Test Path
--------------------------------------------------
\033[0;1m#{fly_trap_path}\033[0m

    ENDSUMMARY

    logfile.flush
    logfile.close
    @logfile = nil

  end

  private

  def logfile
    @logfile ||= File.open("server-prep_#{host}.log", 'wt')
  end

  def enhance_shell(shell)

    def shell.enable_echo
      @enable_echo = true
    end

    def shell.disable_echo
      @enable_echo = false
    end


    shell.instance_variable_set(:@stat_console, @stat_console)
    shell.instance_variable_set(:@prep, self)

    def shell.exec(command, options = {}, &block)
      ret =
          if @enable_echo
            super command, options do |data,type|
              @prep.send(:logfile).write(data)
              @prep.send(:logfile).flush
              @stat_console.append_data data
              if block
                block.call(data, type)
              else
                nil
              end
            end
          else
            super command, options do |data,type|
              @prep.send(:logfile).write(data)
              @prep.send(:logfile).flush
              if block
                block.call(data, type)
              else
                nil
              end
            end
          end

      @stat_console.append_data "\n" if @enable_echo

      ret
    end

    def shell.sudo_exec_ignore(command, &block)
      sudo_exec command, on_non_zero_exit_code: :ignore, &block
    end

    def shell.sudo_exec_raise(command, &block)
      sudo_exec command, on_non_zero_exit_code: :raise, &block
    end

    def shell.exec_ignore(command, &block)
      exec command, on_non_zero_exit_code: :ignore, &block
    end

    def shell.exec_raise(command, &block)
      exec command, on_non_zero_exit_code: :raise
    end

  end

  def admin_shell(auto_enable_echo = true, &block)
    Shells::SshSession.new(
        host: host,
        user: admin_user,
        password: admin_password,
        silence_wait: 0,
        retrieve_exit_code: true,
        on_non_zero_exit_code: :raise,
    ) do |shell|

      enhance_shell shell

      shell.enable_echo if auto_enable_echo

      yield shell
    end
  end

  def deploy_shell(auto_enable_echo = true, &block)
    Shells::SshSession.new(
        host: host,
        user: deploy_user,
        password: deploy_password,
        silence_wait: 0,
        retrieve_exit_code: true,
        on_non_zero_exit_code: :raise,
    ) do |shell|

      enhance_shell shell

      shell.enable_echo if auto_enable_echo

      yield shell
    end
  end

end


if $0 == __FILE__
  begin
    prep = ServerPrep.new
    if ARGV[0] == '-auto'
      prep.use_default_config ARGV[1], ARGV[2], ARGV[3]
    else
      prep.get_config

      print "\nRuby #{prep.ruby_version} with Rails #{prep.rails_version}.\nPlease ensure that the Rails version is compatible with the Ruby version.\n"
      print 'Press <ENTER> to start the configuration, or <CTRL>+<C> to cancel.'
      STDIN.gets
    end

    print "\033[2J\n"
    print "\033[2J\n"

    prep.perform
  ensure
    # reset the console formatting.
    print "\033[0J\033[0m\n"
  end
end
