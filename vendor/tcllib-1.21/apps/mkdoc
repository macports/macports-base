#!/bin/sh
# -*- tcl -*- A Tcl comment, whose contents don't matter \
exec tclsh "$0" "$@"

package require Tcl 8.6
package require mkdoc
package require hook

set Usage [string map [list "\n    " "\n"] {
    Usage: __APP__ ?[--help|version]? INFILE OUTFILE ?[--css file.css]?

    mkdoc - code documentation tool to process embedded Markdown markup
            given after "#'" comments

    Positional arguments (required):
    
        INFILE - input file with:
               - embedded Markdown comments: #' Markdown markup
               - pure Markdown code (file.md)

        OUTFILE - output file usually HTML or Markdown file,
                  file format is deduced on file extension .html or .md,
                  if OUTFILE is the `-` sign output is written to stdout

    Optional arguments:

        --help         - display this help page, and exit
        --version      - display version number, and exit
        --license      - display license information, and exit
        --css CSSFILE  - use the specified CSSFILE instead of internal default 
                         mkdoc.css

    Examples:

        # create manual page for mkdoc.tcl itself 
        __APP__ mkdoc.tcl mkdoc.html

        # create manual code for a CPP file using a custom style sheet
        __APP__ sample.cpp sample.html --css manual.css

        # extract code documentation as simple Markdown
        # ready to be processed further with pandoc
        __APP__ sample.cpp sample.md 

        # convert a Markdown file to HTML
        __APP__ sample.md sample.html

    Author: @ Dr. Detlef Groth, Schwielowsee, 2019-2022

    License: BSD
}]

if {[lsearch -exact $argv {--version}] > -1} {
    puts "[package provide mkdoc::mkdoc]"
    return
}
if {[lsearch -exact $argv {--license}] > -1} {
    puts "BSD License - see manual page"
    return
}

proc Report {event settings} {
    set label [dict get {
	D Defaults
	Y YAML....
	F Final...
    } $event]
    puts "$label $settings"
}

proc Done {outfile} {
    puts "Results written to `$outfile`."
}

proc Processing {infile inmode outmode} {
    puts "Processing $inmode file `$infile` for $outmode."
}

#hook bind mkdoc::mkdoc Header/Defaults x {::Report D}
hook bind mkdoc::mkdoc Header/YAML     x {::Report Y}
hook bind mkdoc::mkdoc Header/Final    x {::Report F}
hook bind mkdoc::mkdoc Done            x ::Done
hook bind mkdoc::mkdoc Processing      x ::Processing

if {[llength $argv] < 2 || [lsearch -exact $argv {--help}] > -1} {
    set usage [regsub -all {__APP__} $Usage [info script]]
    puts $usage
    exit 0
    
} elseif {[llength $argv] >= 2 && [lsearch -exact $argv {--run}] == 1} {
    # argv == `path --run ...` -- Modify for run to see `path ...`
    mkdoc::run {*}[lreplace $argv 1 1]

} elseif {[llength $argv] == 2} {
    if {[regexp {^-.} [lindex $argv 1]]} {
	puts stderr "Error: wrong outfile name [lindex $argv 1]"
	exit 1
    }

    mkdoc::mkdoc {*}$argv

} elseif {[llength $argv] > 2} {
    # Check for `--css` and replace with the internal `-css`
    set csspos [lsearch -exact $argv --css]
    if {$csspos >= 0} {
	set argv [lreplace $argv $csspos $csspos -css]
    }
    
    mkdoc::mkdoc {*}$argv
}

exit
