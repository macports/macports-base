#!/bin/sh

# Point this to an unpacked source distribution of file(1) to
# regenerate the recognizers.

filesrc="$1"

type="${filesrc}/magic/Magdir"

`dirname $0`/tmc -merge filetypes.tcl '::fileutil::magic::filetype' "${type}"
exit 0
