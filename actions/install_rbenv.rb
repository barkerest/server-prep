module BarkestServerPrep
  module InstallRbenv

    def install_rbenv(shell)
      shell.exec 'git clone https://github.com/rbenv/rbenv.git ~/.rbenv'
      shell.exec 'git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build'

      bashrc = shell.read_file(deploy_home + '/.bashrc') rescue ''
      lines = bashrc.split("\n")
      first_line = nil
      lines.each_with_index do |line,index|
        if line.strip[0] != '#'
          first_line = index
          break
        end
      end
      first_line ||= lines.count
      lines.insert first_line, <<-EORC

# Initialize rbenv and ruby.
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/plugins/ruby-build/bin:$PATH"
eval "$(rbenv init -)"

      EORC

      bashrc = lines.join("\n")
      shell.write_file(deploy_home + '/.bashrc', bashrc)
    end

  end
end