# DeployTemplate

This is an example of deploying an Elixir app based on this
[blog post](https://www.cogini.com/blog/best-practices-for-deploying-elixir-apps/).

Here are the steps used to set it up:

## Generate app

It all began with a Phoenix generator:

    mix phx.new --no-ecto deploy_template

## Set up distillery

Generate initial `rel` files:

    mix release.init

Modify `rel/config.exs` to use random cookie and tune VM with `vm.args.eex` file.

## Set up ASDF

Add `.tool-versions` file to specify versions of Elixir and Erlang.

## Add mix tasks for deploy.local

Add `lib/mix/tasks/deploy.ex`

## Set up Conform

TODO

- Set up Conform

## Add Ansible

Add Ansible tasks to set up the server and deploy code, in the `ansible` directory.

To make it easier for beginners to run, this repository contains local copies
of roles from Ansible Galaxy. To update them, run:

    ansible-galaxy install --roles-path roles.galaxy -r install_roles.yml

## Add shutdown_flag

https://github.com/cogini/shutdown_flag


# Installation

## Check out the code from git to your local dev machine.

## Set up ASDF

Following [the ASDF docs](https://github.com/asdf-vm/asdf):

```shell
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.4.3
```

Add the ASDF scripts to your shell startup files:

```shell
# For Max OSX
echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bash_profile
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bash_profile

# For Linux
echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc
```

Install plugins for our tools

```shell
asdf plugin-add erlang
asdf plugin-add elixir
asdf plugin-add nodejs
```

Install Erlang, Elixir and Node.js

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
# cd assets && npm install && node node_modules/brunch/bin/brunch build

```

At this point you should be able to run the app locally with

```shell
mix compile
iex -S mix phx.server
open http://localhost:4000/
```

## Build the app release

```shell
mix deps.get --only prod
MIX_ENV=prod mix compile
# brunch build --production
MIX_ENV=prod mix phx.digest
MIX_ENV=prod mix release
```

Now you should be able to run the app from the release:

Edit `config/prod.exs`

```elixir
config :phoenix, :serve_endpoints, true
# import_config "prod.secret.exs"
```

```shell
PORT=4001 _build/prod/rel/deploy_template/bin/deploy_template foreground
```

## Deploy the app

Install Ansible on your local machine. Maybe as simple as:

```shell
pip install ansible
```

See [the Ansible docs](http://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) for details.

### Add machine to inventory

Add host to `~/.ssh/config`, e.g.:

    Host elixir-deploy-template
        HostName 159.89.197.173

From the `ansible` directory...

Add host to inventory `inventory/hosts`, e.g.:

    [web-servers]
    elixir-deploy-template

## Set up the machine

	sudo yum install git

	sudo yum install epel-release
	sudo yum group install "Development Tools"
	sudo yum install openssl-devel

Add user accounts:

```shell
ansible-playbook -u root -v -l elixir-deploy-template playbooks/manage-users.yml -D
```

See comments in `playbooks/manage-users.yml` for other ways to run the playbook.

Set up app directories:

```shell
ansible-playbook -u $USER -v -l web-servers playbooks/deploy-template.yml --skip-tags deploy -D
```

## Deploy the app

Check out source on build machine

	ssh -A elixir-deploy-template
	mkdir build
	cd build
	sudo yum install git
	git clone https://github.com/cogini/elixir-deploy-template

Set up ASDF

Install build deps for Erlang

On CentOS 7.x:

	# Utils
	sudo yum install htop tmux

	# https://github.com/erlang/otp/blob/maint/HOWTO/INSTALL.md

	sudo yum install epel-release -y
    # sudo yum group install "Development Tools"
	sudo yum install -y gcc gcc-c++ glibc-devel make ncurses-devel openssl-devel autoconf 

	# sudo yum install -y gcc         glibc-devel make ncurses-devel openssl-devel automake autoconf
	# sudo yum install pam-devel
	# sudo yum install perl-Digest-SHA-5.85-3.el7.x86_64

	# Java http://www.oracle.com/technetwork/java/javase/downloads
	# yum install java-1.8.0-openjdk-devel
    # yum install pam-devel perl-Digest-SHA

    # Node.js build deps
    yum install gpg perl-Digest-SHA


See [the ASDF Erlang plugin docs](https://github.com/asdf-vm/asdf-erlang) for details:

```shell
# Set Erlang build options
# https://github.com/asdf-vm/asdf-erlang
export KERL_CONFIGURE_OPTIONS="--disable-debug --without-javac"

# Import the Node.js release team's OpenPGP keys to main keyring:
# https://github.com/asdf-vm/asdf-nodejs
bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring

asdf install
```

Install build deps for ansible

	sudo yum install python-devel python-pip libffi-devel openssl-devel
	sudo pip install ansible


Deploy the app:

```shell
ansible-playbook -u deploy -v -l web-servers playbooks/deploy-template.yml --tags deploy --extra-vars ansible_become=false -D
```

# TODO

Set up versioned static assets
Add example for CodeDeploy

Comment out config/prod.secret.exs

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](http://www.phoenixframework.org/docs/deployment).

## Learn more

  * Official website: http://www.phoenixframework.org/
  * Guides: http://phoenixframework.org/docs/overview
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix
