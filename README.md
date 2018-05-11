# deploy-template

This is a turn-key example app which shows how to deploy Elixir app based on
this [best practices for deploying elixir
apps](https://www.cogini.com/blog/best-practices-for-deploying-elixir-apps/)
blog post.

It'ts been tested deploying to Digital Ocean](https://m.do.co/c/65a8c175b9bf),
with CentOS 7 and Ubuntu 16.04 and 18.04. It assumes a distro that supports
systemd.

# Installation

Check out the code from git to your local dev machine:

```shell
git clone https://github.com/cogini/elixir-deploy-template
```

## Set up ASDF

Install ASDF as described in [the ASDF docs](https://github.com/asdf-vm/asdf).

Install plugins for our tools:

```shell
asdf plugin-add erlang
asdf plugin-add elixir
asdf plugin-add nodejs
```

Install Erlang, Elixir and Node.js:

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

## Initialize the app

```shell
mix deps.get
mix deps.compile
# Not needed anymore
# cd assets && npm install && node node_modules/brunch/bin/brunch build
```

At this point you should be able to run the app locally with:

```shell
mix compile
iex -S mix phx.server
open http://localhost:4000/
```

## Deploy the app

Install Ansible on your dev machine. See [the Ansible
docs](http://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
for details.

That may be as simple as:

```shell
pip install ansible
```

### Set up a target machine

An easy option is [Digital Ocean](https://m.do.co/c/65a8c175b9bf). Their
smallest $5/month Droplet will run Phoenix fine.

Add the host to the `~/.ssh/config` on your dev machine:

    Host elixir-deploy-template
        HostName 123.45.67.89

Add the host to the groups in the Ansible inventory `ansible/inventory/hosts` file:

    [web-servers]
    elixir-deploy-template

    [build-servers]
    elixir-deploy-template

## Configure the target server using Ansible

From the `ansible` dir:

Newer versions of Ubuntu (16.04+) ship with Python 3, but the default for Ansible is Python 2.
If you are running Ubuntu, install Python 2:

```shell
ansible-playbook -u root -v -l elixir-deploy-template playbooks/setup-python.yml -D
```

Set up user accounts on the server:

```shell
ansible-playbook -u root -v -l web-servers playbooks/manage-users.yml -D
```

Do initial server setup (currently minimal):

```shell
ansible-playbook -u $USER -v -l web-servers playbooks/setup-web.yml -D
```

See comments in `playbooks/manage-users.yml` for other ways to run the playbook.

Set up the app (create dirs, etc.):

```shell
ansible-playbook -u $USER -v -l web-servers playbooks/deploy-template.yml --skip-tags deploy -D
```

## Set up the build server

The build server can be the same as the web server.

Set up ASDF:

```shell
ansible-playbook -u $USER -v -l build-servers playbooks/setup-build.yml -D
```

## Build the app

Log into the `deploy` user on the build machine:

```shell
ssh -A deploy@elixir-deploy-template
```

The `-A` flag on the ssh command gives the session on the server access to your
local ssh keys.  If your local user can access a GitHub repo, then the server
can do it, without having to put keys on the server. Similarly, you can deploy
code to a prod server using Ansible without the web server trusting the build server.

If you are using a CI server to build and deploy code, then you would normally
create a deploy key in GitHub so it can access to your source and configure the
`deploy` user account on the prod servers to trust the build server.

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

The initial build of Erlang from source can take a while, so you may
want to run it under `tmux` or `screen`.

Install libraries into the ASDF dir for the specified Elixir version:

```shell
mix local.hex --force
mix local.rebar --force
```

Generate a cookie and put it in `config/cookie.txt`:

```elixir
iex> :crypto.strong_rand_bytes(32) |> Base.encode16
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
or access the machine over the network.

## Deploy the release

If you are running on the same machine, then you can use the mix tasks to
deploy locally.

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

Add the web-servers hosts to the `~/.ssh/config` on the deploy machine:

    Host elixir-deploy-template
        HostName 123.45.67.89

Deploy the app:

```shell
ansible-playbook -u deploy -v -l web-servers playbooks/deploy-template.yml --tags deploy --extra-vars ansible_become=false -D
```

# Changes

Following are the steps used to set up this repo.

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

Add `.tool-versions` file to specify versions of Elixir and Erlang.

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

Add tasks to set up the servers and deploy code, in the `ansible`
directory.

To make it easier for beginners to run, this repository contains local copies
of roles from Ansible Galaxy in `roles.galaxy`. To update them, run:

```shell
ansible-galaxy install --roles-path roles.galaxy -r install_roles.yml
```

## Add mix tasks for local deploy

Add `lib/mix/tasks/deploy.ex`

## Add shutdown_flag library

Add [shutdown_flag](https://github.com/cogini/shutdown_flag) to `mix.exs`:

    {:shutdown_flag, github: "cogini/shutdown_flag"},

# TODO

* Firewall config
* Nginx config
* Set up Conform
