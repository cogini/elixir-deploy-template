#!/bin/bash

# Deploy app to local server

export MIX_ENV=prod
APP_NAME=deploy-template

# Exit on errors
set -e
# set -o errexit -o xtrace

CURDIR=$PWD
BINDIR=`dirname $0`
cd $BINDIR; BINDIR=$PWD; cd $CURDIR

BASEDIR=$BINDIR/..
cd $BASEDIR

# mix ecto.migrate

mix deploy.local
sudo /bin/systemctl restart $APP_NAME
