#!/bin/sh

# Just tell us where the Tcl installation directory is.

case `uname -s` in
        Darwin)
	    if [ `uname -r` = 7.0 ]; then
		echo /System/Library/Tcl/8.4/darwinports1.0
	    else
		echo /System/Library/Tcl/8.3/darwinports1.0
	    fi
	    ;;
	Linux) echo /usr/lib/tcl8.3/darwinports1.0 ;;
	NetBSD) echo /usr/pkg/lib/tcl8.3/darwinports1.0 ;;
        *) echo /usr/local/lib/tcl8.3/darwinports1.0 ;;
esac
