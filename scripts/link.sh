#!/bin/sh

# This is just for linking Pextlib!  It's not a more generic wrapper.
# Real simple for now, just come up with compilation flags for Darwin
# or for FreeBSD.  Could obviously be extended later for other OSen.

if [ "$1" = "-n" ]; then
	case `uname -s` in
		Darwin) echo $2.dylib ;;
		FreeBSD) echo $2.so ;;
		NetBSD) echo $2.so ;;
		Linux) echo $2.so ;;
	esac
	exit 0
fi

LIB=$1; shift

case `uname -s` in
	Darwin)
		cc -dynamiclib $* -o ${LIB}.dylib -ltcl -framework CoreFoundation
	;;

	FreeBSD)
		cc -shared $* -o ${LIB}.so -L/usr/local/lib -ltcl83
	;;
	NetBSD)
		cc -shared $* -o ${LIB}.so -L/usr/pkg/lib -ltcl83
	;;
	Linux)
		cc -shared $* -o ${LIB}.so -L/usr/lib/ -ltcl8.3
	;;
esac
