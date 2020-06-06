#!/bin/sh

set -e

fail() {
	echo "Failed at $*!" 1>&2
	exit 1
}

./explicit_bzero || fail explicit_bzero

t="$PWD/test-results"
s="$PWD/src/regress/usr.bin/signify"

rm -rf "$t"
mkdir "$t"

# We don't have native sha* like OpenBSD, so emulate them:
function fixsha { sed 's/^SHA\([0-9]*\)(\(.*\))= /SHA\1 (\2) = /'; }
function sha256 { openssl dgst -sha256 "$@" | fixsha; }
function sha512 { openssl dgst -sha512 "$@" | fixsha; }

# Use the signify we just compiled, not some other one.
alias signify="$PWD/signify"

( cd "$t" && . "$s/signify.sh" "$s" ) || fail signify

echo 'All tests passed!'
