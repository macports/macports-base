#!/bin/sh

# This is just for compiling Pextlib!  It's not a more generic wrapper.
# Real simple for now, just come up with compilation flags for Darwin
# or for FreeBSD.  Could obviously be extended later for other OSen.

case `uname -s` in
	Darwin)
		cc -c -DPIC -O -pipe -no-cpp-precomp $*
	;;

	FreeBSD)
		cc -c -fPIC -DPIC -I/usr/local/include/tcl8.3 -O -pipe $*
	;;
	Linux)
		cc -c -fPIC -DPIC -I/usr/include/tcl8.3 -O -pipe $*
	;;
esac
