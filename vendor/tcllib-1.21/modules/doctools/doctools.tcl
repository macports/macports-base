# doctools.tcl --
#
#	Implementation of doctools objects for Tcl.
#
# Copyright (c) 2003-2019 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.2
package require textutil::expander

# @mdgen OWNER: api.tcl
# @mdgen OWNER: checker.tcl
# @mdgen OWNER: mpformats/*.tcl
# @mdgen OWNER: mpformats/*.msg
# @mdgen OWNER: mpformats/fmt.*
# @mdgen OWNER: mpformats/man.macros

namespace eval ::doctools {
    # Data storage in the doctools module
    # -------------------------------
    #
    # One namespace per object, containing
    #  1) A list of additional search paths for format definition files.
    #     This list extends the list of standard paths known to the module.
    #     The paths in the list are searched before the standard paths.
    #  2) Configuration information
    #     a) string:  The format to use when converting the input.
    #     b) boolean: A flag telling us whether to warn when visual markup
    #        is used in the input, or not.
    #     c) File information associated with the input, if any.
    #     d) Module information associated with the input, if any.
    #     e) Copyright information, if any
    #  4) Name of the interpreter used to perform the syntax check of the
    #     input (= allowed order of formatting commands).
    #  5) Name of the interpreter containing the code coming from the format
    #     definition file.
    #  6) Name of the expander object used to interpret the input to convert.

    # commands is the list of subcommands recognized by the doctools objects
    variable commands [list		\
	    "cget"			\
	    "configure"			\
	    "destroy"			\
	    "format"			\
	    "map"			\
	    "search"			\
	    "warnings"                  \
	    "parameters"                \
	    "setparam"                  \
	    ]

    # Only export the toplevel commands
    namespace export new search help

    # Global data

    #  1) List of standard paths to look at when searching for a format
    #     definition. Extensible.
    #  2) Location of this file in the filesystem

    variable paths [list]
    variable here [file dirname [info script]]
}

# ::doctools::search --
#
#	Extend the list of paths used when searching for format definition files.
#
# Arguments:
#	path	Path to add to the list. The path has to exist, has to be a
#               directory, and has to be readable.
#
# Results:
#	None.
#
# Sideeffects:
#	The specified path is added to the front of the list of search
#	paths. This means that the new path is search before the
#	standard paths set at module initialization time.

proc ::doctools::search {path} {
    variable paths

    if {![file exists      $path]} {return -code error "doctools::search: path does not exist"}
    if {![file isdirectory $path]} {return -code error "doctools::search: path is not a directory"}
    if {![file readable    $path]} {return -code error "doctools::search: path cannot be read"}

    set paths [linsert $paths 0 $path]
    return
}

# ::doctools::help --
#
#	Return a string containing short help
#	regarding the existing formatting commands.
#
# Arguments:
#	None.
#
# Results:
#	A string.

proc ::doctools::help {} {
    return "formatting commands\n\
	    * manpage_begin - begin of manpage\n\
	    * moddesc       - module description\n\
	    * titledesc     - manpage title\n\
	    * copyright     - copyright assignment\n\
	    * manpage_end   - end of manpage\n\
	    * require       - package requirement\n\
	    * description   - begin of manpage body\n\
	    * section       - begin new section of body\n\
	    * subsection    - begin new sub-section of body\n\
	    * para          - begin new paragraph\n\
	    * list_begin    - begin a list\n\
	    * list_end      - end of a list\n\
	    * lst_item      - begin item of definition list\n\
	    * call          - command definition, adds to synopsis\n\
	    * usage         - see above, without adding to synopsis\n\
	    * bullet        - begin item in bulleted list\n\
	    * enum          - begin item in enumerated list\n\
	    * arg_def       - begin item in argument list\n\
	    * cmd_def       - begin item in command list\n\
	    * opt_def       - begin item in option list\n\
	    * tkoption_def  - begin item in tkoption list\n\
	    * example       - example block\n\
	    * example_begin - begin example\n\
	    * example_end   - end of example\n\
	    * category      - category declaration\n\
	    * see_also      - cross reference declaration\n\
	    * keywords      - keyword declaration\n\
	    * nl            - paragraph break in list items\n\
	    * arg           - semantic markup - argument\n\
	    * cmd           - semantic markup - command\n\
	    * opt           - semantic markup - optional data\n\
	    * comment       - semantic markup - comment\n\
	    * sectref       - semantic markup - section reference\n\
	    * syscmd        - semantic markup - system command\n\
	    * method        - semantic markup - object method\n\
	    * namespace     - semantic markup - namespace name\n\
	    * option        - semantic markup - option\n\
	    * widget        - semantic markup - widget\n\
	    * fun           - semantic markup - function\n\
	    * type          - semantic markup - data type\n\
	    * package       - semantic markup - package\n\
	    * class         - semantic markup - class\n\
	    * var           - semantic markup - variable\n\
	    * file          - semantic markup - file \n\
	    * uri           - semantic markup - uri (optional label)\n\
	    * term          - semantic markup - unspecific terminology\n\
	    * const         - semantic markup - constant value\n\
	    * emph          - emphasis\n\
	    * strong        - emphasis, deprecated, usage is discouraged\n\
	    "
}

# ::doctools::new --
#
#	Create a new doctools object with a given name. May configure the object.
#
# Arguments:
#	name	Name of the doctools object.
#	args	Options configuring the new object.
#
# Results:
#	name	Name of the doctools created

proc ::doctools::new {name args} {

    if { [llength [info commands ::$name]] } {
	return -code error "command \"$name\" already exists, unable to create doctools object"
    }
    if {[llength $args] % 2 == 1} {
	return -code error "wrong # args: doctools::new name ?opt val...??"
    }

    # The arguments seem to be ok, setup the namespace for the object

    namespace eval ::doctools::doctools$name {
	variable paths      [list]
	variable format     ""
	variable formatfile ""
	variable deprecated 0
	variable file       ""
	variable mainfile   ""
	variable ibase      ""
	variable module     ""
	variable copyright  ""
	variable format_ip  ""
	variable chk_ip     ""
	variable expander   "[namespace current]::ex"
	variable ex_ok      0
	variable msg        [list]
	variable param      [list]
	variable map ;      array set map {}
    }

    # Create the command to manipulate the object
    #                 $name -> ::doctools::DoctoolsProc $name
    interp alias {} ::$name {} ::doctools::DoctoolsProc $name

    # If the name was followed by arguments use them to configure the
    # object before returning its handle to the caller.

    if {[llength $args] > 1} {
	# Use linsert trick to make the command a pure list.
	eval [linsert $args 0 _configure $name]
    }
    return $name
}

##########################
# Private functions follow

# ::doctools::DoctoolsProc --
#
#	Command that processes all doctools object commands.
#	Dispatches any object command to the appropriate internal
#	command implementing its functionality.
#
# Arguments:
#	name	Name of the doctools object to manipulate.
#	cmd	Subcommand to invoke.
#	args	Arguments for subcommand.
#
# Results:
#	Varies based on command to perform

proc ::doctools::DoctoolsProc {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	error "wrong # args: should be \"$name option ?arg arg ...?\""
    }

    # Split the args into command and args components

    if { [llength [info commands ::doctools::_$cmd]] == 0 } {
	variable commands
	set optlist [join $commands ", "]
	set optlist [linsert $optlist "end-1" "or"]
	return -code error "bad option \"$cmd\": must be $optlist"
    }
    return [eval [list ::doctools::_$cmd $name] $args]
}

##########################
# Method implementations follow (these are also private commands)

# ::doctools::_cget --
#
#	Retrieve the current value of a particular option
#
# Arguments:
#	name	Name of the doctools object to query
#	option	Name of the option whose value we are asking for.
#
# Results:
#	The value of the option

proc ::doctools::_cget {name option} {
    _configure $name $option
}

# ::doctools::_configure --
#
#	Configure a doctools object, or query its configuration.
#
# Arguments:
#	name	Name of the doctools object to configure
#	args	Options and their values.
#
# Results:
#	None if configuring the object.
#	A list of all options and their values if called without arguments.
#	The value of one particular option if called with a single argument.

proc ::doctools::_configure {name args} {
    upvar #0 ::doctools::doctools${name}::format_ip  format_ip
    upvar #0 ::doctools::doctools${name}::chk_ip     chk_ip
    upvar #0 ::doctools::doctools${name}::expander   expander
    upvar #0 ::doctools::doctools${name}::passes     passes

    if {[llength $args] == 0} {
	# Retrieve the current configuration.

	upvar #0 ::doctools::doctools${name}::file       file
	upvar #0 ::doctools::doctools${name}::ibase      ibase
	upvar #0 ::doctools::doctools${name}::module     module
	upvar #0 ::doctools::doctools${name}::format     format
	upvar #0 ::doctools::doctools${name}::copyright  copyright
	upvar #0 ::doctools::doctools${name}::deprecated deprecated

	set     res [list]
	lappend res -file       $file
	lappend res -ibase      $ibase
	lappend res -module     $module
	lappend res -format     $format
	lappend res -copyright  $copyright
	lappend res -deprecated $deprecated
	return $res

    } elseif {[llength $args] == 1} {
	# Query the value of one particular option.

	switch -exact -- [lindex $args 0] {
	    -file {
		upvar #0 ::doctools::doctools${name}::file file
		return $file
	    }
	    -ibase {
		upvar #0 ::doctools::doctools${name}::ibase ibase
		return $ibase
	    }
	    -module {
		upvar #0 ::doctools::doctools${name}::module module
		return $module
	    }
	    -copyright {
		upvar #0 ::doctools::doctools${name}::copyright copyright
		return $copyright
	    }
	    -format {
		upvar #0 ::doctools::doctools${name}::format format
		return $format
	    }
	    -deprecated {
		upvar #0 ::doctools::doctools${name}::deprecated deprecated
		return $deprecated
	    }
	    default {
		return -code error \
			"doctools::_configure: Unknown option \"[lindex $args 0]\", expected\
			-copyright, -file, -ibase, -module, -format, or -deprecated"
	    }
	}
    } else {
	# Reconfigure the object.

	if {[llength $args] % 2 == 1} {
	    return -code error "wrong # args: doctools::_configure name ?opt val...??"
	}

	foreach {option value} $args {
	    switch -exact -- $option {
		-file {
		    upvar #0 ::doctools::doctools${name}::file     file
		    upvar #0 ::doctools::doctools${name}::mainfile mfile
		    set file  $value
		    set mfile $value
		}
		-ibase {
		    upvar #0 ::doctools::doctools${name}::ibase    ibase
		    set ibase $value
		}
		-module {
		    upvar #0 ::doctools::doctools${name}::module module
		    set module $value
		}
		-copyright {
		    upvar #0 ::doctools::doctools${name}::copyright copyright
		    set copyright $value
		}
		-format {
		    if {[catch {
			set fmtfile [LookupFormat $name $value]
			SetupFormatter $name $fmtfile
			upvar #0 ::doctools::doctools${name}::format format
			set format $value
		    } msg]} {
			return -code error \
			    -errorinfo $::errorInfo \
			    "doctools::_configure: -format: $msg"
		    }
		}
		-deprecated {
		    if {![string is boolean $value]} {
			return -code error \
				"doctools::_configure: -deprecated expected a boolean, got \"$value\""
		    }
		    upvar #0 ::doctools::doctools${name}::deprecated deprecated
		    set deprecated $value
		}
		default {
		    return -code error \
			    "doctools::_configure: Unknown option \"$option\", expected\
			    -copyright, -file, -ibase, -module, -format, or -deprecated"
		}
	    }
	}
    }
    return ""
}

# ::doctools::_destroy --
#
#	Destroy a doctools object, including its associated command and data storage.
#
# Arguments:
#	name	Name of the doctools object to destroy.
#
# Results:
#	None.

proc ::doctools::_destroy {name} {
    # Check the object for sub objects which have to destroyed before
    # the namespace is torn down.
    namespace eval ::doctools::doctools$name {
	if {$format_ip != ""} {interp delete $format_ip}
	if {$chk_ip    != ""} {interp delete $chk_ip}

	# Expander objects have no delete/destroy method. This would
	# be a leak if not for the fact that an expander object is a
	# namespace, and we have arranged to make it a sub namespace of
	# the doctools object. Therefore tearing down our object namespace
	# also cleans up the expander object.
	# if {$expander != ""} {$expander destroy}

    }
    namespace delete ::doctools::doctools$name
    interp alias {} ::$name {}
    return
}

# ::doctools::_map --
#
#	Add a mapping from symbolic to actual filename to the object.
#
# Arguments:
#	name	Name of the doctools object to use
#	sfname	Symbolic filename to map
#	afname	Actual filename
#
# Results:
#	None.

proc ::doctools::_map {name sfname afname} {
    upvar #0 ::doctools::doctools${name}::map map
    set map($sfname) $afname
    return
}

# ::doctools::_img --
#

#	Add a mapping from symbolic to the actual image filenames to
#	the object. Two actual paths! The path the image is found at
#	in the input, and the path for where image is to be placed in
#	the output.
#
# Arguments:
#	name	Name of the doctools object to use
#	sfname	Symbolic filename to map
#	afnameo	Actual filename, origin
#	afnamed	Actual filename, destination
#
# Results:
#	None.

proc ::doctools::_img {name sfname afnameo afnamed} {
    upvar #0 ::doctools::doctools${name}::imap imap
    set imap($sfname) [list $afnameo $afnamed]
    return
}

# ::doctools::_format --
#
#	Convert some text in doctools format
#	according to the configuration in the object.
#
# Arguments:
#	name	Name of the doctools object to use
#	text	Text to convert.
#
# Results:
#	The conversion result.

proc ::doctools::_format {name text} {
    upvar #0 ::doctools::doctools${name}::format format
    if {$format == ""} {
	return -code error "$name: No format was specified"
    }

    upvar #0 ::doctools::doctools${name}::format_ip format_ip
    upvar #0 ::doctools::doctools${name}::chk_ip    chk_ip
    upvar #0 ::doctools::doctools${name}::ex_ok     ex_ok
    upvar #0 ::doctools::doctools${name}::expander  expander
    upvar #0 ::doctools::doctools${name}::passes    passes
    upvar #0 ::doctools::doctools${name}::msg       warnings

    if {!$ex_ok}       {SetupExpander  $name}
    if {$chk_ip == ""} {SetupChecker   $name}
    # assert (format_ip != "")

    set warnings [list]
    if {[catch {$format_ip eval fmt_initialize}]} {
	return -code error -errorcode {DOCTOOLS ENGINE} \
	    "Could not initialize engine"
    }
    set result ""

    for {
	set p $passes ; set n 1
    } {
	$p > 0
    } {
	incr p -1 ; incr n
    } {
	if {[catch {$format_ip eval [list fmt_setup $n]}]} {
	    catch {$format_ip eval fmt_shutdown}
	    return -code error -errorcode {DOCTOOLS ENGINE} \
		"Could not initialize pass $n of engine"
	}
	$chk_ip eval ck_initialize $n

	if {[catch {set result [$expander expand $text]} msg]} {
	    catch {$format_ip eval fmt_shutdown}
	    # Filter for checker errors and reduce them to the essential message.

	    if {![regexp {^Error in} $msg]}          {
		return -code error -errorcode {DOCTOOLS INPUT} $msg
	    }
	    #set msg [join [lrange [split $msg \n] 2 end]]

	    if {![regexp {^--> \(FmtError\) } $msg]} {
		return -code error -errorcode {DOCTOOLS INPUT} "Doctools $msg"
	    }
	    set msg [lindex [split $msg \n] 0]
	    regsub {^--> \(FmtError\) } $msg {} msg

	    return -code error -errorcode {DOCTOOLS INPUT} $msg
	}

	$chk_ip eval ck_complete
    }

    if {[catch {set result [$format_ip eval [list fmt_postprocess $result]]}]} {
	return -code error -errorcode {DOCTOOLS ENGINE} \
	    "Unable to post process final result"
    }
    if {[catch {$format_ip eval fmt_shutdown}]} {
	return -code error -errorcode {DOCTOOLS ENGINE} \
	    "Could not shut engine down"
    }
    return $result

}

# ::doctools::_search --
#
#	Add a search path to the object.
#
# Arguments:
#	name	Name of the doctools object to extend
#	path	Search path to add.
#
# Results:
#	None.

proc ::doctools::_search {name path} {
    if {![file exists      $path]} {return -code error "$name search: path does not exist"}
    if {![file isdirectory $path]} {return -code error "$name search: path is not a directory"}
    if {![file readable    $path]} {return -code error "$name search: path cannot be read"}

    upvar #0 ::doctools::doctools${name}::paths paths
    set paths [linsert $paths 0 $path]
    return
}

# ::doctools::_warnings --
#
#	Return the warning accumulated during the last invocation of 'format'.
#
# Arguments:
#	name	Name of the doctools object to query
#
# Results:
#	A list of warnings.

proc ::doctools::_warnings {name} {
    upvar #0 ::doctools::doctools${name}::msg msg
    return $msg
}

# ::doctools::_parameters --
#
#	Returns a list containing the parameters provided
#	by the selected formatting engine.
#
# Arguments:
#	name	Name of the doctools object to query
#
# Results:
#	A list of parameter names

proc ::doctools::_parameters {name} {
    upvar #0 ::doctools::doctools${name}::param param
    return $param
}

# ::doctools::_setparam --
#
#	Set a named engine parameter to a value.
#
# Arguments:
#	name	Name of the doctools object to query
#	param	Name of the parameter to set.
#	value	Value to set the parameter to.
#
# Results:
#	None.

proc ::doctools::_setparam {name param value} {
    upvar #0 ::doctools::doctools${name}::format_ip format_ip

    if {$format_ip == {}} {
	return -code error \
		"Unable to set parameters without a valid format"
    }

    $format_ip eval [list fmt_varset $param $value]
    return
}

##########################
# Support commands

# ::doctools::LookupFormat --
#
#	Search a format definition file based upon its name
#
# Arguments:
#	name	Name of the doctools object to use
#	format	Name of the format to look for.
#
# Results:
#	The file containing the format definition

proc ::doctools::LookupFormat {name format} {
    # Order of searching
    # 1) Is the name of the format an existing file ?
    #    If yes, take this file.
    # 2) Look for the file in the directories given to the object itself..
    # 3) Look for the file in the standard directories of this package.

    if {[file exists $format] && [file isfile $format] } {
      return $format
    }

    upvar #0 ::doctools::doctools${name}::paths opaths
    foreach path $opaths {
	set f [file join $path fmt.$format]
	if {[file exists $f] && [file isfile $f]} {
	    return $f
	}
    }

    variable paths
    foreach path $paths {
	set f [file join $path fmt.$format]
	if {[file exists $f] && [file isfile $f]} {
	    return $f
	}
    }

    return -code error "Unknown format \"$format\""
}

# ::doctools::SetupFormatter --
#
#	Create and initializes an interpreter containing a
#	formatting engine
#
# Arguments:
#	name	Name of the doctools object to manipulate
#	format	Name of file containing the code of the engine
#
# Results:
#	None.

proc ::doctools::SetupFormatter {name format} {

    # Create and initialize the interpreter first.
    # Use a transient variable. Interrogate the
    # engine and check its response. Bail out in
    # case of errors. Only if we pass the checks
    # we tear down the old engine and make the new
    # one official.

    variable here
    set mpip [interp create -safe] ; # interpreter for the formatting engine
    $mpip eval [list set auto_path $::auto_path]
    #set mpip [interp create] ; # interpreter for the formatting engine

    $mpip invokehidden source [file join $here api.tcl]
    #$mpip eval [list source [file join $here api.tcl]]
    interp alias $mpip dt_source   {} ::doctools::Source  $mpip [file dirname $format]
    interp alias $mpip dt_read     {} ::doctools::Read    $mpip [file dirname $format]
    interp alias $mpip dt_package  {} ::doctools::Package $mpip
    interp alias $mpip file        {} ::doctools::FileOp  $mpip
    interp alias $mpip puts_stderr {} ::puts stderr
    interp alias $mpip puts_stdout {} ::puts stdout
    $mpip invokehidden source $format
    #$mpip eval [list source $format]

    # Check the engine for useability in doctools.

    foreach api {
	fmt_numpasses
	fmt_initialize
	fmt_setup
	fmt_postprocess
	fmt_shutdown
	fmt_listvariables
	fmt_varset
    } {
	if {[$mpip eval [list info commands $api]] == {}} {
	    interp delete $mpip
	    error "$format error: API incomplete, cannot use this engine"
	}
    }
    if {[catch {
	set passes [$mpip eval fmt_numpasses]
    }]} {
	interp delete $mpip
	error "$format error: Unable to query for number of passes"
    }
    if {![string is integer $passes] || ($passes < 1)} {
	interp delete $mpip
	error "$format error: illegal number of passes \"$passes\""
    }
    if {[catch {
	set parameters [$mpip eval fmt_listvariables]
    }]} {
	interp delete $mpip
	error "$format error: Unable to query for list of parameters"
    }

    # Passed the tests. Tear down existing engine,
    # and checker. The latter is destroyed because
    # of its aliases into the formatter, which are
    # now invalid. It will be recreated during the
    # next call of 'format'.

    upvar #0 ::doctools::doctools${name}::formatfile formatfile
    upvar #0 ::doctools::doctools${name}::format_ip  format_ip
    upvar #0 ::doctools::doctools${name}::chk_ip     chk_ip
    upvar #0 ::doctools::doctools${name}::expander   expander
    upvar #0 ::doctools::doctools${name}::passes     xpasses
    upvar #0 ::doctools::doctools${name}::param      xparam

    if {$chk_ip != {}}    {interp delete $chk_ip}
    if {$format_ip != {}} {interp delete $format_ip}

    set chk_ip    ""
    set format_ip ""

    # Now link engine API into it.

    interp alias $mpip dt_file      {} ::doctools::GetFile      $name
    interp alias $mpip dt_mainfile  {} ::doctools::GetMainFile  $name
    interp alias $mpip dt_fileid    {} ::doctools::GetFileId    $name
    interp alias $mpip dt_ibase     {} ::doctools::GetIBase     $name
    interp alias $mpip dt_module    {} ::doctools::GetModule    $name
    interp alias $mpip dt_copyright {} ::doctools::GetCopyright $name
    interp alias $mpip dt_format    {} ::doctools::GetFormat    $name
    interp alias $mpip dt_user      {} ::doctools::GetUser      $name
    interp alias $mpip dt_lnesting  {} ::doctools::ListLevel    $name
    interp alias $mpip dt_fmap      {} ::doctools::MapFile      $name
    interp alias $mpip dt_imgsrc    {} ::doctools::ImgSrc       $name
    interp alias $mpip dt_imgdst    {} ::doctools::ImgDst       $name
    interp alias $mpip dt_imgdata   {} ::doctools::ImgData      $name
    interp alias $mpip file         {} ::doctools::FileCmd

    foreach cmd {cappend cget cis cname cpop cpush ctopandclear cset lb rb} {
	interp alias $mpip ex_$cmd {} $expander $cmd
    }

    set format_ip  $mpip
    set formatfile $format
    set xpasses    $passes
    set xparam     $parameters
    return
}

# ::doctools::SetupChecker --
#
#	Create and initializes an interpreter for checking the usage of
#	doctools formatting commands
#
# Arguments:
#	name	Name of the doctools object to manipulate
#
# Results:
#	None.

proc ::doctools::SetupChecker {name} {
    # Create an interpreter for checking the usage of doctools formatting commands
    # and initialize it: Link it to the interpreter doing the formatting, the
    # expander object and the configuration information. All of which
    # is accessible through the token/handle (name of state/object array).

    variable here

    upvar #0 ::doctools::doctools${name}::chk_ip    chk_ip
    if {$chk_ip != ""} {return}

    upvar #0 ::doctools::doctools${name}::expander  expander
    upvar #0 ::doctools::doctools${name}::format_ip format_ip

    set chk_ip [interp create] ; # interpreter hosting the formal format checker

    # Make configuration available through command, then load the code base.

    foreach {cmd ckcmd} {
	dt_search     SearchPaths
	dt_deprecated Deprecated
	dt_error      FmtError
	dt_warning    FmtWarning
	dt_where      Where
	dt_file       GetFile
    } {
	interp alias $chk_ip $cmd {} ::doctools::$ckcmd $name
    }
    $chk_ip eval [list source [file join $here checker.tcl]]

    # Simple expander commands are directly routed back into it, no
    # checking required.

    foreach cmd {cappend cget cis cname cpop cpush ctopandclear cset lb rb} {
	interp alias $chk_ip $cmd {} $expander $cmd
    }

    # Link the formatter commands into the checker. We use the prefix
    # 'fmt_' to distinguish them from the checking commands.

    foreach cmd {
	manpage_begin moddesc titledesc copyright manpage_end require
	description section para list_begin list_end lst_item call
	bullet enum example example_begin example_end see_also
	keywords nl arg cmd opt comment sectref syscmd method option
	widget fun type package class var file uri usage term const
	arg_def cmd_def opt_def tkoption_def emph strong plain_text
	namespace subsection category image
    } {
	interp alias $chk_ip fmt_$cmd $format_ip fmt_$cmd
    }
    return
}

# ::doctools::SetupExpander --
#
#	Create and initializes the expander for input
#
# Arguments:
#	name	Name of the doctools object to manipulate
#
# Results:
#	None.

proc ::doctools::SetupExpander {name} {
    upvar #0 ::doctools::doctools${name}::ex_ok    ex_ok
    if {$ex_ok} {return}

    upvar #0 ::doctools::doctools${name}::expander expander
    ::textutil::expander $expander
    $expander evalcmd [list ::doctools::Eval $name]
    $expander textcmd plain_text
    set ex_ok 1
    return
}

# ::doctools::SearchPaths --
#
#	API for checker. Returns list of search paths for format
#	definitions. Used to look for message catalogs as well.
#
# Arguments:
#	name	Name of the doctools object to query.
#
# Results:
#	None.

proc ::doctools::SearchPaths {name} {
    upvar #0 ::doctools::doctools${name}::paths opaths
    variable paths

    set p $opaths
    foreach s $paths {lappend p $s}
    return $p
}

# ::doctools::Deprecated --
#
#	API for checker. Returns flag determining
#	whether visual markup is warned against, or not.
#
# Arguments:
#	name	Name of the doctools object to query.
#
# Results:
#	None.

proc ::doctools::Deprecated {name} {
    upvar #0 ::doctools::doctools${name}::deprecated deprecated
    return $deprecated
}

# ::doctools::FmtError --
#
#	API for checker. Called when an error occurred.
#
# Arguments:
#	name	Name of the doctools object to query.
#	text	Error message
#
# Results:
#	None.

proc ::doctools::FmtError {name text} {
    return -code error "(FmtError) $text"
}

# ::doctools::FmtWarning --
#
#	API for checker. Called when a warning was generated
#
# Arguments:
#	name	Name of the doctools object
#	text	Warning message
#
# Results:
#	None.

proc ::doctools::FmtWarning {name text} {
    upvar #0 ::doctools::doctools${name}::msg msg
    lappend msg $text
    return
}

# ::doctools::Where --
#
#	API for checker. Called when the current location is needed
#
# Arguments:
#	name	Name of the doctools object
#
# Results:
#	List containing offset, line, column

proc ::doctools::Where {name} {
    upvar #0 ::doctools::doctools${name}::expander expander
    return [$expander where]
}

# ::doctools::Eval --
#
#	API for expander. Routes the macro invocations
#	into the checker interpreter
#
# Arguments:
#	name	Name of the doctools object to query.
#
# Results:
#	None.

proc ::doctools::Eval {name macro} {
    upvar #0 ::doctools::doctools${name}::chk_ip chk_ip

    #puts stderr "\t\t$name [lindex [split $macro] 0]"

    # Handle the [include] command directly
    if {[string match include* $macro]} {
	set macro [$chk_ip eval [list subst $macro]]
	foreach {cmd filename} $macro break
	return [ExpandInclude $name $filename]
    }

    # Rewrite the [namespace] command before passing it on.
    # "namespace" is a special command. The interpreter the validator
    # resides in uses the package "msgcat", which in turn uses the
    # builtin namespace. So the builtin cannot be simply
    # overwritten. We use a different name.

    if {[string match namespace* $macro]} {
	set macro _$macro
    }
    return [$chk_ip eval $macro]
}

# ::doctools::ExpandInclude --
#
#	Handle inclusion of files.
#
# Arguments:
#	name	Name of the doctools object to query.
#	path	Name of file to include and expand.
#
# Results:
#	None.

proc ::doctools::ExpandInclude {name path} {
    upvar #0 ::doctools::doctools${name}::file file
    upvar #0 ::doctools::doctools${name}::ibase ibase

    set savedi $ibase
    set savedf $file

    set base $ibase
    if {$base eq {}} { set base $file }

    set ipath [file normalize [file join [file dirname $base] $path]]
    if {![file exists $ipath]} {
	set ipath $path
	if {![file exists $ipath]} {
	    return -code error "Unable to find include file \"$path\""
	}
    }

    set    chan [open $ipath r]
    set    text [read $chan]
    close $chan

    upvar #0 ::doctools::doctools${name}::expander  expander

    set ibase $ipath
    set res [$expander expand $text]

    set ibase $savedi
    set file  $savedf

    return $res
}

# ::doctools::GetUser --
#
#	API for formatter. Returns name of current user
#
# Arguments:
#	name	Name of the doctools object to query.
#
# Results:
#	String, name of current user.

proc ::doctools::GetUser {name} {
    global  tcl_platform
    return $tcl_platform(user)
}

# ::doctools::GetFile --
#
#	API for formatter. Returns file information
#
# Arguments:
#	name	Name of the doctools object to query.
#
# Results:
#	File information

proc ::doctools::GetFile {name} {

    #puts stderr "GetFile $name"

    upvar #0 ::doctools::doctools${name}::file file

    #puts stderr "ok $file"
    return $file
}

proc ::doctools::GetMainFile {name} {

    #puts stderr "GetMainFile $name"

    upvar #0 ::doctools::doctools${name}::mainfile mfile

    #puts stderr "ok $mfile"
    return $mfile
}

# ::doctools::GetFileId --
#
#	API for formatter. Returns file information (truncated to stem of filename)
#
# Arguments:
#	name	Name of the doctools object to query.
#
# Results:
#	File information

proc ::doctools::GetFileId {name} {
    return [file rootname [file tail [GetFile $name]]]
}

proc ::doctools::GetIBase {name} {
    upvar #0 ::doctools::doctools${name}::file file
    upvar #0 ::doctools::doctools${name}::ibase ibase

    set base $ibase
    if {$base eq {}} { set base $file }
    return $base
}

# ::doctools::FileCmd --
#
#	API for formatter. Restricted implementation of file.
#
# Arguments:
#	name	Name of the doctools object to query.
#
# Results:
#	Module information

proc ::doctools::FileCmd {cmd args} {
    switch -exact -- $cmd {
	split    {return [eval file split    $args]}
	join     {return [eval file join     $args]}
	tail     {return [eval file tail     $args]}
	rootname {return [eval file rootname $args]}
    }
    return -code error "Illegal subcommand: $cmd $args"
}

# ::doctools::GetModule --
#
#	API for formatter. Returns module information
#
# Arguments:
#	name	Name of the doctools object to query.
#
# Results:
#	Module information

proc ::doctools::GetModule {name} {
    upvar #0 ::doctools::doctools${name}::module module
    return   $module
}

# ::doctools::GetCopyright --
#
#	API for formatter. Returns copyright information
#
# Arguments:
#	name	Name of the doctools object to query.
#
# Results:
#	Copyright information

proc ::doctools::GetCopyright {name} {
    upvar #0 ::doctools::doctools${name}::copyright copyright
    return   $copyright
}

# ::doctools::GetFormat --
#
#	API for formatter. Returns format information
#
# Arguments:
#	name	Name of the doctools object to query.
#
# Results:
#	Format information

proc ::doctools::GetFormat {name} {
    upvar #0 ::doctools::doctools${name}::format format
    return $format
}

# ::doctools::ListLevel --
#
#	API for formatter. Returns number of open lists
#
# Arguments:
#	name	Name of the doctools object to query.
#
# Results:
#	Boolean flag.

proc ::doctools::ListLevel {name} {
    upvar #0 ::doctools::doctools${name}::chk_ip chk_ip
    return [$chk_ip eval LNest]
}

# ::doctools::MapFile --
#
#	API for formatter. Maps symbolic to actual filename in a doctools
#	item. If no mapping is found it is assumed that the symbolic name
#	is also the actual name.
#
# Arguments:
#	name	Name of the doctools object to query.
#	fname	Symbolic name of the file.
#
# Results:
#	Actual name of the file.

proc ::doctools::MapFile {name fname} {
    upvar #0 ::doctools::doctools${name}::map map

    #parray map

    if {[info exists map($fname)]} {
	return $map($fname)
    }
    return $fname
}

# ::doctools::Img{Src,Dst} --
#
#	API for formatter. Maps symbolic to actual image in a doctools
#	item. Returns nothing if no mapping is found.
#
# Arguments:
#	name		Name of the doctools object to query.
#	iname		Symbolic name of the image file.
#	extensions	List of acceptable file extensions.
#
# Results:
#	Actual name of the file.

proc ::doctools::ImgData {name iname extensions} {

    # The system searches for the image relative to the current input
    # file, and the current main file

    upvar #0 ::doctools::doctools${name}::imap imap

    #parray imap

    foreach e $extensions {
	if {[info exists imap($iname.$e)]} {
	    foreach {origin dest} $imap($iname.$e) break

	    set f   [open $origin r]
	    set img [read $f]
	    close   $f

	    return $img
	}
    }
    return {}
}

proc ::doctools::ImgSrc {name iname extensions} {

    # The system searches for the image relative to the current input
    # file, and the current main file

    upvar #0 ::doctools::doctools${name}::imap imap

    #parray imap

    foreach e $extensions {
	if {[info exists imap($iname.$e)]} {
	    foreach {origin dest} $imap($iname.$e) break
	    return $origin
	}
    }
    return {}
}

proc ::doctools::ImgDst {name iname extensions} {
    # The system searches for the image relative to the current input
    # file, and the current main file

    upvar #0 ::doctools::doctools${name}::imap imap

    #parray imap

    foreach e $extensions {
	if {[info exists imap($iname.$e)]} {
	    foreach {origin dest} $imap($iname.$e) break
	    file mkdir [file dirname $dest]
	    file copy -force $origin $dest
	    return $dest
	}
    }
    return {}
}

# ::doctools::Source --
#
#	API for formatter. Used by engine to ask for
#	additional script files support it.
#
# Arguments:
#	name	Name of the doctools object to change.
#
# Results:
#	Boolean flag.

proc ::doctools::Source {ip path file} {
    #puts stderr "$ip (source $path $file)"

    $ip invokehidden source [file join $path [file tail $file]]
    #$ip eval [list source [file join $path [file tail $file]]]
    return
}

proc ::doctools::Read {ip path file} {
    #puts stderr "$ip (read $path $file)"

    return [read [set f [open [file join $path [file tail $file]]]]][close $f]
}

proc ::doctools::Locate {p} {
    # @mdgen NODEP: doctools::__undefined__
    catch {package require doctools::__undefined__}

    #puts stderr "auto_path = [join $::auto_path \n]"

    # Check if requested package is in the list of loadable packages.
    # Then get the highest possible version, and then the index script

    if {[lsearch -exact [package names] $p] < 0} {
	return -code error "Unknown package $p"
    }

    set v  [lindex [lsort -increasing [package versions $p]] end]

    #puts stderr "Package $p = $v"

    return [package ifneeded $p $v]
}

proc ::doctools::FileOp {ip args} {
    #puts stderr "$ip (file $args)"
    # -- FUTURE -- disallow unsafe operations --

    return [eval [linsert $args 0 file]]
}

proc ::doctools::Package {ip pkg} {
    #puts stderr "$ip package require $pkg"

    set indexScript [Locate $pkg]

    $ip expose source
    $ip expose load
    $ip eval		$indexScript
    $ip hide   source
    $ip hide   load
    #$ip eval [list source [file join $path [file tail $file]]]
    return
}

#------------------------------------
# Module initialization

namespace eval ::doctools {
    # Reverse order of searching. First to search is specified last.

    # FOO/doctools.tcl
    # => FOO/mpformats

    #catch {search [file join $here                lib doctools mpformats]}
    #catch {search [file join [file dirname $here] lib doctools mpformats]}
    catch {search [file join $here                             mpformats]}
}

package provide doctools 1.5.6
