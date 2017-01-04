# -*- tcl -*- \
# @@ Meta Begin
# Application dtplite 1.2
# Meta platform     tcl
# Meta summary      Lightweight DocTools Processor
# Meta description  This application is a simple processor
# Meta description  for documents written in the doctools
# Meta description  markup language. It covers the most
# Meta description  common use cases, but is not as
# Meta description  configurable as its big brother dtp.
# Meta category     Processing doctools documents
# Meta subject      doctools doctoc docidx
# Meta require      {doctools 1}
# Meta require      {doctools::idx 1}
# Meta require      {doctools::toc 1}
# Meta require      fileutil
# Meta require      textutil::repeat
# Meta author       Andreas Kupries
# Meta license      BSD
# @@ Meta End

package provide dtplite 1.3

# dtp lite - Lightweight DocTools Processor
# ======== = ==============================
#
# Use cases
# ---------
#
# (1)	Validation of a single manpage, i.e. checking that it is valid
#	doctools format.
#
# (1a)	Getting a preliminary version of the formatted output, for
#	display in a browser, nroff, etc., proofreading the
#	formatting.
#
# (2)	Generate documentation for a single package, i.e. all the
#	manpages, plus index and table of contents.
#
# (3)	Generation of unified documentation for several
#	packages. Especially unified keyword index and table of
#	contents. This may additionally generate per-package TOCs
#	as well (Per-package indices don't make sense IMHO).
#
# Command syntax
# --------------
#
# Ad 1)	dtplite -o output format file
#
#	The option -o specifies where to write the output to. Using
#	the string "-" as name of the output file causes the tool to
#	write the generated data to stdout. If $output is a directory
#	then a file named [[file rootname $file].$format] is written
#	to the directory.

# Ad 1a)	dtplite validate file
#
#	The "validate" format does not generate output at all, only
#	syntax checking is performed.
#
# Ad 2)	dtplite -o output format directory
#
#	I.e. we distinguish (2) from (1) by the type of the input,
#	file, or directory. In this situation output has to be a
#	directory. Use the path "." to place the results into the
#	current directory.
#
#	We locate _all_ files under directory, i.e. all subdirectories
#	are scanned as well. We replicate the found directory
#	structure in the output (See example below). The index and
#	table of contents are written to the toplevel directory in the
#	output. The names are hardwired to "toc.$format" and
#	"index.$format".
#
# Ad 3)	dtplite -merge -o output format directory
#
#	This can be treated as special case of (2). The -merge option
#	tells it that the output is nested one level deeper, to keep a
#	global toc and index in the toplevel and to merge the package
#	toc and index into them.
#
#	This way the global documents are built up incrementally. This
#	can help us in a future extended installer as well!, extending
#	a global documentation tree of all installed packages.
#
# Additional features.
#
# *	As described above the format name is used as the extension
#	for the generated files. Does it make sense to introduce an
#	option with which we can overide this, or should we simply
#	extect that a calling script does a proper renaming of all the
#	files ?  ... The option is better. In HTML output we have
#	links between the files, and renaming from the outside just
#	breaks the links. This option is '-ext'. It is ignored if the
#	output is a single file (fully specified via -o), or stdout.
#
#	-ext extension
#
# *	Most of the formats don't need much/none of customizability.
#	I.e. text, nroff, wiki, tmml, ...  For HTML however some
#	degree of customizability is required for good output.  What
#	should we given to the user ?
#
#	- Allow setting of a stylesheet.
#	- Allow integration of custom body header and footer html.
#	- Allow additional links for the navigation bar.
#	- Force module name, for when the directory name is wrong.
#	- Allow raw output, aka "embedded HTML", no head/body, just the body itself
#
#	Note: The tool generates standard navigation bars to link the
#	all tocs, indices, and pages together.
#
#	-style file
#	-header file
#	-footer file
#	-module name
#	-nav label url
#	-prenav label url
#	-postnav label url
#	-raw
#
# *	The application may mis-detect files as doctools input.
#	And we cannot always mark them as non-doctools because
#	they may be such. Test cases, for example. To exclude
#	these we have the option '-exclude' taking a glob pattern.
#	Multiple uses of the option accumulate.
#
#	-exclude glob
#
# *	For tcllib itself we have external tools generating a nicer
#	TOC. Use option -toc to specify the doctoc file to use
#	_instead_ of generating our own. And using option -post+toc
#	and -pre+toc to _add_ more special toc's to the main
#	navbar. These latter mix with the -pre- and -postnav options.
#
#	-toc            path|text
#	-post+toc label path|text
#	-pre+toc label path|text
#
# That should be enough to allow the creation of good looking formatted
# documentation without getting overly complex in both implementation
# and use.

package require doctools      1.4.11 ; # 'image' support, -ibase support
package require doctools::idx 1.0.4 ;
package require doctools::toc 1.1.3 ;
package require fileutil
package require textutil::repeat

# ### ### ### ######### ######### #########
## Internal data and status

namespace eval ::dtplite {
    variable print ::puts

    # Path to where the output goes to. This is a file in case of mode
    # 'file', irrelevant for mode 'file.stdout', and the directory for
    # all the generated files for the two directory modes. Specified
    # through the mandatory option '-o'.

    variable  output ""

    # Path to where the documents to convert come from. This is a
    # single file in the case of the two file modes, and a directory
    # for the directory modes. In the later case all files under that
    # directory are significant, including links, if identifiable as
    # in doctools format (fileutil::fileType). Specified through the
    # last argument on the command line. The relative path of a file
    # under 'input' also becomes its relative path under 'output'.

    variable  input  ""

    # The extension to use for the generated files. Ignored by the
    # file modes, as for them they either don't generate a file, or
    # know its full name already, i.e. including any wanted
    # extension. Set via option '-ext'. Defaults to the format name if
    # '-ext' was not used.

    variable  ext    ""

    # Optional. HTML specific, requires engine parameter 'meta'. Path
    # to a stylesheet file to use in the output. The file modes link
    # to it using the original location, but the directory modes copy
    # the file into the 'output' and link it there (to make the
    # 'output' more selfcontained). Initially set via option '-style'.

    variable  style  ""

    # Optional. Path to a file. Contents of the file are assigned to
    # engine parameter 'header', if present. If navigation buttons
    # were defined their HTML will be appended to the file contents
    # before doing the assignment. A specification is ignored if the
    # engine does not support the parameter 'header'. Set via option
    # '-header'.

    variable  header ""

    # Like header, but for the document footer, and no navigation bar
    # insert. Set via option '-footer', requires engine parameter
    # 'footer'.

    variable  footer ""

    # raw flag. When set "embedded HTML" is generated. Or whatever
    # fits the definition for the active format.

    variable raw off
    
    # List of buttons/links for a navigation bar. No navigation bar is
    # created if this is empty. HTML specific, requires engine
    # parameter 'header' (The navigation bar is merged with the
    # 'header' data, see above). Each element of the list is a
    # 2-element list, containing the button label and url, in this
    # order. Initial data comes from the command line, via options
    # '-nav', '-prenav', and '-postnav'. The commands 'Navbutton(Push|Pop)'
    # then allow the programmatic addition and removal of buttons at
    # the left (stack like, top at end index). This is used for the
    # insertion of links to TOC and Index into each document, if
    # applicable.

    variable  nav     {}
    variable  prenav  {}
    variable  postnav {}

    # The name of the format to convert the doctools documents
    # into. Set via the next-to-last argument on the command
    # line. Used as extension for the generated files as well by the
    # directory modes, and if not overridden via '-ext'. See 'ext'
    # above.

    variable  format ""

    # Boolean flag. Set by the option '-merge'. Ignored when a file
    # mode is detected, but for a directory it determines the
    # difference between the two directory modes, i.e. plain
    # generation, or incremental merging of many inputs into one
    # output.

    variable  merge  0

    # Boolean flag. Automatically set by code distinguishing between
    # file and directory modes. Set for a the file modes, unset for
    # the directory modes.

    variable  single 1

    # Boolean flag. Automatically set by the code processing the '-o'
    # option. Set if output is '-', unset otherwise. Ignored for the
    # directory modes. Distinguished between the two file modes, i.e.
    # writing to a file (unset), or stdout (set).

    variable  stdout 0

    # Name of the found processing mode. Derived from the values of
    # the three boolean flags (merge, single, stdout). This value is
    # used during the dispatch to the command implementing the mode,
    # after processing the command line.
    #
    # Possible/Legal values:	Meaning
    # ---------------------	-------
    # File			File mode. Write result to a file.
    # File.Stdout		File mode. Write result to stdout.
    # Directory			Directory mode. Plain processing of one set.
    # Directory.Merge		Directory mode. Merging of multiple sets into
    #				one output.
    # ---------------------	-------

    variable  mode   ""

    # Name of the module currently processed. Derived from the 'input'
    # (last element of this path, without extension).

    variable  module ""

    # Crossreference data. Extracted from the processed documents, a
    # rearrangement and filtration of the full meta data (See 'meta'
    # below). Relevant only to the directory modes. I.e. the file
    # modes don't bother with its extraction and use.

    variable  xref
    array set xref   {}

    # Index data. Mapping from keyword (label) to the name of its
    # anchor in the index output. Requires support for the engine
    # parameter 'kwid' in the index engine.

    variable  kwid
    array set kwid {}

    # Cache. This array maps from the path of an input file/document
    # (relative to 'input'), to the paths of the file to generate
    # (relative to 'output', including extension and such). In other
    # words we derive the output paths from the inputs only once and
    # then simply get them here.

    variable  out
    array set out  {}

    # Meta data cache. Stores the meta data extracted from the input
    # files/documents, per input. The meta data is a dictionary and
    # processed several ways to get: Crossreferences (See 'xref'
    # above), Table Of Contents, and Keyword Index. The last two are
    # not cached, but ephemeral.

    variable  meta
    array set meta {}

    # Cache of input documents. When we read an input file we store
    # its contents here, keyed by path (relative to 'input') so that
    # we don't have to go to the disk when we we need the file again.
    # The directory modes need each input twice, for metadata
    # extraction, and the actual conversion.

    variable  data
    array set data {}

    # Database of image files for use by dt_imap.

    variable  imap
    array set imap {}

    # Database of exclusion patterns. Files matching these are not
    # manpages. For example, test files for doctools itself may fall
    # under this.

    variable excl {}

    # Path of a user specified table of contents (doctoc format).

    variable utoc {}

    # List of path|text of additional TOCs to put into the navigation
    # bar. Label and ordering information is found in the pre- and
    # postnav lists. See above.

    variable mtoc {}
}

# ### ### ### ######### ######### #########
## External data and status
#
## Only the directory merge mode uses external data, saving the
## internal representations of current toc, index. and xref
## information for use by future mergers. It uses three files,
## described below. The files are created if they don't exist.
## Remove them when the merging is complete.
#
## .toc
## Contains the current full toc in form of a dictionary.
#  Keys are division labels, values the lists of toc items.
#
## .idx
## Contains the current full index, plus keyword id map.  Is a list of
#  three elements, index, start id for new kwid entries, and the
#  keyword id map (kwid). Index and Kwid are both dictionaries, keyed
#  by keywords. Index value is a list of 2-tuples containing symbolic
#  file plus label, in this order. Kwid value is the id of the anchor
#  for that keyword in the index.
#
## .xrf
## Contains the current cross reference database, a dictionary. Keys
#  are tags the formatter can search for (keywords, keywords with
#  prefixes, keywords with suffices), values a list containing either
#  the file to refer to to, or both file and an anchor in that
#  file. The latter is for references into the index.

proc ::dtplite::Init {} {
    variable  data
    variable  excl {}
    variable  ext    ""
    variable  footer ""
    variable  format ""
    variable  header ""
    variable  imap
    variable  input  ""
    variable  kwid
    variable  merge  0
    variable  meta
    variable  mode   ""
    variable  module ""
    variable  mtoc {}
    variable  nav     {}
    variable  out
    variable  output ""
    variable  postnav {}
    variable  prenav  {}
    variable  single 1
    variable  stdout 0
    variable  style  ""
    variable  utoc {}
    variable  xref
    variable  xrefl

    array unset data     *
    array unset imap     *
    array unset kwid     *
    array unset meta     *
    array unset out      *
    array unset xref     *
    catch { unset xrefl }

    return
}

# ### ### ### ######### ######### #########
## Option processing.
## Validate command line.
## Full command line syntax.
##
# dtplite	-o outputpath	\
#		?-merge?	\
#		?-raw?	\
#		?-ext ext?	\
#		?-style file?	\
#		?-header file?	\
#		?-footer file?	\
#		?-module name?	\
#		?-nav label url?... \
#		?-prenav label url?... \
#		?-postnav label url?... \
#		?-exclude glob?... \
#		?-toc path|text? \
#		?-post+toc label path|text? \
#		?-pre+toc label path|text? \
#		format inputpath
##

proc ::dtplite::ProcessCmdline {argv} {
    variable output ; variable style  ; variable stdout
    variable format ; variable header ; variable single
    variable input  ; variable footer ; variable mode
    variable ext    ; variable nav    ; variable merge
    variable module ; variable excl   ; variable utoc
    variable prenav ; variable postnav ; variable mtoc
    variable raw

    # Process the options, perform basic validation.

    set fixup {}
    set muser false

    while {[llength $argv]} {
	set opt [lindex $argv 0]
	if {![string match "-*" $opt]} break

	if {[string equal $opt "-o"]} {
	    if {[llength $argv] < 2} Usage
	    set output [lindex $argv 1]
	    set argv   [lrange $argv 2 end]
	} elseif {[string equal $opt "-merge"]} {
	    set merge 1
	    set argv [lrange $argv 1 end]
	} elseif {[string equal $opt "-raw"]} {
	    set raw on
	    set argv [lrange $argv 1 end]
	} elseif {[string equal $opt "-ext"]} {
	    if {[llength $argv] < 2} Usage
	    set ext  [lindex $argv 1]
	    set argv [lrange $argv 2 end]
	} elseif {[string equal $opt "-toc"]} {
	    if {[llength $argv] < 2} Usage
	    set utoc [lindex $argv 1]
	    set argv [lrange $argv 2 end]
	} elseif {[string equal $opt "-post+toc"]} {
	    if {[llength $argv] < 3} Usage
	    # Place toc data separate from the nav data, and identify
	    # by counter (list length). The nav data gets the file
	    # name (see Do.Directory* commands, marker (+TOC)). As
	    # relative paths they will be transformed during navbar
	    # generation to link properly.
	    set n [llength $mtoc]
	    set fname toc$n.$ext
	    if {$ext == {}} {
		lappend fixup postnav [llength $postnav]
	    }
	    lappend postnav [list [lindex $argv 1] $fname]
	    lappend mtoc    [lindex $argv 2]
	    set argv        [lrange $argv 3 end]
	} elseif {[string equal $opt "-pre+toc"]} {
	    if {[llength $argv] < 3} Usage
	    # Place toc data separate from the nav data, and identify
	    # by counter (list length). The nav data gets the file
	    # name (see Do.Directory* commands, marker (+TOC)). As
	    # relative paths they will be transformed during navbar
	    # generation to link properly.
	    set n [llength $mtoc]
	    set fname toc$n.$ext
	    if {$ext == {}} {
		lappend fixup prenav [llength $prenav]
	    }
	    lappend prenav [list [lindex $argv 1] $fname]
	    lappend mtoc   [lindex $argv 2]
	    set argv       [lrange $argv 3 end]
	} elseif {[string equal $opt "-exclude"]} {
	    if {[llength $argv] < 2} Usage
	    lappend excl [lindex $argv 1]
	    set argv [lrange $argv 2 end]
	} elseif {[string equal $opt "-style"]} {
	    if {[llength $argv] < 2} Usage
	    set style [lindex $argv 1]
	    set argv  [lrange $argv 2 end]
	} elseif {[string equal $opt "-header"]} {
	    if {[llength $argv] < 2} Usage
	    set header [lindex $argv 1]
	    set argv   [lrange $argv 2 end]
	} elseif {[string equal $opt "-footer"]} {
	    if {[llength $argv] < 2} Usage
	    set footer [lindex $argv 1]
	    set argv   [lrange $argv 2 end]
	} elseif {[string equal $opt "-module"]} {
	    if {[llength $argv] < 2} Usage
	    set module [lindex $argv 1]
	    set argv   [lrange $argv 2 end]
	    set muser true
	} elseif {[string equal $opt "-nav"]} {
	    if {[llength $argv] < 3} Usage
	    lappend prenav [lrange $argv 1 2]
	    set argv       [lrange $argv 3 end]
	} elseif {[string equal $opt "-postnav"]} {
	    if {[llength $argv] < 3} Usage
	    lappend postnav [lrange $argv 1 2]
	    set argv        [lrange $argv 3 end]
	} elseif {[string equal $opt "-prenav"]} {
	    if {[llength $argv] < 3} Usage
	    lappend prenav [lrange $argv 1 2]
	    set argv       [lrange $argv 3 end]
	} else {
	    Usage
	}
    }

    # Additional validation, and extraction of the non-option
    # arguments.

    if {[llength $argv] != 2} Usage

    set format [lindex $argv 0]
    set input  [lindex $argv 1]

    if {[string equal $format validate]} {
	set format null
    }

    # Final validation across the whole configuration.

    if {[string equal $format ""]} {
	ArgError "Illegal empty format specification"

    } else {
	# Early check: Is the chosen format ok ? For this we have
	# create and configure a doctools object.

	doctools::new dt
	if {[catch {dt configure -format $format}]} {
	    ArgError "Unknown format \"$format\""
	}
	dt configure -deprecated 1

	# Check style, header, and footer options, if present.

	CheckInsert   header {Header file}
	CheckInsert   footer {Footer file}
	CheckPresence raw    {Raw flag}

	if {[llength $nav] && ![in [dt parameters] header]} {
	    ArgError "-nav not supported by format \"$format\""
	}
	if {![string equal $style ""]} {
	    if {![in [dt parameters] meta]} {
		ArgError "-style not supported by format \"$format\""
	    } elseif {![file exists $style]} {
		ArgError "Unable to find style file \"$style\""
	    }
	}
    }

    # Set up an extension based on the format, if no extension was
    # specified.  Also compute the name of the module, based on the
    # input. [SF Tcllib Bug 1111364]. Has to come before the line
    # marked with a [*], or a filename without extension is created.

    if {[string equal $ext ""]} {
	set ext $format
	foreach {v i} $fixup {
	    upvar 0 $v navlist
	    set item [lindex $navlist $i]
	    set item [lreplace $item 1 1 [lindex $item 1]$ext]
	    set navlist [lreplace $navlist $i $i $item]
	}
    }

    CheckInput $input {Input path}
    if {[file isfile $input]} {
	# Input file. Merge mode is not possible. Output can be file
	# or directory, or "-" for stdout. The output may exist, but
	# does not have to. The directory it is in however does have
	# to exist, and has to be writable (if the output does not
	# exist yet). An existing output has to be writable.

	if {$merge} {
	    ArgError "-merge illegal when processing a single input file."
	}
	if {![string equal $output "-"]} {
	    CheckTheOutput

	    # If the output is an existing directory then we have to
	    # ensure that the actual output is a file in that
	    # directory, and we derive its name from the name of the
	    # input file (and -ext, if present).

	    if {[file isdirectory $output]} {
		# [*] [SF Tcllib Bug 1111364]
		set output [file join $output [file tail [Output $input]]]
	    }
	} else {
	    set stdout 1
	}
    } else {
	# Input directory. Merge mode is possible. Output has to be a
	# directory. The output may exist, but does not have to. The
	# directory it is in however does have to exist. An existing
	# output has to be writable.

	set single 0
	CheckTheOutput 1
    }

    # Determine the operation mode from the flags

    if {$single} {
	if {$stdout} {
	    set mode File.Stdout
	} else {
	    set mode File
	}
    } elseif {$merge} {
	set mode Directory.Merge
    } else {
	set mode Directory
    }

    # Derive a module name iff user has not chosen any.
    if {!$muser} {
	set module [file rootname [file tail [file normalize $input]]]
    }
    return
}

# ### ### ### ######### ######### #########
## Option processing.
## Helpers: Generation of error messages.
## I.  General usage/help message.
## II. Specific messages.
#
# Both write their messages to stderr and then
# exit the application with status 1.
##

proc ::dtplite::Usage {} {
    global argv0
    Print stderr "$argv0 wrong#args, expected:\
	    -o outputpath ?-merge? ?-raw? ?-ext ext?\
	    ?-style file? ?-header file?\
	    ?-footer file? ?-module string? ?-nav label url?...\
	    format inputpath"
    return -code error -errorcode {DTPLITE STOP} {}
}

proc ::dtplite::ArgError {text} {
    global argv0
    Print stderr "$argv0: $text"
    return -code error -errorcode {DTPLITE STOP} {}
}

proc ::dtplite::Print {args} {
    variable print
    set cmd [concat $print $args]
    return [uplevel 1 $cmd]
}

proc in {list item} {
    expr {([lsearch -exact $list $item] >= 0)}
}

# ### ### ### ######### ######### #########
## Helper commands. File paths.
## Conversion of relative paths
## to absolute ones for input
## and output. Derivation of
## output file name from input.

proc ::dtplite::Pick {f} {
    variable input
    return [file join $input $f]
}

proc ::dtplite::Output {f} {
    variable ext
    return [file rootname $f].$ext
}

proc ::dtplite::At {f} {
    variable output
    set of     [file normalize [file join $output $f]]
    file mkdir [file dirname $of]
    return $of
}

# ### ### ### ######### ######### #########
## Check existence and permissions of an input/output file or
## directory.

proc ::dtplite::CheckInput {f label} {
    if {![file exists $f]} {
	ArgError "Unable to find $label \"$f\""
    } elseif {![file readable $f]} {
	ArgError "$label \"$f\" not readable (permission denied)"
    }
    return
}

proc ::dtplite::CheckTheOutput {{needdir 0}} {
    variable output
    variable format

    if {[string equal $format null]} {
	# The format does not generate output, so not specifying an
	# output file is ok for that case.
	return
    }

    if {[string equal $output ""]} {
	ArgError "No output path specified"
    }

    set base [file dirname $output]
    if {[string equal $base ""]} {set base [pwd]}

    if {![file exists $output]} {
	if {![file exists $base]} {
	    ArgError "Output base path \"$base\" not found"
	}
	if {![file writable $base]} {
	    ArgError "Output base path \"$base\" not writable (permission denied)"
	}
    } else {
	if {![file writable $output]} {
	    ArgError "Output path \"$output\" not writable (permission denied)"
	}
	if {$needdir && ![file isdirectory $output]} {
	    ArgError "Output path \"$output\" not a directory"
	}
    }
    return
}

proc ::dtplite::CheckInsert {option label} {
    variable format
    variable $option
    upvar 0  $option opt

    if {![string equal $opt ""]} {
	if {![in [dt parameters] $option]} {
	    ArgError "-$option not supported by format \"$format\""
	}
	CheckInput $opt $label
	set opt [Get $opt]
    }
    return
}

proc ::dtplite::CheckPresence {option label} {
    variable format
    variable $option
    upvar 0  $option opt

    if {$opt} {
	if {![in [dt parameters] $option]} {
	    ArgError "-$option not supported by format \"$format\""
	}
    }
    return
}

# ### ### ### ######### ######### #########
## Helper commands. File reading and writing.

proc ::dtplite::Get {f} {
    variable data
    if {[info exists data($f)]} {return $data($f)}
    return [set data($f) [fileutil::cat $f]]
}

proc ::dtplite::Write {f data} {
    # An empty filename is acceptable, the format will be 'null'
    if {[string equal $f ""]} return
    fileutil::writeFile $f $data
    return
}

# ### ### ### ######### ######### #########
## Dump accumulated warnings.

proc ::dtplite::Warnings {} {
    set warnings [dt warnings]
    if {[llength $warnings] > 0} {
	Print stderr [join $warnings \n]
    }
    return
}

# ### ### ### ######### ######### #########
## Configuation phase, validate command line.

# ### ### ### ######### ######### #########
## We can assume that we have from here on a command 'dt', which is a
## doctools object command, and already configured for the format to
## generate.
# ### ### ### ######### ######### #########

# ### ### ### ######### ######### #########
## Commands implementing the main functionality.

proc ::dtplite::Do.File {} {
    # Process a single input file, write the result to a single outut file.

    variable input
    variable output

    SinglePrep
    Write $output [dt format [Get $input]]
    Warnings
    return
}

proc ::dtplite::Do.File.Stdout {} {
    # Process a single input file, write the result to stdout.

    variable input

    SinglePrep
    puts  stdout [dt format [Get $input]]
    close stdout
    Warnings
    return
}

proc ::dtplite::Do.Directory {} {
    # Process a directory of input files, through all subdirectories.
    # Generate index and toc, but no merging with an existing index
    # and toc. I.e. any existing index and toc files are overwritten.

    variable input
    variable out
    variable module
    variable meta
    variable format
    variable utoc
    variable mtoc

    # Phase 0. Find the documents to convert.
    # Phase I. Collect meta data, and compute the map from input to
    # ........ output files. This is also the map for the symbolic
    # ........ references. We extend an existing map (required for use
    # ........ in merge op.
    # Phase II. Build index and toc information from the meta data.
    # Phase III. Convert each file, using index, toc and meta
    # .......... information.

    MapImages
    set files [LocateManpages $input]
    if {![llength $files]} {
	ArgError "Module \"$module\" has no files to process."
    }

    MetadataGet $files
    StyleMakeLocal

    # Attention, ordering! Ensure that 'kwid' is initialized before
    # testing it with 'HaveKeywords' everywhere we configure the links
    # showns in the navigation bar.

    set idx [IdxGenerate $module [IdxGet]]

    if {$utoc ne {}} {
	if {[file exists $utoc]} { set utoc [Get $utoc] }
	TocWrite toc index $utoc
    } else {
	TocWrite toc index [TocGenerate [TocGet $module toc]]
    }
    # (+TOC)
    set n 0
    foreach item $mtoc {
	if {[file exists $item]} { set item [Get $item] }
	TocWrite toc$n index $item
	incr n
    }
    IdxWrite index toc $idx

    dt configure -module $module
    XrefGet
    XrefSetup   dt
    FooterSetup dt
    MapSetup    dt

    foreach f [lsort -dict $files] {
	Print stdout \t$f

	set o $out($f)
	dt configure -file [At $o] -ibase $input/$f

        if {[HaveKeywords]} {
            NavbuttonPush {Keyword Index} [Output index] $o
        }
	NavbuttonPush {Table Of Contents} [Output toc]   $o
	HeaderSetup dt $o
	NavbuttonPop
        if {[HaveKeywords]} {
            NavbuttonPop
        }
	StyleSetup dt $o

	if {[string equal $format null]} {
	    dt format [Get [Pick $f]]
	} else {
	    Write [At $o] [dt format [Get [Pick $f]]]
	}
	Warnings
    }
    return
}

proc ::dtplite::Do.Directory.Merge {} {
    # See Do.Directory, but merge the TOC/Index information from this
    # set of input files into an existing TOC/Index.

    variable input
    variable out
    variable module
    variable meta
    variable output
    variable format
    variable utoc
    variable mtoc

    # Phase 0. Find the documents to process.
    # Phase I. Collect meta data, and compute the map from input to
    # ........ output files. This is also the map for the symbolic
    # ........ references. We extend an existing map (required for use
    # ........ in merge op.
    # Phase II. Build module local toc from the meta data, insert it
    # ......... into the main toc as well, and generate a global
    # ......... index.
    # Phase III. Process each file, using cross references, and links
    # .......... to boths tocs and the index.

    MapImages
    set files [LocateManpages $input]
    if {![llength $files]} {
	ArgError "Module \"$module\" has no files to process."
    }

    MetadataGet $files $module
    StyleMakeLocal     $module

    # Attention, ordering! Ensure that 'kwid' is initialized before
    # testing it with 'HaveKeywords' everywhere we configure the links
    # showns in the navigation bar.

    set idx [IdxGenerate {} [IdxGetSaved index]]

    set localtoc [TocGet $module $module/toc]
    TocWrite $module/toc index [TocGenerate $localtoc] [TocMap $localtoc]
    if {$utoc ne {}} {
	if {[file exists $utoc]} { set utoc [Get $utoc] }
	TocWrite toc index $utoc
    } else {
	TocWrite toc index [TocGenerate [TocMergeSaved $localtoc]]
    }
    # (+TOC)
    set n 0
    foreach item $mtoc {
	if {[file exists $item]} { set item [Get $item] }
	TocWrite toc$n index $item
	incr n
    }
    IdxWrite index toc $idx

    dt configure -module $module
    XrefGetSaved
    XrefSetup   dt
    FooterSetup dt
    MapSetup    dt

    foreach f [lsort -dict $files] {
	Print stdout \t$f

	set o $out($f)
	dt configure -file [At $o] -ibase $input/$f
        if {[HaveKeywords]} {
            NavbuttonPush {Keyword Index} [Output index] $o
        }
	NavbuttonPush {Table Of Contents}      [Output $module/toc] $o
	NavbuttonPush {Main Table Of Contents} [Output toc]         $o
	HeaderSetup dt $o
	NavbuttonPop
	NavbuttonPop
        if {[HaveKeywords]} {
            NavbuttonPop
        }
	StyleSetup dt $o

	if {[string equal $format null]} {
	    dt format [Get [Pick $f]]
	} else {
	    Write [At $o] [dt format [Get [Pick $f]]]
	}
	Warnings
    }
    return
}

# ### ### ### ######### ######### #########
## Helper commands. Preparations shared between the two file modes.

proc ::dtplite::SinglePrep {} {
    variable input
    variable module

    MapImages
    StyleSetup  dt
    HeaderSetup dt {}
    FooterSetup dt
    MapSetup    dt

    dt configure -module $module -file $input
    return
}

# ### ### ### ######### ######### #########
## Get the base meta data out of the listed documents.

proc ::dtplite::MetadataGet {files {floc {}}} {
    # meta :: map (symbolicfile -> metadata)
    # metadata = dict (key -> value)
    # key      = set { desc, fid, file, keywords,
    #                  module, section, see_also,
    #                  shortdesc, title, version }
    # desc      :: string 'document title'
    # fid       :: string           'file name, without path/extension'
    # file      :: string           'file name, without path'
    # keywords  :: list (string...) 'key phrases'
    # module    :: string           'module the file is in'
    # section   :: string           'manpage section'
    # see_also  :: list (string...) 'related files'
    # shortdesc :: string           'module description'
    # title     :: string           'manpage file name intended'
    # version   :: string           'file/package version'
    variable meta
    variable input
    variable out

    doctools::new meta -format list -deprecated 1
    foreach f $files {
	meta configure -file $input/$f
	set o [Output [file join $floc files $f]]
	set out($f)  $o
	set meta($o) [lindex [string trim [meta format [Get [Pick $f]]]] 1]
    }
    meta destroy
    return
}

# ### ### ### ######### ######### #########
## Handling Tables of Contents:
## - Get them out of the base meta data.
## - As above, and merging them with global toc.
## - Conversion of internals into doctoc.
## - Processing doctoc into final formatting.

proc ::dtplite::TocGet {desc {f toc}} {
    # Generate the intermediate form of a TOC for the current document
    # set. This generates a single division.

    # Get toc out of the meta data.
    variable meta
    set res {}
    foreach {k item} [array get meta] {
	lappend res [TocItem $k $item]
    }
    return [list $desc [list $f $res]]
}

proc ::dtplite::TocMap {toc {base {}}} {
    if {$base == {}} {
	set base  [lindex [lindex $toc 1] 0]
    }
    set items [lindex [lindex $toc 1] 1]

    set res {}
    foreach i $items {
	foreach {f label desc} $i break
	lappend res $f [fileutil::relativeUrl $base $f]
    }
    return $res
}

proc ::dtplite::TocItem {f meta} {
    array set md $meta
    set desc    $md(desc)
    set label   $md(title)
    return [list $f $label $desc]
}

proc ::dtplite::TocMergeSaved {sub} {
    # sub is the TOC of the current doc set (local toc). Merge this
    # into the main toc (as read from the saved global state), and
    # return the resulting internal rep for further processing.

    set fqn [At .toc]
    if {[file exists $fqn]} {
	array set _ [Get $fqn]
    }
    array set _ $sub
    set thetoc [array get _]

    # Save extended toc for next merge.
    Write $fqn $thetoc

    return $thetoc
}

proc ::dtplite::TocGenerate {data} {
    # Handling single and multiple divisions.
    # single div => div is full toc
    # multi div  => place divs into the toc in alpha order.
    #
    # Sort toc (each division) by label (index 1).
    # Write as doctoc.

    array set toc $data

    TagsBegin
    if {[array size toc] < 2} {
	# Empty, or single division. The division is the TOC, toplevel.

	unset toc
	set desc [lindex $data 0]
	set data [lindex [lindex $data 1] 1]
	TocAlign mxf mxl $data

	Tag+ toc_begin [list {Table Of Contents} $desc]
	foreach item [lsort -dict -index 1 $data] {
	    foreach {symfile label desc} $item break
	    Tag+ item \
		    [FmtR mxf $symfile] \
		    [FmtR mxl $label] \
		    [list $desc]
	}
    } else {
	Tag+ toc_begin [list {Table Of Contents} Modules]
	foreach desc [lsort -dict [array names toc]] {
	    foreach {ref div} $toc($desc) break
	    TocAlign mxf mxl $div

	    Tag+ division_start [list $desc [Output $ref]]
	    foreach item [lsort -dict -index 1 $div] {
		foreach {symfile label desc} $item break
		Tag+ item \
			[FmtR mxf $symfile] \
			[FmtR mxl $label] \
			[list $desc]
	    }
	    Tag+ division_end
	}
    }

    Tag+ toc_end

    #puts ____________________\n[join $lines \n]\n_________________________
    return [join $lines \n]\n
}

proc ::dtplite::TocWrite {ftoc findex text {map {}}} {
    variable format

    if {[string equal $format null]} return
    Write [At .tocdoc] $text

    set ft [Output $ftoc]

    doctools::toc::new toc -format $format -file $ft
    if {[HaveKeywords]} {
        NavbuttonPush {Keyword Index} [Output $findex] $ftoc
    }
    HeaderSetup toc $ft
    if {[HaveKeywords]} {
        NavbuttonPop
    }
    FooterSetup  toc
    StyleSetup   toc $ftoc

    foreach {k v} $map {toc map $k $v}

    Write [At $ft] [toc format $text]
    toc destroy
    return
}

proc ::dtplite::TocAlign {fv lv div} {
    upvar 1 $fv mxf $lv mxl
    set mxf 0
    set mxl 0
    foreach item $div {
	foreach {symfile label desc} $item break
	Max mxf $symfile
	Max mxl $label
    }
    return
}

# ### ### ### ######### ######### #########
## Handling Keyword Indices:
## - Get them out of the base meta data.
## - As above, and merging them with global index.
## - Conversion of internals into docidx.
## - Processing docidx into final formatting.

proc ::dtplite::IdxGet {{f index}} {
    # Get index out of the meta data.
    array set keys {}
    array set kdup {}
    return [lindex [IdxExtractMeta] 1]
}

proc ::dtplite::IdxGetSaved {{f index}} {
    # Get index out of the meta data, merge into global state.
    variable meta
    variable kwid

    array set keys {}
    array set kwid {}
    array set kdup {}
    set start 0

    set fqn [At .idx]
    if {[file exists $fqn]} {
	foreach {kw kd start ki} [Get $fqn] break
	array set keys $kw
	array set kwid $ki
	array set kdup $kd
    }

    foreach {start theindex} [IdxExtractMeta $start] break

    # Save extended index for next merge.
    Write $fqn [list $theindex [array get kdup] $start [array get kwid]]

    return $theindex
}

proc ::dtplite::IdxExtractMeta {{start 0}} {
    # Get index out of the meta data.
    variable meta
    variable kwid

    upvar keys keys kdup kdup
    foreach {k item} [array get meta] {
	foreach {symfile keywords label} [IdxItem $k $item] break
	# Store inverted file - keyword relationship
	# Kdup is used to prevent entering of duplicates.
	# Checks full (keyword file label).
	foreach k $keywords {
	    set kx [list $k $symfile $label]
	    if {![info exists kdup($kx)]} {
		lappend keys($k) [list $symfile $label]
		set kdup($kx) .
	    }
	    if {[info exist kwid($k)]} continue
	    set kwid($k) key$start
	    incr start
	}
    }
    return [list $start [array get keys]]
}

proc ::dtplite::IdxItem {f meta} {
    array set md $meta
    set keywords $md(keywords)
    set title    $md(title)
    return [list $f $keywords $title]
}

proc ::dtplite::IdxGenerate {desc data} {
    # Sort by keyword label.
    # Write as docidx.

    array set keys $data

    TagsBegin
    Tag+ index_begin [list {Keyword Index} $desc]

    foreach k [lsort -dict [array names keys]] {
	IdxAlign mxf $keys($k)

	Tag+ key [list $k]
	foreach v [lsort -dict -index 1 $keys($k)] {
	    foreach {file label} $v break
	    Tag+ manpage [FmtR mxf $file] [list $label]
	}
    }

    Tag+ index_end
    #puts ____________________\n[join $lines \n]\n_________________________
    return [join $lines \n]\n
}

proc ::dtplite::IdxWrite {findex ftoc text} {
    variable format

    if {[string equal $format null]} return
    if {![HaveKeywords]} return

    Write [At .idxdoc] $text

    set fi [Output $findex]

    doctools::idx::new idx -format $format -file $fi

    NavbuttonPush {Table Of Contents} [Output $ftoc] $findex
    HeaderSetup   idx $findex
    NavbuttonPop
    FooterSetup   idx
    StyleSetup    idx $findex
    XrefSetupKwid idx

    Write [At $fi] [idx format $text]
    idx destroy
    return
}

proc ::dtplite::IdxAlign {v keys} {
    upvar 1 $v mxf
    set mxf 0
    foreach item $keys {
	foreach {symfile label} $item break
	Max mxf $symfile
    }
    return
}

# ### ### ### ######### ######### #########
## Detect presence of keywords.

proc ::dtplite::HaveKeywords {} {
    variable   kwid
    array size kwid
}

# ### ### ### ######### ######### #########
## Column sizing

proc ::dtplite::Max {v str} {
    upvar 1 $v max
    set l [string length [list $str]]
    if {$max < $l} {set max $l}
    return
}

proc ::dtplite::FmtR {v str} {
    upvar 1 $v max
    return [list $str][textutil::repeat::blank \
	    [expr {$max - [string length [list $str]]}]]
}

# ### ### ### ######### ######### #########
## Code generation.

proc ::dtplite::Tag {n args} {
    if {[llength $args]} {
	return "\[$n [join $args]\]"
    } else {
	return "\[$n\]"
    }
    #return \[[linsert $args 0 $n]\]
}

proc ::dtplite::Tag+ {n args} {
    upvar 1 lines lines
    lappend lines [eval [linsert $args 0 ::dtplite::Tag $n]]
    return
}

proc ::dtplite::TagsBegin {} {
    upvar 1 lines lines
    set lines {}
    return
}

# ### ### ### ######### ######### #########
## Collect all files for possible use as image

proc ::dtplite::MapImages {} {
    variable input
    variable output
    variable single
    variable stdout

    # Ignore images when writing results to a pipe.
    if {$stdout} return

    set out  [file normalize $output]
    set path [file normalize $input]
    set res  {}

    if {$single} {
	# output is file, image directory is sibling to it.
	set imgbase [file join [file dirname $output] image]
	# input to search is director the input file is in, and below
	set path    [file dirname $path]
    } else {
	# output is directory, image directory is inside.
	set imgbase [file join $out image]
    }

    set n [llength [file split $path]]

    foreach f [::fileutil::find $path] {
	MapImage \
	    [::fileutil::stripN $f $n] \
	    $f [file join $imgbase [file tail $f]]
    }
    return
}

proc ::dtplite::MapImage {path orig dest} {
    # A file a/b/x.y is stored under
    # a/b/x.y, b/x.y, and x.y

    variable imap
    set plist [file split $path]
    while {[llength $plist]} {
	set imap([join $plist /]) [list $orig $dest]
	set plist [lrange $plist 1 end]
    }
    return
}

proc ::dtplite::MapSetup {dt} {
    # imap :: map (symbolicfile -> list (originpath,destpath)))
    variable imap
    # Skip if no data available

    #puts MIS|[array size imap]|
    if {![array size imap]} return

    foreach sf [array names imap] {
	foreach {origin destination} $imap($sf) break
	$dt img $sf $origin $destination
    }
    return
}

# ### ### ### ######### ######### #########
## Find the documents to process.

proc ::dtplite::LocateManpages {path} {
    set path [file normalize $path]
    set n    [llength [file split $path]]
    set res  {}
    foreach f [::fileutil::find $path ::dtplite::IsDoctools] {
	lappend res [::fileutil::stripN $f $n]
    }
    return $res
}

proc ::dtplite::IsDoctools {f} {
    set res [expr {[in [::fileutil::fileType $f] doctools] && ![Excluded [file normalize $f]]}]
    #puts ...$f\t$res\t|[fileutil::fileType $f]|\texcluded=[Excluded [file normalize $f]]\tin.[pwd]
    return $res
}

proc ::dtplite::Excluded {f} {
    variable excl
    foreach p $excl {
	if {[string match $p $f]} {return 1}
    }
    return 0
}

# ### ### ### ######### ######### #########
## Handling a style sheet
## - Decoupling output from input location.
## - Generate HTML to insert into a generated document.

proc ::dtplite::StyleMakeLocal {{pfx {}}} {
    variable style
    if {[string equal $style ""]} return
    set base [file join $pfx [file tail $style]]

    # TODO input == output does what here ?

    file copy -force $style [At $base]
    set style $base
    return
}

proc ::dtplite::StyleSetup {o {f {}}} {
    variable style
    if {[string equal $style ""]}   return
    if {![in [$o parameters] meta]} return

    if {![string equal $f ""]} {
	set dst [fileutil::relativeUrl $f $style]
    } else {
	set dst $style
    }
    set value "<link\
	    rel=\"stylesheet\"\
	    href=\"$dst\"\
	    type=\"text/css\">"

    $o setparam meta $value
    return
}

# ### ### ### ######### ######### #########
## Handling the cross references
## - Getting them out of the base meta data.
## - ditto, plus merging with saved xref information.
## - Insertion into processor, cached list.
## - Setting up the keyword-2-anchor map.

proc ::dtplite::XrefGet {} {
    variable meta
    variable xref
    variable kwid

    array set keys {}
    foreach {symfile item} [array get meta] {
	array set md $item
	# Cross-references ... File based, see-also

	set t  $md(title)
	set ts ${t}($md(section))
	set td $md(desc)

	set xref(sa,$t)  [set _ [list $symfile]]
	set xref(sa,$ts) $_
	set xref($t)     $_ ; # index on manpage file name
	set xref($ts)    $_ ; # ditto, with section added
	set xref($td)    $_ ; # index on document title

	# Store an inverted file - keyword relationship, for the index
	foreach kw $md(keywords) {
	    lappend keys($kw) $symfile
	}
    }

    set if [Output index]
    foreach k [array names keys] {
	if {[info exists xref(kw,$k)]} continue

	set frag $kwid($k)
	set xref(kw,$k) [set _ [list $if $frag]]
	set xref($k)    $_
    }
    return
}

proc ::dtplite::XrefGetSaved {} {
    # xref :: map (xrefid -> list (symbolicfile))
    variable  xref
    array set xref {}

    # Load old cross references, from a previous run
    set fqn [At .xrf]
    if {[file exists $fqn]} {
	array set xref [set s [Get $fqn]]
    }

    # Add any new cross references ...
    XrefGet
    Write $fqn [array get xref]
    return
}

proc ::dtplite::XrefSetup {o} {
    # xref :: map (xrefid -> list (symbolicfile))
    variable xref
    # Skip if no data available
    if {![array size xref]}         return
    # Skip if backend doesn't support an index
    if {![in [$o parameters] xref]} return

    # Transfer index data to the backend. The data we keep has to be
    # re-formatted from a dict into a list of tuples with leading
    # xrefid.

    # xrefl :: list (list (xrefid symbolicfile...)...)
    variable xrefl
    if {![info exist xrefl]} {
	set xrefl {}
	foreach k [array names xref] {
	    lappend xrefl [linsert $xref($k) 0 $k]
	    set f [lindex $xref($k) 0]
	    dt map $f [At $f]
	}
    }
    $o setparam xref $xrefl
    return
}

proc ::dtplite::XrefSetupKwid {o} {
    # kwid :: map (label -> anchorname)
    variable kwid
    # Skip if no data available
    if {![array size kwid]}         return
    # Skip if backend doesn't support an index
    if {![in [$o parameters] kwid]} return
    # Transfer index data to the backend
    $o setparam kwid [array get kwid]
    return
}

# ### ### ### ######### ######### #########
## Extending and shrinking the navigation bar.

proc ::dtplite::NavbuttonPush {label file ref} {
    # nav = list (list (label reference) ...)
    variable nav
    #set file [fileutil::relativeUrl $ref $file]]]
    set      nav [linsert $nav 0 [list $label $file]]
    return
}

proc ::dtplite::NavbuttonPop {} {
    # nav = list (list (label reference) ...)
    variable nav
    set      nav [lrange $nav 1 end]
    return
}

# ### ### ### ######### ######### #########
## Header/Footer mgmt
## Header is merged from regular header, plus nav bar.
## Caching the merge result for quicker future access.

proc ::dtplite::HeaderSetup {o ref} {
    variable header
    variable nav
    variable prenav
    variable postnav
    variable raw

    # Activate raw mode, if supported and requested.
    if {[in [$o parameters] raw] && $raw} {
	$o setparam raw 1
    }
    
    # We cannot generate a navigation bar if the output format does
    # not support a "header".
    if {![in [$o parameters] header]} return

    # Do not generate a navigation bar if no content was specified for
    # it, at all.
    if {![llength $prenav] &&
	![llength $postnav] &&
	![llength $nav] &&
	[string equal $header ""]} return

    $o setparam header [Navbar $nav $ref]
    return
}

proc ::dtplite::Navbar {nav ref} {
    variable header
    variable prenav
    variable postnav

    set sep 0
    set first 1
    set hdr ""

    append hdr [NavbarSegment sep first $prenav  $ref]
    append hdr [NavbarSegment sep first $nav     $ref]
    append hdr [NavbarSegment sep first $postnav $ref]

    if {[string length $hdr]} {
	set hdr "<hr> \[\n $hdr \] <hr>\n"
    }
    if {![string equal $header ""]} {
	set hdr "$header $hdr"
    }
    return $hdr
}

proc ::dtplite::NavbarSegment {sepv firstv nav ref} {
    if {![llength $nav]} { return {} }
    upvar 1 $sepv sep $firstv first

    if {$sep} {append hdr <br>\n}
    set sep 0

    foreach item $nav {
	if {!$first} {append hdr "| "} else {append hdr "  "}
	set first 0
	foreach {label url} $item break

	if {[string length $ref] &&
	    ![string match *://* $url] &&
	    ![string match /*    $url]} {
	    # The specified url is a plain relative path and we have a
	    # proper referent.  We assume that this path is relative
	    # to the toplevel toc and index files we are generating,
	    # and transform it here to be relative to the referent
	    # instead.
	    set url [fileutil::relativeUrl $ref $url]
	}
	append hdr "<a href=\"" $url "\">" $label "</a>\n"
    }
    return $hdr
}

proc ::dtplite::FooterSetup {o} {
    variable footer
    if {[string equal $footer ""]}    return
    if {![in [$o parameters] footer]} return
    $o setparam footer $footer
    return
}

# ### ### ### ######### ######### #########
## Invoking the functionality.

proc ::dtplite::print-via {cmd} {
    variable print $cmd
    return
}

proc ::dtplite::do {arguments} {
    Init

    if {[catch {
	ProcessCmdline $arguments
    }]} {
	return 1
    }
    if {[catch {
	set mode $::dtplite::mode
	Do.$mode
    } msg]} {
	## puts $::errorInfo
	dt destroy
	ArgError $msg
	return 1
    }
    dt destroy
    return 0
}

# ### ### ### ######### ######### #########
return

