#!/bin/bash

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

run make clean

build_arch x86_64-unknown-linux-gnu strip
build_arch aarch64-unknown-linux-gnu aarch64-linux-gnu-strip
build_arch x86_64-pc-windows-gnu x86_64-w64-mingw32-strip
