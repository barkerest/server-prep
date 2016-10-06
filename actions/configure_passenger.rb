
require 'securerandom'

module BarkestServerPrep
  module ConfigurePassenger

    PASSENGER_ROOT_PLACEHOLDER = /\?\?PR/
    DEPLOY_HOME_PLACEHOLDER = /\?\?DH/

    PASSENGER_ROOT_PATH = 'ruby/vendor_ruby/phusion_passenger/locations.ini'
    PASSENGER_ROOT_SEARCH = %w(/usr/share /usr/lib)

    NGINX_CONFIG = <<-EOCFG
# General nginx configuration from BarkerEST server-prep script.

user              nginx;
worker_processes  1;
error_log         /var/log/nginx/error.log;
pid               /run/nginx.pid;

events {
  worker_connections 1024;
}

http {
  ##
  # Basic Settings
  ##

  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
  access_log        /var/log/nginx/access.log  main;

  sendfile on;
  index             index.html index.htm;

  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  types_hash_max_size 2048;

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
  # Phusion Passenger settings
  ##

  passenger_root                  ??PR;
  passenger_ruby                  ??DH/.rbenv/shims/ruby;
  passenger_instance_registry_dir /var/run/passenger-instreg;
  passenger_log_level             1;

  ##
  # Default server settings
  ##

  server {
    listen 80 default_server;
    listen 443 ssl;

    ssl_certificate       /var/ssl/ssl.crt;
    ssl_certificate_key   /var/ssl/ssl.key;

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



    private_constant :NGINX_CONFIG, :DEFAULT_LOC, :PASSENGER_ROOT_PLACEHOLDER, :DEPLOY_HOME_PLACEHOLDER, :PASSENGER_ROOT_PATH, :PASSENGER_ROOT_SEARCH

    def configure_passenger(shell)

      # add both users to each other.
      shell.sudo_exec "usermod -G nginx -a #{deploy_user}"
      shell.sudo_exec "usermod -G #{deploy_user} -a nginx"

      # backup and remove the original configuration.
      shell.sudo_exec 'if [ ! -f /etc/nginx/nginx.conf.original ]; then mv -f /etc/nginx/nginx.conf /etc/nginx/nginx.conf.original; fi'

      # get the passenger_root path.
      pr_path = shell.sudo_exec("ls {#{PASSENGER_ROOT_SEARCH.join(',')}}/#{PASSENGER_ROOT_PATH} 2>/dev/null") rescue nil
      pr_path = pr_path.to_s.split("\n").first.to_s.strip
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
        shell.sudo_exec "if [ ! -d #{loc} ]; then mkdir #{loc}; fi"
        shell.sudo_exec "chown nginx:nginx #{loc} && chmod 2775 #{loc}"
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
      shell.sudo_exec 'if [ ! -d /var/ssl ]; then mkdir /var/ssl; fi'
      shell.sudo_exec 'chown nginx:nginx /var/ssl && chmod 700 /var/ssl'
      shell.sudo_exec 'openssl dhparam -out /var/ssl/dhparams.pem 2048'
      shell.sudo_exec 'openssl req -x509 -nodes -days 365 -newkey rsa:4096 -subj "/C=US/ST=Pennsylvania/L=Pittsburgh/O=WEB/CN=$(hostname -f)" -keyout /var/ssl/ssl.key -out /var/ssl/ssl.crt'
      shell.sudo_exec 'chown nginx:nginx /var/ssl/* -R && chmod 600 /var/ssl/*'

    end

  end
end