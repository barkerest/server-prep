module BarkestServerPrep
  module GetConfig

    attr_accessor :host, :admin_user, :admin_password, :deploy_user, :deploy_password,
                  :host_info, :host_id, :ruby_version, :rails_version

    private :admin_password

    def get_config
      print "This script will configure a Linux server for use with Phusion Passenger.\n"
      print "It is currently setup to configure CentOS, Ubuntu, Debian, or Raspbian.\n"

      print "Press <ENTER> to continue, or <CTRL>+<C> to exit.\n"
      STDIN.gets

      print "\nTo start, we need to configure the admin connection.\n"
      get_admin_config

      print "\nNow we'll configure the deployment connection.\n"
      get_deploy_config
    end

    def use_default_config(host, admin, pwd)
      get_admin_config host, admin, pwd
      get_deploy_config true
    end

    private

    def get_deploy_config(defaults = false)
      deploy_default = 'deploy'
      ruby_default = '2.4.1'
      rails_default = '4.2.7.1'

      print "The deployment user will be recreated on the target.\n"
      print "That means if the user already exists, all their data will be removed.\n"

      print "What is the username of your deployment user (default: #{deploy_default})? "
      if defaults
        self.deploy_user = deploy_default
        print "#{deploy_default}\n"
      else
        self.deploy_user = STDIN.gets.to_s.strip
        self.deploy_user = deploy_default if self.deploy_user == ''
      end

      raise 'Deployment user cannot be the same as the admin user.' if deploy_user == admin_user

      # generate a 24-character password (18 * (4/3) == 24)
      self.deploy_password = nil
      until deploy_password
        self.deploy_password = SecureRandom.urlsafe_base64(18)
        # ensure the password starts with a letter or number.
        self.deploy_password = nil unless (/^[a-zA-Z0-9]/).match(deploy_password)
      end
      

      print "What version of Ruby would you like to install (default: #{ruby_default})? "
      if defaults
        self.ruby_version = ruby_default
        print "#{ruby_default}\n"
      else
        self.ruby_version = STDIN.gets.strip
        self.ruby_version = ruby_default if self.ruby_version == ''
        a,b,c = self.ruby_version.split('.').map{|v| v.to_i}
        a ||= 2
        b ||= 0
        c ||= 0
        self.ruby_version = "#{a}.#{b}.#{c}"
      end

      print "What version of Rails would you like to install (default: #{rails_default})? "
      if defaults
        self.rails_version = rails_default
        print "#{rails_default}\n"
      else
        self.rails_version = defaults ? '' : STDIN.gets.strip
        self.rails_version = rails_default if self.rails_version == ''
        a,b,c,d = self.rails_version.split('.').map{|v| v.to_i}
        a ||= 4
        b ||= 0
        c ||= 0
        d ||= 0
        self.rails_version = "#{a}.#{b}.#{c}.#{d}"
      end
    end

    def get_admin_config(host_address = nil, admin = nil, password = nil)
      print 'What is the host we will be connecting to? '
      if host_address.to_s.strip != ''
        self.host = host_address.to_s.strip
        print "#{self.host}\n"
      else
        self.host = STDIN.gets.to_s.strip
      end

      raise 'Host is required.' if host == ''

      print 'What is the username of a user with sudoer priviledges? '
      if admin.to_s.strip != ''
        self.admin_user = admin.to_s.strip
        print "#{self.admin_user}\n"
      else
        self.admin_user = STDIN.gets.to_s.strip
      end

      raise 'Admin user is required.' if admin_user == ''
      raise 'Admin user cannot be the same as the deployment user.' if admin_user == deploy_user

      print 'What is the password for that user? '
      self.admin_password = password || STDIN.noecho(&:gets).to_s.strip
      print "\n"

      raise 'Admin password is required.' if admin_password == ''

      print 'Testing admin connection: '

      self.host_info = {}

      @waiting = true
      admin_shell(false) do |shell|
        begin
          # get the release info.
          results = shell.exec('cat /etc/*-release').split("\n").map{|v| v.strip}
          results.delete('')

          # process the release info variables.
          results.each do |line|
            if line.include?('=')
              var,_,val = line.partition('=')
              val = val[1...-1] if val[0] == '"' && val[-1] == '"'
              var = var.upcase
              host_info[var] = val
            end
          end

          # test for sudo capabilities.
          results = shell.sudo_exec('touch /root/test && echo sudo-test-passed')
          raise 'Failed to execute sudo command.' unless results.include?('sudo-test-passed')

        ensure
          @waiting = false
        end
      end

      while @waiting
        sleep 0
      end

      host_info['ID'] = (host_info['ID'] || 'unknown').downcase.to_sym
      self.host_id = host_info['ID']
      host_info['NAME'] ||= host_info['ID'].to_s
      host_info['VERSION'] ||= '??'
      host_info['PRETTY_NAME'] ||= "#{host_info['NAME']} #{host_info['VERSION']}"

      print "#{host_info['PRETTY_NAME']}\n"

      raise "Host OS (#{host_id})is not supported." unless [:centos, :ubuntu, :debian, :raspbian].include?(host_id)

    end

  end
end