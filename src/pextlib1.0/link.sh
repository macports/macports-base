#!/bin/sh

# This is just for linking Pextlib!  It's not a more generic wrapper.
# Real simple for now, just come up with compilation flags for Darwin
# or for FreeBSD.  Could obviously be extended later for other OSen.

LIB=$1; shift

case `uname -s` in
	Darwin)
		cc -dynamiclib $* -o ${LIB}.dylib -ltcl
	;;

	FreeBSD)
		cc -shared $* -o ${LIB}.so -L/usr/local/lib -ltcl84
	;;
esac
