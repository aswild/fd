#!/bin/bash

set -euo pipefail

run() {
    echo "+ $*"
    "$@"
}

build_arch() {
    local target="$1"
    local strip="$2"
    local strip_arg
    if [[ -n "$strip" ]]; then
        strip_arg="STRIP=$strip"
    else
        strip_arg="NOSTRIP=1"
    fi
    run make TARGET="$target" "$strip_arg" build dist
}

if [[ "${1:-}" == "--docker" ]]; then
    run docker run --rm --user "$(id -u)":"$(id -g)" -v "$PWD":/usr/src/fd -w /usr/src/fd \
        aswild/rust-multiarch ci/make_dist.bash
    exit 0
fi

run make clean

build_arch x86_64-unknown-linux-gnu strip
build_arch aarch64-unknown-linux-gnu aarch64-linux-gnu-strip
build_arch aarch64-unknown-linux-musl aarch64-linux-gnu-strip
build_arch x86_64-pc-windows-gnu x86_64-w64-mingw32-strip
