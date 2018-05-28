This is a working example app which shows how to deploy a Phoenix app using
the principles from my blog post "[Best practices for deploying Elixir
apps](https://www.cogini.com/blog/best-practices-for-deploying-elixir-apps/)".
The blog post "[Deploying your Phoenix app to Digital Ocean for
beginners](https://www.cogini.com/blog/deploying-your-phoenix-app-to-digital-ocean-for-beginners/)"
has similar content, but is simplified for beginners. If you have any
questions, open an issue here or ping me on the `#elixir-lang` IRC channel on
Freenode, I am `reachfh`. Patches welcome.

It starts with a default Phoenix project with PostgreSQL database. First get
the template running, then add the necessary [changes](#changes) to your own
project.

It's regularly tested deploying to [Digital Ocean](https://m.do.co/c/150575a88316)
with CentOS 7, Ubuntu 16.04, Ubuntu 18.04 and Debian 9.4. Digital Ocean's
smallest $5/month Droplet [runs Phoenix
fine](https://www.cogini.com/blog/benchmarking-phoenix-on-digital-ocean/). The
approach here works great for dedicated servers and cloud instances as well.

It uses [Ansible](https://www.ansible.com/resources/get-started), which is an
easy-to-use standard tool for managing servers. Unlike edeliver, it has
reliable and well documented primitives to handle logging into servers,
uploading files and executing commands. It can also be used to [support more
complex deployment scenarios](https://www.cogini.com/blog/setting-ansible-variables-based-on-the-environment/).

### Overall approach

1. Set up the web servers, running Linux.
2. Set up a build server matching the architecture of the web server.
   This can be the same as the web server.
3. Check out code on the build server from git and build a release.
4. Deploy the release to the web server, locally or remotely via Ansible.

The actual work of checking out and deploying is handled by simple shell
scripts which you run on the build server or from your dev machine via
ssh, e.g.:

```shell
# Check out latest code and build release on server
ssh -A deploy@build-server build/deploy-template/scripts/build-release.sh

# Deploy release
ssh -A deploy@build-server build/deploy-template/scripts/deploy-local.sh
```

# Set up dev machine

Check out the project from git on your local dev machine, same as you normally
would:

```shell
git clone https://github.com/cogini/elixir-deploy-template
```

## Set up ASDF

ASDF lets you manage multiple versions of Erlang, Elixir and Node.js. It is
safe to install on your machine, it won't conflict with anything else, that's
it's whole reason for existing.

Install ASDF as described in [the ASDF docs](https://github.com/asdf-vm/asdf).

Install ASDF plugins for our tools:

```shell
asdf plugin-add erlang
asdf plugin-add elixir
asdf plugin-add nodejs
```

Install build dependencies.

On macOS, first install [Homebrew](https://brew.sh/), then run:

```shell
# Erlang
brew install autoconf automake libtool openssl wxmac
# Install Java (optional) to avoid popup prompts
# If you already have Java installed, you don't need to do this
brew cask install java

# Node.js
brew install gpg
bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring
```

For Linux, see packages in `ansible/vars/build-Debian.yml` and `ansible/vars/build-RedHat.yml`.

Use ASDF to install the versions of Erlang, Elixir and Node.js specified in the
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

Install libraries into the ASDF node dirs:
```shell
npm install -g brunch
```

Confirm that it works by building the app the normal way:

```shell
mix deps.get
mix deps.compile
mix compile
```

You should be able to run the app locally with:

```shell
mix ecto.create
(cd assets && npm install && node node_modules/brunch/bin/brunch build)
iex -S mix phx.server
open http://localhost:4000/
```

## Install Ansible

Install Ansible on your dev machine. On macOS, use pip, the Python package
manager:

```shell
sudo pip install ansible
```

If pip isn’t already installed, run:

```shell
sudo easy_install pip
```

See [the Ansible docs](http://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
for other options.

## Set up ssh key

We use ssh keys to control access to servers instead of passwords. This is more
secure and easier to automate.

Generate an ssh key if you don't have one already:

```shell
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

Set a pass phrase to protect access to your key (optional but recommended).
macOS and modern Linux desktops will remember your pass phrase in the keyring
when you log in so you don't have to enter it every time.

Add the `~/.ssh/id_rsa.pub` public key file to your GitHub account.

# Set up a server

Go to [Digital Ocean](https://m.do.co/c/150575a88316) (affiliate link) and
create a Droplet (virtual server).

* **Choose an image**: If you are [not sure which distro to
  use](/blog/choosing-a-linux-distribution/), choose CentOS 7.
* **Choose a size**: The smallest, $5/month Droplet is fine
* **Choose a datacenter region**: Select a data center near you
* **Add your SSH keys**: Select the "New SSH Key" button, and paste the
  contents of your `~/.ssh/id_rsa.pub` file.
* **Choose a hostname**: The default name is fine, but a bit awkward to type. Use
  "web-server" or whatever you like.

The defaults for everything else are fine. Click the "Create" button.

Add the host to the `~/.ssh/config` file on your dev machine:

    Host web-server
        HostName 123.45.67.89

The file permissions on `~/.ssh/config` need to be secure or ssh will be unhappy:

```shell
chmod 600 ~/.ssh/config
```

## Configure Ansible

Add the hosts to the groups in the Ansible inventory `ansible/inventory/hosts`
file in the project:

    [web-servers]
    web-server

    [build-servers]
    web-server

The host name here should match the `Host` name in your `.ssh/config` file.

If you are using Ubuntu or Debian, add the host to the `[py3-hosts]` group, and
it will use Python 3 on the server.

(The repo has multiple hosts in the groups for testing different OS versions,
comment them out.)

Test it by connecting to the server:

```shell
ssh root@web-server
```

If it doesn't work, run ssh with `-v` flags to see what the problem is.
You can add more verbosity, e.g. `-vvvv` if you need more detail.

```shell
ssh -vv root@web-server
```

File permissions are the most common cause of problems with ssh. Another common
problem is forgetting to add your ssh key when creating the Droplet. Destroy
the Droplet and create it again.

### Set Ansible variables

The configuration variables defined in `inventory/group_vars/all` apply to all hosts in
your project. They are overridden by vars in more specific groups like
`inventory/group_vars/web-servers` or for individual hosts, e.g.
`inventory/host_vars/web-server`.

Ansible uses ssh to connect to the server. These playbooks use ssh keys to
control logins to server accounts, not passwords. The `users` Ansible role
manages accounts.

The `inventory/group_vars/all/users.yml` file defines a global list of users and
system admins. It has a live user (me!), **change it to match your details**:

```yaml
users_users:
  - user: jake
    name: "Jake Morrison"
    github: reachfh

users_global_admin_users:
 - jake
```

The `inventory/group_vars/all/elixir-release.yml` file specifies the
app settings:

```yaml
# External name of the app, used to name directories and the systemd process
elixir_release_name: deploy-template

# Internal "Elixir" name of the app, used to by Distillery to name things
elixir_release_name_code: deploy_template

# Name of your organization or overall project, used to make a unique dir prefix
elixir_release_org: myorg

# OS user the app runs under
elixir_release_app_user: foo

# OS user for building and deploying the code
elixir_release_deploy_user: deploy

# Port that Phoenix listens on
elixir_release_http_listen_port: 4001
```

The `inventory/group_vars/build-servers/vars.yml` file specifies the build settings.

It specifies the project's git repo, which will be checked out on the build server:

```yaml
# App git repo
app_repo: https://github.com/cogini/elixir-deploy-template
```

## Set up web server

Run the following Ansible commands from the `ansible` dir in the project.

Do initial server setup:

```shell
ansible-playbook -u root -v -l web-servers playbooks/setup-web.yml -D
```

In this command, `web-servers` is the group of servers. Ansible allows you to
work on groups of servers simultaneously. Configuration tasks are written to be
idempotent, so we can run the playbook against all our servers and it will make
whatever changes are needed to get them up to date.

The `-v` flag controls verbosity, you can add more v's to get more debug info.
The `-D` flag shows diffs of the changes Ansible makes on the server. If you
add `--check` to the Ansible command, it will show you the changes it is
planning to do, but doesn't actually run them (these scripts are safe to run,
but it may error out during the play if required packages are not installed).

Set up the app (create dirs, etc.):

```shell
ansible-playbook -u $USER -v -l web-servers playbooks/deploy-app.yml --skip-tags deploy -D
```

Configure runtime secrets, setting the `$HOME/.erlang.cookie` file and
generate a Conform config file at `/etc/deploy-template/deploy_template.conf`:

```shell
ansible-playbook -u $USER -v -l web-servers playbooks/config-web.yml -D
```

For ease of getting started, this generates secrets on your local machine and
stores them in `/tmp`.  See below for discussion about managing secrets.

At this point, the web server is set up, but we need to build and deploy
the app code to it.

## Set up build server

This can be the same as the web server or a separate server.

Set up the server:

```shell
ansible-playbook -u root -v -l build-servers playbooks/setup-build.yml -D
```

This sets up the build environment, e.g. install ASDF. It also installs
PostgreSQL, assuming we are running the web app on the same server.

Configure `config/prod.secret.exs` on the build server:

```shell
ansible-playbook -u $USER -v -l build-servers playbooks/config-build.yml -D
```

Again, see below for discussion about managing secrets.

## Build the app

Log into the `deploy` user on the build machine:

```shell
ssh -A deploy@build-server
cd ~/build/deploy-template
```

The `-A` flag on the ssh command gives the session on the server access to your
local ssh keys. If your local user can access a GitHub repo, then the server
can do it, without having to put keys on the server. Similarly, if your ssh key
is on the prod server, then you can push code from the build server using
Ansible without the web server needing to trust the build server.

If you are using a CI server to build and deploy code, then it runs in the
background.  Create a deploy key in GitHub so it can access to your source and
add the ssh key on the build server to the `deploy` user account on the web
servers so the CI server can push releases.

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

`asdf install` builds Erlang from source, so the first time it runs it can take
a long time. If it fails, delete `/home/deploy/.asdf/installs/erlang/20.3` and
try again. You may want to run it under `tmux`.

## Deploy the release locally

If you are building on the web web server, then you can use the custom mix
tasks in `lib/mix/tasks/deploy.ex` to deploy locally.

In `mix.exs`, set `deploy_dir` to match Ansible, i.e.
`deploy_dir: /opt/{{ org }}/{{ elixir_release_name }}`:

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

The build is being done under the `deploy` user, who owns the files under
`/opt/myorg/deploy-template` and has a special `/etc/sudoers.d` config which
allows it to run the `/bin/systemctl restart deploy-template` command.

### Verify it works

Make a request to the app supervised by systemd:

```shell
curl -v http://localhost:4001/
```

Have a look at the logs:
```shell
# systemctl status deploy-template
# journalctl -r -u deploy-template
```

Make a request to the machine over the network on port 80 through the magic of
[iptables port forwarding](https://www.cogini.com/blog/port-forwarding-with-iptables/).

You can get a console on the running app by logging in as the `foo` user the
app runs under and executing:

```shell
/opt/myorg/deploy-template/scripts/remote_console.sh
```

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

Add the servers in `ansible/inventory/hosts` to `~/.ssh/config`:

    Host web-server
        HostName 123.45.67.89

For projects with lots of servers, we normally maintain the list of servers in
a `ssh.config` file in the repo. See `ansible/ansible.cfg` for config.

### Deploy the app

On the build server:

```shell
scripts/deploy-remote.sh
```

That script runs:

```shell
ansible-playbook -u deploy -v -l web-servers playbooks/deploy-app.yml --tags deploy --extra-vars ansible_become=false -D
```

### Managing secrets with Ansible

Ansible has a [vault](http://docs.ansible.com/ansible/2.5/user_guide/vault.html) function
which you can use to store keys. It automates the process of encrypting
variable data so you can check it into source control, so only people with the
password can read it.

There are trade-offs in managing secrets.

For a small team of devs who are also the admins, then you trust your
developers and your own dev machine with the secrets. It's better not to have
secrets in the build environment, though. You can push the prod secrets
directly from your dev machine to the web servers. If you are using a 3rd-party
CI server, then that goes double. You don't want to give the CI service access
to your production keys.

For secure applications like health care, developers should not have access to
the prod environment. You can restrict vault password access to your ops team,
or use different keys for different environments.

You can also set up a build/deploy server in the cloud which has access to the
keys and configure the production instances from it. When we run in an AWS auto
scaling group, we build an AMI with [Packer](https://www.packer.io/) and
Ansible, putting the keys on it the same way. Even better, however, is to not
store keys on the server at all. Pull them when the app starts up, reading from
an S3 bucket or Amazon's KMS, with access controlled by IAM instance roles.

The one thing that really needs to be there at startup is the Erlang cookie,
everything else we can pull at runtime. If we are not using the Erlang
distribution protocol, then we don't need to share it, it just needs to be
secure.

The following shows describes how you can use the vault.

Generate a vault password and put it in the file `ansible/vault.key`:

```shell
openssl rand -hex 16
```

You can specify the password when you are running a playbook with the
`--vault-password-file vault.key` option, or you can make the vault password always
available by setting it in `ansible/ansible.cfg`:

    vault_password_file = vault.key

The `ansible/inventory/group_vars/web-servers/secrets.yml` file specifies deploy secrets.

Generate a cookie for deployment and copy it into the `secrets.yml` file:

```shell
openssl rand -hex 32 | ansible-vault encrypt_string --vault-id vault.key --stdin-name 'erlang_cookie'
```
That generates encrypted data like:

```yaml
erlang_cookie: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          64346139623638623838396261373265666363643264333664633965306465313864653033643530
          3830366538366139353931323662373734353064303034660a326232343036646339623638346236
          39623832656466356338373264623331363736636262393838323135663962633339303634353763
          3935623562343131370a383439346166323832353232373933613363383435333037343231393830
          35326662353662316339633732323335653332346465383030633333333638323735383666303264
          35663335623061366536363134303061323861356331373334653363383961396330386136636661
          63373230643163633465303933396336393531633035616335653234376666663935353838356135
          36323866346139666462
```

Generate `secret_key_base` for the server the same way:

```shell
openssl rand -base64 48 | ansible-vault encrypt_string --vault-id vault.key --stdin-name 'secret_key_base'
```

Generate `db_pass` for the db user:

```shell
openssl rand -hex 16 | ansible-vault encrypt_string --vault-id vault.key --stdin-name 'db_pass'
```

This playbook configures the production server, setting the
`$HOME/.erlang.cookie` file on the web server and generates a Conform config file at
`/etc/deploy-template/deploy_template.conf` with the other vars:

```shell
ansible-playbook --vault-password-file vault.key -u $USER -v -l web-servers playbooks/config-web.yml -D
```

This playbook configures `config/prod.secret.exs` on the build server.

```shell
ansible-playbook --vault-password-file vault.key -u $USER -v -l build-servers playbooks/config-build.yml -D
```

TODO: link to config blog post when it's live

## Database

Most apps use a database. The Ansible playbooks create the database
for you on the build server, assuming everything is running on the same server.

Whenever you change the db schema, you need to run migrations on the server.

After building the release, but before deploying the code, update the db to
match the code:

```shell
scripts/db-migrate.sh
```

That script runs:

```shell
MIX_ENV=prod mix ecto.migrate
```

Surprisingly, the same process also works when we are deploying in an AWS cloud
environment. Create a build instance in the VPC private subnet which has
permissions to talk to the RDS database. Run the Ecto commands to migrate the
db, build the release, then do a Blue/Green deployment to the ASG using AWS
CodeDeploy.

# Changes

Following are the steps used to set up this repo. You can do the same to add
it to your own project.

It all began with a new Phoenix project:

```shell
mix phx.new deploy_template
```

## Set up distillery

Generate initial files in the `rel` dir:

```shell
mix release.init
```

Modify `rel/config.exs` and `vm.args.eex`.

## Set up ASDF

Add the `.tool-versions` file to specify versions of Elixir and Erlang.

## Configure for running in a release

Edit `config/prod.exs`

Uncomment this so Phoenix will run in a release:

```elixir
config :phoenix, :serve_endpoints, true
```

## Add Ansible

Add the Ansible tasks to set up the servers and deploy code, in the `ansible`
directory. Configure the vars in the inventory.

This repository contains local copies of roles from Ansible Galaxy in
`roles.galaxy`. To install them, run:

```shell
ansible-galaxy install --roles-path roles.galaxy -r install_roles.yml
```

## Add mix tasks for local deploy

Add `lib/mix/tasks/deploy.ex`

## Add Conform for configuration

Add [Conform](https://github.com/bitwalker/conform) to `deps` in `mix.exs`:

```elixir
 {:conform, "~> 2.2"}
```

Generate schema to the `config/deploy_template.schema.exs` file.

```elixir
MIX_ENV=prod mix conform.new
```

Generate a sample `deploy_template.prod.conf` file:

```elixir
MIX_ENV=prod mix conform.configure
```

Integrate with Distillery, by adding `plugin Conform.ReleasePlugin`
to `rel/config.exs`:

```elixir
release :deploy_template do
  set version: current_version(:deploy_template)
  set applications: [
    :runtime_tools
  ]
  plugin Conform.ReleasePlugin
end
```

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
