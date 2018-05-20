# deploy-template

This is a working example app which shows how to deploy a Phoenix app based on
this [best practices for deploying elixir
apps](https://www.cogini.com/blog/best-practices-for-deploying-elixir-apps/)
blog post.

It is based on a default Phoenix project without Ecto. The [changes](#changes)
are all additions, so you can easily add them to your own project.

It's tested deploying to [Digital Ocean](https://m.do.co/c/150575a88316) with
CentOS 7, Ubuntu 16.04, Ubuntu 18.04 and Debian 9.4.

It is based on [Ansible](https://www.ansible.com/resources/get-started), which
is an easy-to-use standard platform for managing servers.
Unlike edeliver, it is based on a reliable and well documented set of primitives
to handle logging into servers, uploading files and executing commands.
It can also be used to [support more complex deployment
scenarios](https://www.cogini.com/blog/setting-ansible-variables-based-on-the-environment/).

# Overall approach

1. Set up the web server, running Linux.
2. Set up a build server matching the architecture of the web server.
   This can be the same as the web server.
3. Check out code on the build server from git and build a release.
4. Deploy the release to the web server.

The actual work of checking out and deploying is handled by simple shell
scripts which you run on the build server or from from your dev machine via
ssh, e.g.:

```shell
# Check out latest code and build release on server
ssh -A deploy@build-server build/deploy-template/scripts/build-release.sh

# Deploy release
ssh -A deploy@build-server build/deploy-template/scripts/deploy-local.sh
```

# Set up dev machine

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
mix compile
```

At this point you should be able to run the app locally with:

```shell
iex -S mix phx.server
open http://localhost:4000/
```

## Install Ansible

Install Ansible on your dev machine:

May be as simple as:

```shell
pip install ansible
```

See [the Ansible docs](http://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
for other options.

# Set up server

An easy option is [Digital Ocean](https://m.do.co/c/150575a88316).
Their smallest $5/month Droplet will run Phoenix fine.

## Configure Ansible

### Define servers

Add the hosts to the `~/.ssh/config` file on your dev machine:

    Host web-server
        HostName 123.45.67.89

Add the hosts to the groups in the Ansible inventory `ansible/inventory/hosts`
file in the project:

    [web-servers]
    web-server

    [build-servers]
    web-server

The host name is not important, you can use an existing server. Just use the
name from your `.ssh/config` file in the `inventory/hosts` config and in the
`ansible-playbook` commands below.

If you are using a recent Ubuntu or Debian version that defaults to Python 3,
add the host to the `[py3-hosts]` group.

(The template has multiple hosts in the groups for testing different OS
versions, comment them out.)

### Set variables

Configuration vars defined in `inventory/group_vars/all` apply to all hosts in
your project. They are overridden by variables in more specfic groups, e.g.
`inventory/group_vars/web-servers` or for individual hosts, e.g.
`inventory/group_vars/web-server`.

The `inventory/group_vars/all/users.yml` defines a global list of users and
system admins. It has a live user (me!), change it to match your details:

```yaml
users_users:
  - user: jake
    name: "Jake Morrison"
    github: reachfh

users_global_admin_users:
 - jake
```

The `inventory/group_vars/web-servers/elixir-release.yml` file specifies the
app settings:

```yaml
# A unique prefix for our directories
# This could be your organization or the overall project
elixir_release_org: myorg

# External name of the app, used to name directories and the systemd process
elixir_release_name: deploy-template

# Internal "Elixir" name of the app, used to by Distillery to name directories
elixir_release_name_code: deploy_template

# Name of your organization or overall project, used to make a unique dir prefix
elixir_release_org: myorg

# OS user that the app runs under
elixir_release_app_user: foo

# Port that Phoenix listens on
elixir_release_http_listen_port: 4001

# Port that app listens on
iptables_http_app_port: "{{ elixir_release_http_listen_port }}"
```

The `inventory/group_vars/build-servers/vars.yml` file specifies the build settings:

```yaml
# App git repo
app_repo: https://github.com/cogini/elixir-deploy-template
```

## Set up web server

Run these and other Ansible commands from the `ansible` dir.

Do initial server setup:

```shell
ansible-playbook -u root -v -l web-servers playbooks/setup-web.yml -D
```

In this command, `web-servers` is the group of servers. Ansible allows you to
work on groups of servers simultaneously. Configuration tasks are written to be
idempotent, so we can run the playbook against all our servers and it will make
whatever changes are needed to get them up to date.

Set up the app (create app dirs, etc.).

```shell
ansible-playbook -u $USER -v -l web-servers playbooks/deploy-app.yml --skip-tags deploy -D
```

At this point, the web server is set up, but we need to build and deploy
the app code to it.

## Set up build server

This can be the same as the web server or a separate server.

Set up the server, e.g. install ASDF:

```shell
ansible-playbook -u root -v -l build-servers playbooks/setup-build.yml -D
```

## Build the app

Log into the `deploy` user on the build machine:

```shell
ssh -A deploy@build-server
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
scripts/build-release.sh
```

That script runs:

```shell
# Pull latest code from git
git pull

# Update versions of Erlang/Elixir/Node.js if necessary
asdf install
asdf install

# Update Elixir libs
mix local.hex --force
mix local.rebar --force

# Build app and release
mix deps.get --only prod
MIX_ENV=prod mix do compile, phx.digest, release
```

## Deploy the release locally

If you are running on the same machine, then you can use the custom
mix tasks in `lib/mix/tasks/deploy.ex` to deploy locally.

In `mix.exs`, set `deploy_dir` to match Ansible, i.e.
`deploy_dir: /opt/{{ org }}/{{ app_name }}`:

```elixir
deploy_dir: "/opt/myorg/deploy-template/",
```

Deploy the release:

```shell
scripts/deploy-local.sh
```

That script runs:

```shell
MIX_ENV=prod mix deploy.local
sudo /bin/systemctl restart deploy-template
```

This assumes that the build is being done under the `deploy` user, who owns
the files under `/opt/myorg/deploy-template` and has a special `/etc/sudoers.d`
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
through the magic of [iptables port forwarding](https://www.cogini.com/blog/port-forwarding-with-iptables/).

## Deploy to a remote machine using Ansible

### Install Ansible on the build machine

From your dev machine:

```shell
ansible-playbook -u $USER -v -l build-servers playbooks/setup-ansible.yml -D
```

On the build server:

```shell
ssh -A deploy@build-server
cd ~/build/deploy-template/ansible
```

Add the servers in the `inventory/hosts` `web-servers` group to `~/.ssh/config`:

    Host web-server
        HostName 123.45.67.89

For larger projects, we normally maintain the list of servers in a `ssh.config`
file in the repo. See `ansible/ansible.cfg`.

### Deploy the app

On the build server:

```shell
scripts/deploy-remote.sh
```

That script runs:

```shell
ansible-playbook -u deploy -v -l web-servers playbooks/deploy-app.yml --tags deploy --extra-vars ansible_become=false -D
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
complex AWS cloud environment. Create a build instance in the VPC private
subnet which has permissions to talk to the RDS database. Run the Ecto commands
to create and migrate the db, build the release and deploy it via AWS
CodeDeploy.

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
