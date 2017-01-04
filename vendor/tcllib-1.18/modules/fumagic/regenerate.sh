#!/bin/sh

# Point this to an unpacked source distribution of file(1) to
# regenerate the recognizers.

filesrc="$1"

mime="${filesrc}/magic/magic.mime"
type="${filesrc}/magic/Magdir"

`dirname $0`/tmc -merge mimetypes.tcl '::fileutil::magic::mimetype::run' "${mime}"
`dirname $0`/tmc -merge filetypes.tcl '::fileutil::magic::filetype::run' "${type}"
exit 0
