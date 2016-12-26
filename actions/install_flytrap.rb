require 'securerandom'

module BarkestServerPrep
  module InstallFlytrap

    FLY_TRAP_PING = 'ft_' + SecureRandom.hex(6)

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

    FLY_TRAP_SECRETS = <<-EOCFG
# [#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}]
# The secrets were generated specifically for this application installation.
test:
  secret_key_base: #{SecureRandom.urlsafe_base64(60)}
development:
  secret_key_base: #{SecureRandom.urlsafe_base64(60)}
production:
  secret_key_base: #{SecureRandom.urlsafe_base64(60)}
EOCFG

    private_constant :FLY_TRAP_PING, :FLY_TRAP_ROUTES, :FLY_TRAP_SECRETS

    def fly_trap_path
      "http://#{host}/#{FLY_TRAP_PING}"
    end

    def install_flytrap(shell)
      shell.exec "if [ ! -d #{deploy_home}/apps ]; then mkdir #{deploy_home}/apps; fi"
      shell.exec "chmod 775 #{deploy_home}/apps"
      # install the fly_trap app and write the new routes.rb file.
      shell.exec "git clone https://github.com/barkerest/fly_trap.git #{deploy_home}/apps/fly_trap"
      shell.write_file "#{deploy_home}/apps/fly_trap/config/routes.rb", FLY_TRAP_ROUTES
      shell.write_file "#{deploy_home}/apps/fly_trap/config/secrets.yml", FLY_TRAP_SECRETS
      # prep the app.
      shell.exec "cd #{deploy_home}/apps/fly_trap"
      shell.exec "bundle install --deployment"
      shell.exec "bundle exec rake db:migrate:reset RAILS_ENV=production"
      shell.exec "bundle exec rake assets:precompile RAILS_ENV=production RAILS_GROUPS=assets RAILS_RELATIVE_URL_ROOT=\"/\""
      shell.exec "cd #{deploy_home}"
      # generate the cron job.
      shell.exec "(crontab -l; echo \"*/5 * * * * curl http://localhost/#{FLY_TRAP_PING} >/dev/null 2>&1\";) | crontab -"
    end

  end
end