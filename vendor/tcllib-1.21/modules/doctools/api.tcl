# -*- tcl -*-
# api.tcl -- API placeholders
#
# Copyright (c) 2001 Andreas Kupries <andreas_kupries@sourceforge.net>
# Copyright (c) 2002 Andreas Kupries <andreas_kupries@sourceforge.net>
# Copyright (c) 2003 Andreas Kupries <andreas_kupries@sourceforge.net>

################################################################
# This file defines all commands expected from a formatter by the
# doctools library. It is loaded into the formatter interpreter before
# the code for a particular format is loaded. All commands defined
# here return an error. This ensures the generation of errors if a
# format forgets to define commands in the API.

################################################################
# Here it comes

foreach __cmd {
    initialize shutdown setup numpasses listvariables varset

    manpage_begin moddesc titledesc manpage_end require description
    section para list_begin list_end lst_item call bullet enum see_also
    keywords example example_begin example_end nl arg cmd opt emph strong
    comment sectref syscmd method option widget fun type package class var
    file uri term const copyright category
} {
    proc fmt_$__cmd {args} [list return  "return -code error \"Unimplemented API command $__cmd\""]
}
unset __cmd

################################################################
