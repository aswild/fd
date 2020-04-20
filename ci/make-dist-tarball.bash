#!/bin/bash

die() {
    echo "Error: $*"
    exit 1
}

[[ -f Cargo.toml ]] || die "this script must be run from the root of the repo"

if [[ ! -x target/release/fd ]]; then
    echo "Building release config"
    cargo build --release --locked || die "build failed"
fi

gitver="$(git describe --long --tags)"
tarname="fd-${gitver#v}"
tarfile="${tarname}.tar.gz"

if [[ -f "$tarfile" ]]; then
    echo "warning: tarball $tarfile already exists, overwriting"
    rm $tarfile
fi

outdir="$(find target/release/build -maxdepth 2 -path '*/fd-find-*/out' -type d)"
[[ -d $outdir ]] || die "failed to find output directory"

set -e
tmpdir="$(mktemp -d)"
trap "rm -rf $tmpdir" EXIT

tardir="$tmpdir/$tarname"
install -v -s -Dm755 target/release/fd $tardir/bin/fd
install -v -Dm644 $outdir/fd.bash $tardir/share/bash-completions/completions/fd
install -v -Dm644 $outdir/fd.fish $tardir/share/fish/vendor_completions.d/fd.fish
install -v -Dm644 $outdir/_fd $tardir/share/zsh/site-functions/_fd
install -v -Dm644 doc/fd.1 $tardir/share/man/man1/fd.1

tar -czf $tarfile -C $tmpdir $tarname

echo "Done: $tarfile"
