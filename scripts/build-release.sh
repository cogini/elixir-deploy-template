#!/bin/bash

# Build production release

export MIX_ENV=prod

# Exit on errors
set -e
# set -o errexit -o xtrace

CURDIR=$PWD
BINDIR=`dirname $0`
cd $BINDIR; BINDIR=$PWD; cd $CURDIR

BASEDIR=$BINDIR/..
cd $BASEDIR

source $HOME/.asdf/asdf.sh

echo "Pulling latest code from git"
git pull

echo "Updating versions of Erlang/Elixir/Node.js if necessary"
asdf install

echo "Building release"
mix deps.get --only $MIX_ENV
mix do compile, phx.digest, release
