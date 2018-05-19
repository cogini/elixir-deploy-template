# deploy-template

This is a working example app which shows how to deploy a Phoenix app based on
this [best practices for deploying elixir
apps](https://www.cogini.com/blog/best-practices-for-deploying-elixir-apps/)
blog post.

It is based on a default Phoenix project without Ecto. The [changes](#changes)
are all additions, so you can easily add them to your own project.

It's tested deploying to [Digital Ocean](https://m.do.co/c/150575a88316) with
CentOS 7, Ubuntu 16.04, Ubuntu 18.04 and Debian 9.4.

This document goes through the template step to show you how it works, so
you can make modifications to match your needs.

It is based on [Ansible](https://www.ansible.com/resources/get-started), which
is an easy-to-use standard platform for managing servers.
Unlike edeliver, it is based on a reliable and well documented set of primitives
to handle logging into servers, uploading files and executing commands.
It can also be used to [support more complex deployment
scenarios](https://www.cogini.com/blog/setting-ansible-variables-based-on-the-environment/).

# Overall approach

1. Set up the web server, running Linux.
2. Set up a build server matching the architecture of your web server.
   This can be the same as the web server.
3. Check out code on the build server from git and build a release.
4. Deploy the release to the web server.

The actual work of checking out and deploying is handled by simple shell
scripts which you run on the build server from your dev machine, e.g.:

```shell
# Check out latest code and build release on server
ssh -A deploy@build-server build/elixir-deploy-template/scripts/build-release.sh

# Deploy release
ssh -A deploy@build-server build/elixir-deploy-template/scripts/deploy-local.sh
```

# Up and running

Check out the code from git to your local dev machine:

```shell
git clone https://github.com/cogini/elixir-deploy-template
```

## Set up ASDF

Install ASDF as described in [the ASDF docs](https://github.com/asdf-vm/asdf).

Install ASDF plugins for our tools:

```shell
asdf plugin-add erlang
asdf plugin-add elixir
asdf plugin-add nodejs
```

Install the versions of Erlang, Elixir and Node.js specified in the
`.tool-versions` file:

```shell
asdf install
```
Run this multiple times until everything is installed (should be twice).

Install libraries into the ASDF Elixir dirs:

```shell
mix local.hex --force
mix local.rebar --force
mix archive.install https://github.com/phoenixframework/archives/raw/master/phx_new.ez --force
```

## Build the app

Build the app the same as you normally would:

```shell
mix deps.get
mix deps.compile
```

At this point you should be able to run the app locally with:

```shell
mix compile
iex -S mix phx.server
open http://localhost:4000/
```

## Deploy the app

Install Ansible on your dev machine:

May be as simple as:

```shell
pip install ansible
```

See [the Ansible docs](http://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
for other options.

### Set up a target machine

An easy option is [Digital Ocean](https://m.do.co/c/150575a88316).
Their smallest $5/month Droplet will run Phoenix fine.

Add the host to the `~/.ssh/config` file on your dev machine:

    Host elixir-deploy-template
        HostName 123.45.67.89

Add the host to the groups in the Ansible inventory `ansible/inventory/hosts` file:

    [web-servers]
    elixir-deploy-template

    [build-servers]
    elixir-deploy-template

The host name is not important, you can use an existing server. Just use the
name from your `.ssh/config` file in the `inventory/hosts` config and in the
`ansible-playbook` commands below.

(The template has multiple hosts in the groups for testing different OS
versions, comment them out.)

### Configure the target server using Ansible

Run these commands from the `ansible` dir.

Newer versions of Ubuntu (16.04+) and Debian ship with Python 3, but the
default for Ansible is Python 2. It's possible to use the Python 3 that comes
with the OS, but when you are getting started with Ansible, this is the most
straightforward way. If necessary, run this playbook to install Python 2:

```shell
ansible-playbook -u root -v -l elixir-deploy-template playbooks/setup-python.yml -D
```

In this command, `elixir-deploy-template` is the hostname.

Edit the `playbooks/manage-users.yml` script to specify user accounts:

```yaml
# OS user account that the app runs under
users_app_user: foo
# OS group for the app
users_app_group: foo
# OS user account that deploys the app and owns the code files
users_deploy_user: deploy
# OS group for deploy
users_deploy_group: deploy
# Defines the list of users, but doesn't actually create them
users_users:
  - user: jake
    name: "Jake Morrison"
    github: reachfh
# Creates user accounts with sudo permissions
users_admin_users:
  - jake
# Defines users (ssh keys) who can ssh into the app account
users_app_users:
  - jake
# Defines users (ssh keys) who can ssh into the deploy account
users_deploy_users:
  - jake
# Defines secondary groups for the deploy user
users_deploy_groups:
  - foo
```

Change the `jake` user (me!) to match your account.

See [the documentation for the role](https://galaxy.ansible.com/cogini/users/)
for more details about options, e.g. using ssh keys from files instead of
relying on GitHub.

Execute this playbook to set up the user accounts:

```shell
ansible-playbook -u root -v -l elixir-deploy-template playbooks/manage-users.yml -D
```
See comments in `playbooks/manage-users.yml` for other ways to do the initial bootstrap.

Do initial server setup:

```shell
ansible-playbook -u $USER -v -l web-servers playbooks/setup-web.yml -D
```

In this command, `web-servers` is the group of servers. Ansible allows you to
work on groups of servers simultaneously. Configuration tasks are written to be
idempotent, so we can run the playbook against all our servers and it will make
whatever changes are needed to get them up to date.

Set up the app (create app dirs, etc.).

```shell
ansible-playbook -u $USER -v -l web-servers playbooks/deploy-template.yml --skip-tags deploy -D
```
You can customize locations with vars in `playbooks/deploy-template.yml`.

At this point, the web server is set up, but we still need to build and deploy
the app code to it.

## Set up the build server

We need to build the release on the same architecture as it will run on.
In this example, the build server is the same as the web server.

Set up the server, mainly installing ASDF:

```shell
ansible-playbook -u $USER -v -l build-servers playbooks/setup-build.yml -D
```

## Build the app

Log into the `deploy` user on the build machine:

```shell
ssh -A deploy@elixir-deploy-template
```

The `-A` flag on the ssh command gives the session on the server access to your
local ssh keys. If your local user can access a GitHub repo, then the server
can do it, without having to put keys on the server. Similarly, if your ssh key
is on the prod server, then you can push code from the build server using
Ansible without the web server needing to trust the build server.

If you are using a CI server to build and deploy code, then it runs in the
background.  Create a deploy key in GitHub so it can access to your source and
add the ssh key on the build server to the `deploy` user account on the prod
servers so the CI server can push releases.

Check out the source:

```shell
mkdir build
cd build
git clone https://github.com/cogini/elixir-deploy-template
cd elixir-deploy-template
```

Install Erlang, Elixir and Node.js as specified in `.tool-versions`:

```shell
asdf install
```
Run this multiple times until everything is installed (should be twice).

The initial compile of Erlang from source can take a while on a small Droplet,
so you may want to run it under `tmux` or `screen`.

Install libraries into the ASDF dir for the specified Elixir version:

```shell
mix local.hex --force
mix local.rebar --force
```

Generate a cookie and put it in `config/cookie.txt`:

```elixir
iex> :crypto.strong_rand_bytes(32) |> Base.encode16
```

Update `secret_key_base` in `config/prod.secret.exs`:

```shell
cp config/prod.secret.exs.sample config/prod.secret.exs
openssl rand -base64 48
```

Replace `xxx` with the random string generated by openssl:

```elixir
config :deploy_template, DeployTemplateWeb.Endpoint,
  secret_key_base: "xxx"
```

Build the production release:

```shell
mix deps.get --only prod
MIX_ENV=prod mix do compile, phx.digest, release
```

Now you should be able to run the app from the release:

```shell
PORT=4001 _build/prod/rel/deploy_template/bin/deploy_template foreground
```

```shell
curl -v http://localhost:4001/
```

## Deploy the release

If you are running on the same machine, then you can use the custom
mix tasks in `lib/mix/tasks/deploy.ex` to deploy locally.

In `mix.exs`, set `deploy_dir` to match the directory structure in the
created by the Ansible playbook, e.g.:

```elixir
deploy_dir: "/opt/myorg/deploy-template/",
```

Deploy the release:

```shell
MIX_ENV=prod mix deploy.local
sudo /bin/systemctl restart deploy-template
```

This assumes that the build is being done under the `deploy` user, who owns the
files under `/opt/myorg/deploy-template` and has a special `/etc/sudoers.d`
config which allows it to run the `/bin/systemctl restart deploy-template`
command.

You should be able to connect to the app supervised by systemd:
```shell
curl -v http://localhost:4001/
```

Have a look at the logs:
```shell
# systemctl status deploy-template
# journalctl -r -u deploy-template
```

You should also be able to access the machine over the network on port 80
through the magic of iptables port forwarding.

## Deploy to a remote machine using Ansible

From your dev machine, install Ansible on the build machine:

```shell
ansible-playbook -u $USER -v -l build-servers playbooks/setup-ansible.yml -D
```

Log into the build machine:

```shell
ssh -A deploy@elixir-deploy-template
cd ~/build/elixir-deploy-template/ansible
```

Add the `web-servers` hosts to the `~/.ssh/config` on the deploy machine:

    Host elixir-deploy-template
        HostName 123.45.67.89

For larger projects, we normally maintain the list of servers in a `ssh.config`
file in the repo. See `ansible/ansible.cfg` for options.

From the build machine, deploy the app:

```shell
ansible-playbook -u deploy -v -l web-servers playbooks/deploy-template.yml --tags deploy --extra-vars ansible_become=false -D
```

## Database migrations

For a real app, you will generally need a database.

In the simple scenario, a single server is used to build and deploy the app,
and also runs the db. In that case, we need to log into the build environment
and create the db after we have set up the build environment.

Add the db passwords to `config/prod.secret.exs` and create the db:

```shell
MIX_ENV=prod mix ecto.create
```

Then, after building the release, but before deploying the code, we need to
update the db to match the code:

```shell
MIX_ENV=prod mix ecto.migrate
```

Surprisingly, the same process also works when we are deploying in a more
complex cloud environment. You can create a build instance in the VPC private
subnet which has permissions to talk to a shared RDS database. You can then run
the Ecto commands to create and migrate the db, build the release and deploy it
via AWS CodeDeploy.

# Changes

Following are the steps used to set up this repo. You can do the same to add
it to your own project.

It all began with a new Phoenix project:

```shell
mix phx.new --no-ecto deploy_template
```

## Set up distillery

Generate initial `rel` files:

```shell
mix release.init
```

Modify `rel/config.exs` to set the cookie from a file and update `vm.args.eex`
to tune the VM settings.

## Set up ASDF

Add the `.tool-versions` file to specify versions of Elixir and Erlang.

## Configure for running in a release

Edit `config/prod.exs`

Uncomment this so Phoenix will run in a release:

```elixir
config :phoenix, :serve_endpoints, true
```

## Add Ansible

Add the tasks to set up the servers and deploy code, in the `ansible`
directory. Configure the vars in the playbooks to match your app name.

To make it easier to run, this repository contains local copies
of roles from Ansible Galaxy in `roles.galaxy`. To update them, run:

```shell
ansible-galaxy install --roles-path roles.galaxy -r install_roles.yml
```

## Add mix tasks for local deploy

Add `lib/mix/tasks/deploy.ex`

## Add shutdown_flag library

This supports restarting the app after deploying a release [without needing
sudo permissions](https://www.cogini.com/blog/deploying-elixir-apps-without-sudo/).

Add [shutdown_flag](https://github.com/cogini/shutdown_flag) to `mix.exs`:

    {:shutdown_flag, github: "cogini/shutdown_flag"},

Add to `config/prod.exs`:

```elixir
config :shutdown_flag,
  flag_file: "/var/tmp/deploy/deploy-template/shutdown.flag",
  check_delay: 10_000
```
