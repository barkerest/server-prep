# server-prep

A script designed to make it easy to setup a nginx/passenger server.
The script itself runs in Ruby, so you will need to have Ruby installed locally first.

The script uses the **shells** gem (v 0.1.7+) to communicate with the target server.

The script has been tested against CentOS 7 and Ubuntu 16.04.  The script will fail for any other
distro at this point in time.  If you want to test it against another distro, it should be fairly
easy to figure out how to modify the code.  First you will need to modify `get_config.rb` so that
your distro is accepted.  Then you will need to check the various files under `actions` to determine
if you need to use a new function or if the centos or ubuntu version will work for your distro.

There are some minor config differences between CentOS and Ubuntu.  First, CentOS makes use of SElinux, 
whereas Ubuntu makes use of AppArmor.  SElinux is enabled for nginx by default, AppArmor is not.
Second, Passenger _expects_ the passenger_instance_registry_dir to be different values on the two
platforms.  On CentOS, we need to include this setting in the nginx.conf file, whereas on Ubuntu
it works better to omit it.  This differences are all handled in the `configure_passenger` method.

As a related note to the differences, the SElinux attributes seem to propagate properly into the 
deployment apps path.  So as new apps are added, they seem to receive the correct attribute and
would therefore be usable by nginx.


## usage

You can let the script use defaults for the deployment user, ruby version, and rails version.
To do this, all you need to do is provide the '-auto' flag.  If you provide the '-auto' flag,
you can also provide the host, admin user, and admin password as well.  If you do not provide
one of these values, you will be prompted for it.

With this example, you will be prompted for all information:

`$ ruby server_prep.rb`

With this example, you will not be prompted at all:

`$ ruby server_prep.rb -auto 10.10.10.10 admin secret`

And then these will prompt for the password, user name, and host as needed:

`$ ruby server_prep.rb -auto 10.10.10.10 admin`

`$ ruby server_prep.rb -auto 10.10.10.10`

`$ ruby server_prep.rb -auto`

The defaults for Ruby and Rails are `2.4.3` and `4.2.10` repectively.  If you want to use different
versions, you can change the defaults in `actions/get_config.rb` or omit the `-auto` flag so that you
can answer all of the questions.


## post-usage

After the script has been run, the server is now configured with a self-signed SSL cert to enable HTTPS
right out of the gate.  The nginx.conf file is setup to serve a single virtual server listening on ports
80 and 443.  And one location "/" is configured and pointing to the `fly_trap` app.  Additional apps can
be added to the deployment user's `apps`directory.  Once they are installed and configured, add a location
file to the /etc/nginx/locations-available directory and then link to it in the 
/etc/nginx/locations-enabled directory.  The setup script is also nice enough to create a `nginx-reload`
executable that can be run by the deployment user.
