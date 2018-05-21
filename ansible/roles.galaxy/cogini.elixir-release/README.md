# elixir-release

This Ansible role deploys Elixir/Phoenix releases.
It uses Erlang "releases" with systemd for process supervision.

## Directory structure

We use a structure like Capistrano to manage the release files.
We create a base directory named for the organization and app:

    /opt/myorg/foo

Unpack the release files to a directory under `releases`, named with a timestamp:

    /opt/myorg/foo/releases/20171114T072116

Then make a symlink from `/opt/myorg/foo/current` to the currently running release.

## Restarting

After we have deployed the new release, we restart the app to make it live:

```shell
sudo /bin/systemctl restart foo
```

The deploy user account needs sufficient permissions to restart the app, though.
Instead of giving the deploy account full sudo permissions, a user-specific
sudo config file specifies what commands it can run,
e.g. `/etc/sudoers.d/deploy-foo`:

    deploy ALL=(ALL) NOPASSWD: /bin/systemctl start foo, /bin/systemctl stop foo, /bin/systemctl restart foo

Better is if we didn't require sudo permissions at all. One option is to take
advantage of the supervision provided by systemd to restart the app.

When we deploy a new release, the deploy user uploads the new code, sets up the
symlink, then tells the app to shutdown by touching a flag file on the disk or
pinging a special URL. The app does a clean shutdown, systemd notices and
starts it with the new code.

The [shutdown_flag library](https://github.com/cogini/shutdown_flag) handles this
for flag files.

See https://www.cogini.com/blog/best-practices-for-deploying-elixir-apps/ for background.
and https://github.com/cogini/elixir-deploy-template for a full example.

# Requirements

None

# Role Variables

A unique prefix for our directories. This could be your organization or the
overall project.

    elixir_release_org: myorg

The external name of the app, used to name directories and the systemd unit.

    elixir_release_name: foo

The internal "Elixir" name of the app, used to by Distillery to name
directories and scripts.

    elixir_release_name_code: "{{ elixir_release_name }}"

Version of the app in the release. Default is to read from the release.

    elixir_release_version: "0.1.0"

App environment

    elixir_release_mix_env: prod

HTTP listen port. This is the port that Phoenix listens on.

    elixir_release_http_listen_port: 4001

OS user that deploys / owns the release files

    elixir_release_deploy_user: deploy

OS group that deploys / owns the release files

    elixir_release_deploy_group: "{{ elixir_release_deploy_user }}"

OS user that the app runs under

    elixir_release_app_user: "{{ elixir_release_name }}"

OS group that the app runs under

    elixir_release_app_group: "{{ elixir_release_app_user }}"

Base directory for deploy files

    elixir_release_deploy_dir: /opt/{{ elixir_release_org }}/{{ elixir_release_name }}
    elixir_release_releases_dir: "{{ elixir_release_deploy_dir }}/releases"

Location for app temp files

    elixir_release_temp_dir: /var/tmp/{{ elixir_release_org }}/{{ elixir_release_name }}

# Optional

These dirs are only created if they are defined.

Location of per-machine config files

    elixir_release_conf_dir: /etc/{{ elixir_release_name }}

Location of runtime scripts, e.g. used in cron jobs

    elixir_release_scripts_dir: "{{ elixir_release_deploy_dir }}/scripts"

Location of runtime logs

    elixir_release_log_dir: /var/log/{{ elixir_release_name }}

Base directory for app data

    elixir_release_var_dir: /var/{{ elixir_release_org }}/{{ elixir_release_name }}

Location of app data files

    elixir_release_data_dir: "{{ elixir_release_var_dir }}/data"

Path to conform conf file

    elixir_release_conform_conf_path: "{{ elixir_release_conf_dir }}/{{ elixir_release_name_code }}.conf"

Location of flag dir

    elixir_release_shutdown_flag_dir: "/var/tmp/{{ elixir_release_deploy_user }}/{{ elixir_release_name }}"
    elixir_release_shutdown_flag_file: "{{ app_shutdown_flag_dir }}/shutdown.flag"

How to restart after deploying.

    elixir_release_restart_method: systemctl
or

    elixir_release_restart_method: touch

# Defaults

Open file limits

    elixir_release_limit_nofile: 65536

Seconds to wait between restarts

    elixir_release_systemd_restart_sec: 5

# Dependencies

None

# Example Playbook

    - hosts: '*'
      become: true
      roles:
        - cogini.elixir-release

Run setup tasks, e.g. installing packages and creating directories.
Run this from your dev machine, specifying a user with sudo permissions.

    ansible-playbook -u $USER -v -l web-servers playbooks/deploy-app.yml --skip-tags deploy -D

Deploy the code. Run this from the build server, from a user account with ssh
access to the deploy account on the target machine.

    ansible-playbook -u deploy -v -l web-servers playbooks/deploy-app.yml --tags deploy --extra-vars ansible_become=false -D

# License

MIT

# Author Information

Jake Morrison <jake@cogini.com>
