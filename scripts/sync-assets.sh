#!/usr/bin/env bash

# Sync static assets to CDN

export MIX_ENV=prod
export AWS_PROFILE=deploy-template-prod

STATIC_ASSETS_BUCKET=cogini-deploy-template-assets

# Exit on errors
set -e
# set -o errexit -o xtrace

CURDIR="$PWD"
BINDIR=$(dirname "$0")
cd "$BINDIR"; BINDIR="$PWD"; cd "$CURDIR"

BASEDIR="$BINDIR/.."
cd "$BASEDIR"

source "$HOME/.asdf/asdf.sh"

aws s3 sync "$BASEDIR/priv/static" "s3://$STATIC_ASSETS_BUCKET"
