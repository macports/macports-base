#!/bin/sh

# Just tell us where the Tcl installation directory is.

case `uname -s` in
        Darwin) echo /System/Library/Tcl/8.3/darwinports1.0 ;;
        *) echo /usr/local/lib/tcl83/darwinports1.0 ;;
esac
