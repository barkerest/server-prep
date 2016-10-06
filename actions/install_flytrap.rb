require 'securerandom'

module BarkestServerPrep
  module InstallFlytrap

    FLY_TRAP_PING = "ft-" + SecureRandom.urlsafe_base64(9)

    FLY_TRAP_ROUTES = <<-EOCFG
Rails.application.routes.draw do
  # [#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}]
  # This route defines the ping address, which is a unique address generated specifically for this web server.
  # No other web server or host knows it.
  # If you decide to change this address, you will want to update the associated crontab job as well.
  get '/#{FLY_TRAP_PING}', controller: 'trap', action: 'ping'

  # These two simply pour everything else into the trap controller for logging.
  get '/(:trigger)', trigger: /.+/, controller: 'trap', action: 'index'
  root 'trap#index'
end
    EOCFG

    private_constant :FLY_TRAP_PING, :FLY_TRAP_ROUTES

    def install_flytrap(shell)
      # install the fly_trap app and write the new routes.rb file.
      shell.exec "git clone https://github.com/barkerest/fly_trap.git #{deploy_home}/fly_trap"
      shell.write_file "#{deploy_home}/fly_trap/config/routes.rb", FLY_TRAP_ROUTES
      shell.exec "cd #{deploy_home}/fly_trap && bundle install && rake db:migrate:reset"
      shell.exec "cd #{deploy_home}"
      # generate the cron job.
      shell.exec "(crontab -l; echo \"*/5 * * * * wget http://localhost/#{FLY_TRAP_PING} >/dev/null 2>&1\";) | crontab -"
    end

  end
end