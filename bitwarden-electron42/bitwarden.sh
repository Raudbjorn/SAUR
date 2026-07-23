#!/bin/sh
set -eu
export ELECTRON_IS_DEV=0

# Prevent credential-bearing process memory from being dumped or attached.
# shellcheck disable=SC3045
ulimit -c 0
export LD_PRELOAD=/usr/lib/bitwarden/libprocess_isolation.so

cd /usr/lib/bitwarden
exec electron42 /usr/lib/bitwarden/app.asar "$@"
