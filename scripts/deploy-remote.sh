#!/usr/bin/env bash

# Deploy app to remote servers

export MIX_ENV=prod

# Exit on errors
set -e
# set -o errexit -o xtrace

CURDIR="$PWD"
BINDIR=$(dirname "$0")
cd "$BINDIR"; BINDIR="$PWD"; cd "$CURDIR"

BASEDIR="$BINDIR/.."
cd "$BASEDIR/ansible"

ansible-playbook -u deploy -v -l web-servers playbooks/deploy-app.yml --tags deploy --extra-vars ansible_become=false -D
