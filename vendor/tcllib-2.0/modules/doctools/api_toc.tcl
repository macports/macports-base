# -*- tcl -*-
# api_toc.tcl -- API placeholders
#
# Copyright (c) 2003 Andreas Kupries <andreas_kupries@sourceforge.net>

################################################################
# This file defines all commands expected from a doctoc formatter by the
# doctools library. It is loaded into the formatter interpreter before
# the code for a particular doctoc format is loaded. All commands defined
# here return an error. This ensures the generation of errors if a
# format forgets to define commands in the API.

################################################################
# Here it comes

foreach __cmd {
    toc_initialize toc_shutdown toc_setup toc_numpasses
    toc_listvariables toc_varset
    fmt_toc_begin fmt_toc_end fmt_division_start fmt_division_end
    fmt_item fmt_comment fmt_plain_text
} {
    proc $__cmd {args} [list return  "return -code error \"Unimplemented API command $__cmd\""]
}
unset __cmd

################################################################
