
require 'securerandom'

module BarkestServerPrep
  module ConfigurePassenger

    PASSENGER_ROOT_PLACEHOLDER = /\?\?PR/
    DEPLOY_HOME_PLACEHOLDER = /\?\?DH/

    PASSENGER_ROOT_PATH = 'ruby/vendor_ruby/phusion_passenger/locations.ini'
    PASSENGER_ROOT_SEARCH = %w(/usr/share /usr/lib)

    NGINX_CONFIG = <<-EOCFG
user nginx;
worker_processes 4;
pid /run/nginx.pid;

events {
  worker_connections 768;
  # multi_accept on;
}

http {
  ##
  # Basic Settings
  ##

  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  types_hash_max_size 2048;
  # server_tokens off;

  # server_names_hash_bucket_size 64;
  # server_name_in_redirect off;

  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  ##
  # SSL Settings
  ##

  ssl_protocols           TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers             DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:kEDH+AESGCM:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA;
  ssl_prefer_server_ciphers on;
  ssl_session_cache       shared:SSL:10m;
  ssl_session_timeout     5m;
  ssl_dhparam             /var/ssl/dhparams.pem;

  ##
  # Logging Settings
  ##

  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log error;

  ##
  # Gzip settings
  ##

  gzip on;
  gzip_disable "msie6";
  # gzip_vary on;
  # gzip_proxied any;
  # gzip_comp_level 6;
  # gzip_buffers 16 8k;
  # gzip_http_version 1.1;
  # gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

  ##
  # Phusion Passenger settings
  ##

  passenger_root ??PR;
  passenger_ruby ??DH/.rbenv/shims/ruby;
  passenger_instance_registry_dir /var/run/passenger-instreg;
  passenger_log_level 1;

  ##
  # Default server settings
  ##

  server {
    listen 80 default_server;
    listen 443 ssl;

    ssl_certificate /var/ssl/ssl.crt;
    ssl_certificate_key /var/ssl/ssl.key;

    # server_name www.somesite.com;

    proxy_set_header X-Forwarded-Proto $scheme;

    keepalive_timeout 70;

    include /etc/nginx/locations-enabled/*;
  }
}
    EOCFG

    DEFAULT_LOC = <<-EOCFG
# This is a sample rails app configuration that also happens to take care of ignoring zombie requests.
# See the fly_trap app's README for more information about it.
location / {
  # path to the public folder in your app.
  root                ??DH/fly_trap/public;

  # path rails will use as the root path, should match the path provided to location above.
  passenger_base_uri  /;

  rails_env           production;
  passenger_enabled   on;
}
    EOCFG

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

    private_constant :NGINX_CONFIG, :DEFAULT_LOC, :PASSENGER_ROOT_PLACEHOLDER, :DEPLOY_HOME_PLACEHOLDER, :PASSENGER_ROOT_PATH, :PASSENGER_ROOT_SEARCH, :FLY_TRAP_PING, :FLY_TRAP_ROUTES

    def configure_passenger(shell)

      # add both users to the nginx group.
      shell.sudo_exec "usermod -G nginx -a #{deploy_user}"
      shell.sudo_exec "usermod -G nginx -a #{admin_user}"

      # backup and remove the original configuration.
      shell.sudo_exec 'mv -f /etc/nginx/nginx.conf /etc/nginx/nginx.conf.original'

      # get the passenger_root path.
      pr_path = shell.sudo_exec("ls {#{PASSENGER_ROOT_SEARCH.join(',')}}/#{PASSENGER_ROOT_PATH} 2>/dev/null").to_s.split("\n").first.to_s.strip
      raise 'failed to locate passenger_root path' if pr_path == ''

      # get the home path for the current user.
      home_path = shell.exec("eval echo ~#{admin_user}").to_s.split("\n").first.to_s.strip
      raise 'failed to locate admin user\'s home path' if home_path == ''

      # write the new configuration to a temporary file.
      shell.write_file(
          "#{home_path}/nginx.conf",
          NGINX_CONFIG
              .gsub(PASSENGER_ROOT_PLACEHOLDER, pr_path)
              .gsub(DEPLOY_HOME_PLACEHOLDER, deploy_home)
      )

      # move it where it belongs.
      shell.sudo_exec "mv -f #{home_path}/nginx.conf /etc/nginx/nginx.conf"
      shell.sudo_exec 'chown root:root /etc/nginx/nginx.conf && chmod 644 /etc/nginx/nginx.conf'

      # create the location folders.
      %w(locations-available locations-enabled).each do |loc|
        loc = "/etc/nginx/#{loc}"
        shell.sudo_exec "mkdir #{loc} && chown nginx:nginx #{loc} && chmod 775 #{loc}"
      end

      # create the default location.
      shell.write_file(
          "#{home_path}/default.loc",
          DEFAULT_LOC
              .gsub(PASSENGER_ROOT_PLACEHOLDER, pr_path)
              .gsub(DEPLOY_HOME_PLACEHOLDER, deploy_home)
      )
      shell.sudo_exec "mv -f #{home_path}/default.loc /etc/nginx/locations-available/default"
      shell.sudo_exec 'chown nginx:nginx /etc/nginx/locations-available/default && chmod 664 /etc/nginx/locations-available/default'
      shell.sudo_exec "ln -s /etc/nginx/locations-available/default /etc/nginx/locations-enabled/default"

      # create the SSL files.
      shell.sudo_exec 'mkdir /var/ssl && chown nginx:nginx /var/ssl && chmod 700 /var/ssl'
      shell.sudo_exec 'openssl dhparam -out /var/ssl/dhparams.pem 2048'
      shell.sudo_exec 'openssl req -x509 -nodes -days 365 -newkey rsa:4096 -subj "/C=US/ST=Pennsylvania/L=Pittsburgh/O=WEB/CN=$(hostname -f)" -keyout /var/ssl/ssl.key -out /var/ssl/ssl.crt'

      # install the fly_trap app and write the new routes.rb file.
      shell.exec "git clone https://github.com/barkerest/fly_trap.git #{deploy_home}/fly_trap"
      shell.write_file "#{deploy_home}/fly_trap/config/routes.rb", FLY_TRAP_ROUTES
      shell.exec "cd #{deploy_home}/fly_trap && bundle && rake db:migrate:reset"
      shell.sudo_exec "chown deploy:deploy #{deploy_home}/fly_trap -R"

      # restart the nginx service
      shell.sudo_exec 'systemctl restart nginx.service'

      # generate the cron job.
      shell.sudo_exec "(crontab -l; echo \"*/5 * * * * wget http://localhost/#{FLY_TRAP_PING} >/dev/null 2>&1\";) | crontab -"

    end

  end
end