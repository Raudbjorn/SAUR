#!/bin/sh
set -eu
export ELECTRON_IS_DEV=0

# Disable core dumps so credential-bearing memory is never written to an on-disk core file.
# shellcheck disable=SC3045
ulimit -c 0
export LD_PRELOAD=/usr/lib/bitwarden/libprocess_isolation.so

cd /usr/lib/bitwarden
exec electron@electronversion@ /usr/lib/bitwarden/app.asar "$@"
