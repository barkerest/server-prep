module BarkestServerPrep

  module CreateNginxUtils

    UTIL_NGINX_RELOAD = <<-EOU
#include <unistd.h>

int main(int argc, char **argv)
{
  const char *args[] = { "??NG", "-s", "reload", NULL };
  setuid(0);
  execv(args[0], (char **)args);
  return 0;
}
    EOU

    UTIL_NGINX_TEST = <<-EOU
#include <unistd.h>

int main(int argc, char **argv)
{
  const char *args[] = { "??NG", "-t", "-q", NULL };
  setuid(0);
  execv(args[0], (char **)args);
  return 0;
}
    EOU


    private_constant :UTIL_NGINX_RELOAD

    def create_nginx_utils(shell)

      home_path = shell.exec("eval echo \"~#{admin_user}\"").split("\n").first.to_s.strip
      nginx_path = shell.sudo_exec("which nginx").split("\n").first.to_s.strip

      { 'nginx-reload' => UTIL_NGINX_RELOAD, 'nginx-test' => UTIL_NGINX_TEST }.each do |util,src|
        shell.write_file "#{home_path}/temp-util.c", src.gsub("??NG", nginx_path)
        shell.exec "gcc -o #{home_path}/#{util} #{home_path}/temp-util.c"
        shell.sudo_exec "chown root:root #{home_path}/#{util} && chmod 4755 #{home_path}/#{util}"
        shell.sudo_exec "mv -f #{home_path}/#{util} /usr/local/bin/#{util}"
        shell.exec "rm #{home_path}/temp-util.c"
      end

    end

  end

end