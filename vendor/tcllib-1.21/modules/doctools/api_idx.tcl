# -*- tcl -*-
# api_idx.tcl -- API placeholders
#
# Copyright (c) 2003 Andreas Kupries <andreas_kupries@sourceforge.net>

################################################################
# This file defines all commands expected from a docidx formatter by the
# doctools library. It is loaded into the formatter interpreter before
# the code for a particular docidx format is loaded. All commands defined
# here return an error. This ensures the generation of errors if a
# format forgets to define commands in the API.

################################################################
# Here it comes

foreach __cmd {
    idx_initialize idx_shutdown idx_setup idx_numpasses
    idx_listvariables idx_varset
    fmt_index_begin fmt_index_end fmt_key fmt_manpage fmt_url
    fmt_comment fmt_plain_text
} {
    proc $__cmd {args} [list return  "return -code error \"Unimplemented API command $__cmd\""]
}
unset __cmd

################################################################
