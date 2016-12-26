
require 'securerandom'

module BarkestServerPrep
  module ConfigurePassenger

    PASSENGER_ROOT_PLACEHOLDER = /\?\?PR/
    DEPLOY_HOME_PLACEHOLDER = /\?\?DH/
    INST_REG_COMMENT_PLACEHOLDER = /\?\?IR/
    CONFIG_PATH_PLACEHOLDER = /\?\?CP/
    IP6_COMMENT_PLACEHOLDER = /\?\?I6/
    DEPLOY_RUBY_COMMENT_PLACEHOLDER = /\?\?DC/
    GLOBAL_RUBY_COMMENT_PLACEHOLDER = /\?\?GC/

    PASSENGER_ROOT_PATH = 'ruby/vendor_ruby/phusion_passenger/locations.ini'
    PASSENGER_ROOT_SEARCH = %w(/usr/share /usr/lib)

    NGINX_CONFIG = <<-EOCFG
# General nginx configuration from BarkerEST server-prep script.

user              ruby-apps;
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

  include ??CP/mime.types;
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
  ??DCpassenger_ruby                  ??DH/.rbenv/shims/ruby;
  ??GCpassenger_ruby                  /usr/bin/ruby;
  passenger_log_level             1;
  ??IRpassenger_instance_registry_dir /var/run/passenger-instreg;

  ##
  # Default server settings
  ##

  server {
    listen 80 default_server;
    ??I6listen [::]:80 default_server ipv6only=on;
    listen 443 ssl;
    ??I6listen [::]:443 ssl;

    ssl_certificate       /var/ssl/ssl.crt;
    ssl_certificate_key   /var/ssl/ssl.key;

    # Set this as appropriate.
    server_name localhost;

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
  root                ??DH/apps/fly_trap/public;

  # path rails will use as the root path, should match the path provided to location above.
  passenger_base_uri  /;

  rails_env           production;
  passenger_enabled   on;
}
    EOCFG



    private_constant :NGINX_CONFIG, :DEFAULT_LOC, :PASSENGER_ROOT_PLACEHOLDER, :DEPLOY_HOME_PLACEHOLDER, :PASSENGER_ROOT_PATH, :PASSENGER_ROOT_SEARCH, :INST_REG_COMMENT_PLACEHOLDER

    def configure_passenger(shell)

      # add the ruby-apps user.
      shell.sudo_exec_ignore "useradd -mU ruby-apps"

      # add both users to each other.
      shell.sudo_exec_ignore "usermod -G ruby-apps -a #{deploy_user}"
      shell.sudo_exec_ignore "usermod -G #{deploy_user} -a ruby-apps"

      # find the config file location.
      possible = %w(/etc/nginx/nginx.conf /opt/nginx/conf/nginx.conf).map {|v| "if [ -f #{v} ]; then echo #{v};" }
      conf_path = shell.sudo_exec(possible.join(" el") + ' fi').to_s.split("\n").first.to_s.strip

      raise 'failed to locate nginx config' if conf_path == ''

      conf_dir = conf_path.rpartition('/')[0]

      # backup and remove the original configuration.
      shell.sudo_exec "if [ ! -f #{conf_path}.original ]; then mv -f #{conf_path} #{conf_path}.original; fi"

      # get the passenger_root path.
      pr_path = shell.sudo_exec_ignore("ls {#{PASSENGER_ROOT_SEARCH.join(',')}}/#{PASSENGER_ROOT_PATH} 2>/dev/null")
      pr_path = pr_path.to_s.split("\n").first.to_s.strip
      if pr_path == ''
        pr_path = shell.sudo_exec_ignore('gem specification passenger gem_dir').to_s.split("\n").first.to_s.strip
        if pr_path[0..2] == '---'
          pr_path = eval(pr_path[3..-1].strip)
        else
          pr_path = ''
        end
      end
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
              .gsub(INST_REG_COMMENT_PLACEHOLDER, host_id == :centos ? '' : '# ')
              .gsub(CONFIG_PATH_PLACEHOLDER, conf_dir)
              .gsub(IP6_COMMENT_PLACEHOLDER, enable_ip6? ? '' : '# ')
              .gsub(DEPLOY_RUBY_COMMENT_PLACEHOLDER, global_ruby? ? '# ' : '')
              .gsub(GLOBAL_RUBY_COMMENT_PLACEHOLDER, global_ruby? ? '' : '# ')
      )

      # move it where it belongs.
      shell.sudo_exec "mv -f #{home_path}/nginx.conf #{conf_path}"
      shell.sudo_exec "chown root:root #{conf_path} && chmod 644 #{conf_path}"

      # create the log folder.
      shell.sudo_exec 'if [ ! -d /var/log/nginx ]; then mkdir /var/log/nginx; fi'

      # create the location folders.
      shell.sudo_exec 'if [ ! -d /etc/nginx ]; then mkdir /etc/nginx; fi'
      %w(locations-available locations-enabled).each do |loc|
        loc = "/etc/nginx/#{loc}"
        shell.sudo_exec "if [ ! -d #{loc} ]; then mkdir #{loc}; fi"
        shell.sudo_exec "chown #{deploy_user}:root #{loc}"
        shell.sudo_exec "chmod 6755 #{loc}"
      end

      # create the default location.
      shell.write_file(
          "#{home_path}/default.loc",
          DEFAULT_LOC
              .gsub(PASSENGER_ROOT_PLACEHOLDER, pr_path)
              .gsub(DEPLOY_HOME_PLACEHOLDER, deploy_home)
      )
      shell.sudo_exec "mv -f #{home_path}/default.loc /etc/nginx/locations-available/default"
      shell.sudo_exec "chown #{deploy_user}:root /etc/nginx/locations-available/default && chmod 644 /etc/nginx/locations-available/default"
      shell.sudo_exec "rm -f /etc/nginx/locations-enabled/default"
      shell.sudo_exec "ln -s /etc/nginx/locations-available/default /etc/nginx/locations-enabled/default"

      # create the SSL files.
      shell.sudo_exec 'if [ ! -d /var/ssl ]; then mkdir /var/ssl; fi'
      shell.sudo_exec 'chown ruby-apps:root /var/ssl && chmod 700 /var/ssl'
      # strengthen SSL by using unique dhparams
      shell.sudo_exec 'openssl dhparam -out /var/ssl/dhparams.pem 2048'
      # generate a generic self-signed certificate to get started with.
      shell.sudo_exec 'openssl req -x509 -nodes -days 365 -newkey rsa:4096 -subj "/C=US/ST=Pennsylvania/L=Pittsburgh/O=WEB/CN=$(hostname -f)" -keyout /var/ssl/ssl.key -out /var/ssl/ssl.crt'
      shell.sudo_exec 'chown ruby-apps:root /var/ssl/* -R && chmod 600 /var/ssl/*'

      case host_id
        when :centos
          centos_configure_passenger shell
        when :ubuntu, :raspbian
          nil
        else
          raise 'not implemented'
      end

    end

    private

    def centos_configure_passenger(shell)
      # SELinux is a pain, but it is definitely best to make it work.
      {
          '/etc/nginx'          => 'httpd_config_t',
          '/var/ssl'            => 'httpd_config_t',
          "#{deploy_home}/apps" => 'httpd_sys_content_t',
      }.each do |path,type|
        shell.sudo_exec "semanage fcontext -a -t #{type} \"#{path}(/.*)?\""
        shell.sudo_exec "restorecon -R #{path}"
      end

      # and we need to configure the firewall too.
      shell.sudo_exec 'iptables -I INPUT -p tcp --dport 80 -j ACCEPT'
      shell.sudo_exec 'iptables -I INPUT -p tcp --dport 443 -j ACCEPT'
    end


    def enable_ip6?
      host_id != :raspbian
    end

  end
end