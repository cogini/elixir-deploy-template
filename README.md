# DeployTemplate

This is an example of deploying an Elixir app based on this
[blog post](https://www.cogini.com/blog/best-practices-for-deploying-elixir-apps/).

# Installation

## Check out the code from git to your local dev machine.

```shell
git clone https://github.com/cogini/elixir-deploy-template
```

## Set up ASDF

Following [the ASDF docs](https://github.com/asdf-vm/asdf):

Install plugins for our tools

```shell
asdf plugin-add erlang
asdf plugin-add elixir
asdf plugin-add nodejs
```

Install Erlang, Elixir and Node.js.

```shell
asdf install
```

Install libraries into the ASDF Elixir dirs

```shell
mix local.hex --force
mix local.rebar --force
mix archive.install https://github.com/phoenixframework/archives/raw/master/phx_new.ez --force
```

## Initialize the app

```shell
mix deps.get
mix deps.compile
# Not needed anymore
# cd assets && npm install && node node_modules/brunch/bin/brunch build
```

At this point you should be able to run the app locally with

```shell
mix compile
iex -S mix phx.server
open http://localhost:4000/
```

## Deploy the app

Install Ansible on your dev machine. See [the Ansible
docs](http://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
for details.

Maybe as simple as:

```shell
pip install ansible
```

### Set up a target machine

An easy option is [Digital Ocean](https://m.do.co/c/65a8c175b9bf) (use our affilate
code to say thanks for this guide). Their smallest $5/month Droplet
will run Elixir fine. It can be a bit slow doing the initial compile
of Erlang or if you want to run heavy tests like Dialyzer.

Add the host to the `~/.ssh/config` on your dev machine, e.g.:

    Host elixir-deploy-template
        HostName 123.45.67.89

From the `ansible` directory, add the host to the Ansible inventory
`inventory/hosts`:

    [web-servers]
    elixir-deploy-template

    [build-servers]
    elixir-deploy-template

## Configure the target server

Run Ansible to set up user accounts on the server:

```shell
ansible-playbook -u root -v -l web-servers playbooks/manage-users.yml -D
```

See comments in `playbooks/manage-users.yml` for other ways to run the playbook.

Set up app directories, etc:

```shell
ansible-playbook -u $USER -v -l web-servers playbooks/deploy-template.yml --skip-tags deploy -D
```

## Set up build server

This can be the same as the web server, or a different one.

Set up the build server, mainly ASDF:

```shell
ansible-playbook -u $USER -v -l build-servers playbooks/setup-build.yml -D
```

## Build the app

Log into the `deploy` user on the build machine:

```shell
ssh -A build@elixir-deploy-template
```

The `-A` ssh flag gives the session on the server access to your local ssh
keys.  So if your loal user can access a github repo, then the server can do
it, without having deploy keys on the server. Similarly, you can deploy code to
a prod server using Ansible. If you are using a CI server to build and deploy
code, then you would normally set up a deploy key with access to your source
and configure the deploy user account on the prod servers to trust the build
server.

Check out the source:

```shell
mkdir build
cd build
git clone https://github.com/cogini/elixir-deploy-template
cd elixir-deploy-template

# Install Erlang, Elixir and Node.js as specified in .tool-versions
asdf install

# Install Elixir libraries
mix local.hex --force
mix local.rebar --force
```

Generate a cookie and put it in `config/cookie.txt`.

```elixir
iex> :crypto.strong_rand_bytes(32) |> Base.encode16
```

Build the production release

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
or access the machine from over the network.

## Deploy the release

If you are running on the same machine, then you can use the mix tasks
to deploy locally.

In `mix.exs`, set `deploy_dir` to match the directory structure in Ansible,
e.g.:

```elixir
deploy_dir: "/opt/myorg/deploy-template/",
```

Deploy the release:

```shell
MIX_ENV=prod mix deploy.local
sudo /bin/systemctl restart deploy-template
```

This assumes that the build is being done under the `deploy` user, who
owns the files under `/opt/myorg/deploy-template` and has a `/etc/sudoers.d`
config which allows it to run the `/bin/systemctl restart deploy-template`
command.

Have a look at the logs:
```shell
# systemctl status deploy-template
```

```shell
# journalctl -r -u deploy-template
```

## Deploy to a remote machine using Ansible

From your dev machine, install Ansible on the build machine:

```shell
ansible-playbook -u deploy -v -l build-servers playbooks/setup-ansible.yml -D
```

On the build machine, log in as `deploy` and go to the `build/elixir-deploy-template/ansible`
directory.

```shell
ssh -A build@elixir-deploy-template
```

Deploy the app:

```shell
ansible-playbook -u deploy -v -l web-servers playbooks/deploy-template.yml --tags deploy --extra-vars ansible_become=false -D
```

# Changes

Following are all the steps used to set up this repo.

It all began with a new Phoenix project:

```shell
mix phx.new --no-ecto deploy_template
```

## Set up distillery

Generate initial `rel` files:

```shell
mix release.init
```

Modify `rel/config.exs` to get cookie from file and `vm.args.eex` to tune the VM settings.

## Set up ASDF

Add `.tool-versions` file to specify versions of Elixir and Erlang.

## Add mix tasks for deploy.local

Add `lib/mix/tasks/deploy.ex`

## Configure for running in a release

Edit `config/prod.exs`

Uncomment this:

```elixir
config :phoenix, :serve_endpoints, true
```

Comment this, as we are not using `prod.secret.exs`:

```elixir
import_config "prod.secret.exs"
```

## Add Ansible

Add Ansible tasks to set up the server and deploy code, in the `ansible` directory.

To make it easier for beginners to run, this repository contains local copies
of roles from Ansible Galaxy in the roles.galaxy. To update them, run:

```shell
ansible-galaxy install --roles-path roles.galaxy -r install_roles.yml
```

## Add shutdown_flag

https://github.com/cogini/shutdown_flag

# TODO

Firewall config
Nginx config
Set up Conform
Set up versioned static assets

Add example for CodeDeploy

Log with journald prefix
systemd watchdog notify
Log to journald unix domain socket
systemd socket activation
