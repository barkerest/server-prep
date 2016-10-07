# server-prep

A script designed to make it easy to setup a nginx/passenger server.
The script itself runs in Ruby, so you will need to have Ruby installed locally first.

The script uses the **barkest_ssh** gem (v 1.1.10+) to communicate with the target server.

The script has been tested against CentOS 7 and Ubuntu 16.04.  The script will fail for any other
distro at this point in time.  If you want to test it against another distro, it should be fairly
easy to figure out how to modify the code.  First you will need to modify `get_config.rb` so that
your distro is accepted.  Then you will need to check the various files under `actions` to determine
if you need to use a new function or if the centos or ubuntu version will work for your distro.

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

The defaults for Ruby and Rails are `2.2.5` and `4.2.5.2` repectively.  If you want to use different
versions, you can change the defaults in `actions/get_config.rb` or omit the `-auto` flag so that you
can answer all of the questions.
