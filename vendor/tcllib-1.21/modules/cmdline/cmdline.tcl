# cmdline.tcl --
#
#	This package provides a utility for parsing command line
#	arguments that are processed by our various applications.
#	It also includes a utility routine to determine the
#	application name for use in command line errors.
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
# Copyright (c) 2001-2015 by Andreas Kupries <andreas_kupries@users.sf.net>.
# Copyright (c) 2003      by David N. Welton  <davidw@dedasys.com>
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.2
package provide cmdline 1.5.2

namespace eval ::cmdline {
    namespace export getArgv0 getopt getKnownOpt getfiles getoptions \
	    getKnownOptions usage
}

# ::cmdline::getopt --
#
#	The cmdline::getopt works in a fashion like the standard
#	C based getopt function.  Given an option string and a
#	pointer to an array or args this command will process the
#	first argument and return info on how to proceed.
#
# Arguments:
#	argvVar		Name of the argv list that you
#			want to process.  If options are found the
#			arg list is modified and the processed arguments
#			are removed from the start of the list.
#	optstring	A list of command options that the application
#			will accept.  If the option ends in ".arg" the
#			getopt routine will use the next argument as
#			an argument to the option.  Otherwise the option
#			is a boolean that is set to 1 if present.
#	optVar		The variable pointed to by optVar
#			contains the option that was found (without the
#			leading '-' and without the .arg extension).
#	valVar		Upon success, the variable pointed to by valVar
#			contains the value for the specified option.
#			This value comes from the command line for .arg
#			options, otherwise the value is 1.
#			If getopt fails, the valVar is filled with an
#			error message.
#
# Results:
# 	The getopt function returns 1 if an option was found, 0 if no more
# 	options were found, and -1 if an error occurred.

proc ::cmdline::getopt {argvVar optstring optVar valVar} {
    upvar 1 $argvVar argsList
    upvar 1 $optVar option
    upvar 1 $valVar value

    set result [getKnownOpt argsList $optstring option value]

    if {$result < 0} {
        # Collapse unknown-option error into any-other-error result.
        set result -1
    }
    return $result
}

# ::cmdline::getKnownOpt --
#
#	The cmdline::getKnownOpt works in a fashion like the standard
#	C based getopt function.  Given an option string and a
#	pointer to an array or args this command will process the
#	first argument and return info on how to proceed.
#
# Arguments:
#	argvVar		Name of the argv list that you
#			want to process.  If options are found the
#			arg list is modified and the processed arguments
#			are removed from the start of the list.  Note that
#			unknown options and the args that follow them are
#			left in this list.
#	optstring	A list of command options that the application
#			will accept.  If the option ends in ".arg" the
#			getopt routine will use the next argument as
#			an argument to the option.  Otherwise the option
#			is a boolean that is set to 1 if present.
#	optVar		The variable pointed to by optVar
#			contains the option that was found (without the
#			leading '-' and without the .arg extension).
#	valVar		Upon success, the variable pointed to by valVar
#			contains the value for the specified option.
#			This value comes from the command line for .arg
#			options, otherwise the value is 1.
#			If getopt fails, the valVar is filled with an
#			error message.
#
# Results:
# 	The getKnownOpt function returns 1 if an option was found,
#	0 if no more options were found, -1 if an unknown option was
#	encountered, and -2 if any other error occurred.

proc ::cmdline::getKnownOpt {argvVar optstring optVar valVar} {
    upvar 1 $argvVar argsList
    upvar 1 $optVar  option
    upvar 1 $valVar  value

    # default settings for a normal return
    set value ""
    set option ""
    set result 0

    # check if we're past the end of the args list
    if {[llength $argsList] != 0} {

	# if we got -- or an option that doesn't begin with -, return (skipping
	# the --).  otherwise process the option arg.
	switch -glob -- [set arg [lindex $argsList 0]] {
	    "--" {
		set argsList [lrange $argsList 1 end]
	    }
	    "--*" -
	    "-*" {
		set option [string range $arg 1 end]
		if {[string equal [string range $option 0 0] "-"]} {
		    set option [string range $arg 2 end]
		}

		# support for format: [-]-option=value
		set idx [string first "=" $option 1]
		if {$idx != -1} {
		    set _val   [string range $option [expr {$idx+1}] end]
		    set option [string range $option 0   [expr {$idx-1}]]
		}

		if {[lsearch -exact $optstring $option] != -1} {
		    # Booleans are set to 1 when present
		    set value 1
		    set result 1
		    set argsList [lrange $argsList 1 end]
		} elseif {[lsearch -exact $optstring "$option.arg"] != -1} {
		    set result 1
		    set argsList [lrange $argsList 1 end]

		    if {[info exists _val]} {
			set value $_val
		    } elseif {[llength $argsList]} {
			set value [lindex $argsList 0]
			set argsList [lrange $argsList 1 end]
		    } else {
			set value "Option \"$option\" requires an argument"
			set result -2
		    }
		} else {
		    # Unknown option.
		    set value "Illegal option \"-$option\""
		    set result -1
		}
	    }
	    default {
		# Skip ahead
	    }
	}
    }

    return $result
}

# ::cmdline::getoptions --
#
#	Process a set of command line options, filling in defaults
#	for those not specified.  This also generates an error message
#	that lists the allowed flags if an incorrect flag is specified.
#
# Arguments:
#	argvVar		The name of the argument list, typically argv.
#			We remove all known options and their args from it.
#                       In other words, after the call to this command the
#                       referenced variable contains only the non-options,
#                       and unknown options.
#	optlist		A list-of-lists where each element specifies an option
#			in the form:
#				(where flag takes no argument)
#					flag comment
#
#				(or where flag takes an argument)
#					flag default comment
#
#			If flag ends in ".arg" then the value is taken from the
#			command line. Otherwise it is a boolean and appears in
#			the result if present on the command line. If flag ends
#			in ".secret", it will not be displayed in the usage.
#	usage		Text to include in the usage display. Defaults to
#			"options:"
#
# Results
#	Name value pairs suitable for using with array set.
#       A modified `argvVar`.

proc ::cmdline::getoptions {argvVar optlist {usage options:}} {
    upvar 1 $argvVar argv

    set opts [GetOptionDefaults $optlist result]

    set argc [llength $argv]
    while {[set err [getopt argv $opts opt arg]]} {
	if {$err < 0} {
            set result(?) ""
            break
	}
	set result($opt) $arg
    }
    if {[info exist result(?)] || [info exists result(help)]} {
	Error [usage $optlist $usage] USAGE
    }
    return [array get result]
}

# ::cmdline::getKnownOptions --
#
#	Process a set of command line options, filling in defaults
#	for those not specified.  This ignores unknown flags, but generates
#	an error message that lists the correct usage if a known option
#	is used incorrectly.
#
# Arguments:
#	argvVar		The name of the argument list, typically argv.  This
#			We remove all known options and their args from it.
#                       In other words, after the call to this command the
#                       referenced variable contains only the non-options,
#                       and unknown options.
#	optlist		A list-of-lists where each element specifies an option
#			in the form:
#				flag default comment
#			If flag ends in ".arg" then the value is taken from the
#			command line. Otherwise it is a boolean and appears in
#			the result if present on the command line. If flag ends
#			in ".secret", it will not be displayed in the usage.
#	usage		Text to include in the usage display. Defaults to
#			"options:"
#
# Results
#	Name value pairs suitable for using with array set.
#       A modified `argvVar`.

proc ::cmdline::getKnownOptions {argvVar optlist {usage options:}} {
    upvar 1 $argvVar argv

    set opts [GetOptionDefaults $optlist result]

    # As we encounter them, keep the unknown options and their
    # arguments in this list.  Before we return from this procedure,
    # we'll prepend these args to the argList so that the application
    # doesn't lose them.

    set unknownOptions [list]

    set argc [llength $argv]
    while {[set err [getKnownOpt argv $opts opt arg]]} {
	if {$err == -1} {
            # Unknown option.

            # Skip over any non-option items that follow it.
            # For now, add them to the list of unknownOptions.
            lappend unknownOptions [lindex $argv 0]
            set argv [lrange $argv 1 end]
            while {([llength $argv] != 0) \
                    && ![string match "-*" [lindex $argv 0]]} {
                lappend unknownOptions [lindex $argv 0]
                set argv [lrange $argv 1 end]
            }
	} elseif {$err == -2} {
            set result(?) ""
            break
        } else {
            set result($opt) $arg
        }
    }

    # Before returning, prepend the any unknown args back onto the
    # argList so that the application doesn't lose them.
    set argv [concat $unknownOptions $argv]

    if {[info exist result(?)] || [info exists result(help)]} {
	Error [usage $optlist $usage] USAGE
    }
    return [array get result]
}

# ::cmdline::GetOptionDefaults --
#
#	This internal procedure processes the option list (that was passed to
#	the getopt or getKnownOpt procedure).  The defaultArray gets an index
#	for each option in the option list, the value of which is the option's
#	default value.
#
# Arguments:
#	optlist		A list-of-lists where each element specifies an option
#			in the form:
#				flag default comment
#			If flag ends in ".arg" then the value is taken from the
#			command line. Otherwise it is a boolean and appears in
#			the result if present on the command line. If flag ends
#			in ".secret", it will not be displayed in the usage.
#	defaultArrayVar	The name of the array in which to put argument defaults.
#
# Results
#	Name value pairs suitable for using with array set.

proc ::cmdline::GetOptionDefaults {optlist defaultArrayVar} {
    upvar 1 $defaultArrayVar result

    set opts {? help}
    foreach opt $optlist {
	set name [lindex $opt 0]
	if {[regsub -- {\.secret$} $name {} name] == 1} {
	    # Need to hide this from the usage display and getopt
	}
	lappend opts $name
	if {[regsub -- {\.arg$} $name {} name] == 1} {

	    # Set defaults for those that take values.

	    set default [lindex $opt 1]
	    set result($name) $default
	} else {
	    # The default for booleans is false
	    set result($name) 0
	}
    }
    return $opts
}

# ::cmdline::usage --
#
#	Generate an error message that lists the allowed flags.
#
# Arguments:
#	optlist		As for cmdline::getoptions
#	usage		Text to include in the usage display. Defaults to
#			"options:"
#
# Results
#	A formatted usage message

proc ::cmdline::usage {optlist {usage {options:}}} {
    set str "[getArgv0] $usage\n"
    set longest 20
    set lines {}
    foreach opt [concat $optlist \
	     {{- "Forcibly stop option processing"} {help "Print this message"} {? "Print this message"}}] {
	set name "-[lindex $opt 0]"
	if {[regsub -- {\.secret$} $name {} name] == 1} {
	    # Hidden option
	    continue
	}
	if {[regsub -- {\.arg$} $name {} name] == 1} {
	    append name " value"
	    set desc "[lindex $opt 2] <[lindex $opt 1]>"
	} else {
	    set desc "[lindex $opt 1]"
	}
	set n [string length $name]
	if {$n > $longest} { set longest $n }
	# max not available before 8.5 - set longest [expr {max($longest, )}]
	lappend lines $name $desc
    }
    foreach {name desc} $lines {
	append str "[string trimright [format " %-*s %s" $longest $name $desc]]\n"
    }

    return $str
}

# ::cmdline::getfiles --
#
#	Given a list of file arguments from the command line, compute
#	the set of valid files.  On windows, file globbing is performed
#	on each argument.  On Unix, only file existence is tested.  If
#	a file argument produces no valid files, a warning is optionally
#	generated.
#
#	This code also uses the full path for each file.  If not
#	given it prepends [pwd] to the filename.  This ensures that
#	these files will never conflict with files in our zip file.
#
# Arguments:
#	patterns	The file patterns specified by the user.
#	quiet		If this flag is set, no warnings will be generated.
#
# Results:
#	Returns the list of files that match the input patterns.

proc ::cmdline::getfiles {patterns quiet} {
    set result {}
    if {$::tcl_platform(platform) == "windows"} {
	foreach pattern $patterns {
	    set pat [file join $pattern]
	    set files [glob -nocomplain -- $pat]
	    if {$files == {}} {
		if {! $quiet} {
		    puts stdout "warning: no files match \"$pattern\""
		}
	    } else {
		foreach file $files {
		    lappend result $file
		}
	    }
	}
    } else {
	set result $patterns
    }
    set files {}
    foreach file $result {
	# Make file an absolute path so that we will never conflict
	# with files that might be contained in our zip file.
	set fullPath [file join [pwd] $file]

	if {[file isfile $fullPath]} {
	    lappend files $fullPath
	} elseif {! $quiet} {
	    puts stdout "warning: no files match \"$file\""
	}
    }
    return $files
}

# ::cmdline::getArgv0 --
#
#	This command returns the "sanitized" version of argv0.  It will strip
#	off the leading path and remove the ".bin" extensions that our apps
#	use because they must be wrapped by a shell script.
#
# Arguments:
#	None.
#
# Results:
#	The application name that can be used in error messages.

proc ::cmdline::getArgv0 {} {
    global argv0

    set name [file tail $argv0]
    return [file rootname $name]
}

##
# ### ### ### ######### ######### #########
##
# Now the typed versions of the above commands.
##
# ### ### ### ######### ######### #########
##

# typedCmdline.tcl --
#
#    This package provides a utility for parsing typed command
#    line arguments that may be processed by various applications.
#
# Copyright (c) 2000 by Ross Palmer Mohn.
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: cmdline.tcl,v 1.28 2011/02/23 17:41:52 andreas_kupries Exp $

namespace eval ::cmdline {
    namespace export typedGetopt typedGetoptions typedUsage

    # variable cmdline::charclasses --
    #
    #    Create regexp list of allowable character classes
    #    from "string is" error message.
    #
    # Results:
    #    String of character class names separated by "|" characters.

    variable charclasses
    #checker exclude badKey
    catch {string is . .} charclasses
    variable dummy
    regexp      -- {must be (.+)$} $charclasses dummy charclasses
    regsub -all -- {, (or )?}      $charclasses {|}   charclasses
    unset dummy
}

# ::cmdline::typedGetopt --
#
#	The cmdline::typedGetopt works in a fashion like the standard
#	C based getopt function.  Given an option string and a
#	pointer to a list of args this command will process the
#	first argument and return info on how to proceed. In addition,
#	you may specify a type for the argument to each option.
#
# Arguments:
#	argvVar		Name of the argv list that you want to process.
#			If options are found, the arg list is modified
#			and the processed arguments are removed from the
#			start of the list.
#
#	optstring	A list of command options that the application
#			will accept.  If the option ends in ".xxx", where
#			xxx is any valid character class to the tcl
#			command "string is", then typedGetopt routine will
#			use the next argument as a typed argument to the
#			option. The argument must match the specified
#			character classes (e.g. integer, double, boolean,
#			xdigit, etc.). Alternatively, you may specify
#			".arg" for an untyped argument.
#
#	optVar		Upon success, the variable pointed to by optVar
#			contains the option that was found (without the
#			leading '-' and without the .xxx extension).  If
#			typedGetopt fails the variable is set to the empty
#			string. SOMETIMES! Different for each -value!
#
#	argVar		Upon success, the variable pointed to by argVar
#			contains the argument for the specified option.
#			If typedGetopt fails, the variable is filled with
#			an error message.
#
# Argument type syntax:
#	Option that takes no argument.
#		foo
#
#	Option that takes a typeless argument.
#		foo.arg
#
#	Option that takes a typed argument. Allowable types are all
#	valid character classes to the tcl command "string is".
#	Currently must be one of alnum, alpha, ascii, control,
#	boolean, digit, double, false, graph, integer, lower, print,
#	punct, space, true, upper, wordchar, or xdigit.
#		foo.double
#
#	Option that takes an argument from a list.
#		foo.(bar|blat)
#
# Argument quantifier syntax:
#	Option that takes an optional argument.
#		foo.arg?
#
#	Option that takes a list of arguments terminated by "--".
#		foo.arg+
#
#	Option that takes an optional list of arguments terminated by "--".
#		foo.arg*
#
#	Argument quantifiers work on all argument types, so, for
#	example, the following is a valid option specification.
#		foo.(bar|blat|blah)?
#
# Argument syntax miscellany:
#	Options may be specified on the command line using a unique,
#	shortened version of the option name. Given that program foo
#	has an option list of {bar.alpha blah.arg blat.double},
#	"foo -b fob" returns an error, but "foo -ba fob"
#	successfully returns {bar fob}
#
# Results:
#	The typedGetopt function returns one of the following:
#	 1	a valid option was found
#	 0	no more options found to process
#	-1	invalid option
#	-2	missing argument to a valid option
#	-3	argument to a valid option does not match type
#
# Known Bugs:
#	When using options which include special glob characters,
#	you must use the exact option. Abbreviating it can cause
#	an error in the "cmdline::prefixSearch" procedure.

proc ::cmdline::typedGetopt {argvVar optstring optVar argVar} {
    variable charclasses

    upvar $argvVar argsList

    upvar $optVar retvar
    upvar $argVar optarg

    # default settings for a normal return
    set optarg ""
    set retvar ""
    set retval 0

    # check if we're past the end of the args list
    if {[llength $argsList] != 0} {

        # if we got -- or an option that doesn't begin with -, return (skipping
        # the --).  otherwise process the option arg.
        switch -glob -- [set arg [lindex $argsList 0]] {
            "--" {
                set argsList [lrange $argsList 1 end]
            }

            "-*" {
                # Create list of options without their argument extensions

                set optstr ""
                foreach str $optstring {
                    lappend optstr [file rootname $str]
                }

                set _opt [string range $arg 1 end]

                set i [prefixSearch $optstr [file rootname $_opt]]
                if {$i != -1} {
                    set opt [lindex $optstring $i]

                    set quantifier "none"
                    if {[regexp -- {\.[^.]+([?+*])$} $opt dummy quantifier]} {
                        set opt [string range $opt 0 end-1]
                    }

                    if {[string first . $opt] == -1} {
                        set retval 1
                        set retvar $opt
                        set argsList [lrange $argsList 1 end]

                    } elseif {[regexp -- "\\.(arg|$charclasses)\$" $opt dummy charclass]
                            || [regexp -- {\.\(([^)]+)\)} $opt dummy charclass]} {
				if {[string equal arg $charclass]} {
                            set type arg
			} elseif {[regexp -- "^($charclasses)\$" $charclass]} {
                            set type class
                        } else {
                            set type oneof
                        }

                        set argsList [lrange $argsList 1 end]
                        set opt [file rootname $opt]

                        while {1} {
                            if {[llength $argsList] == 0
                                    || [string equal "--" [lindex $argsList 0]]} {
                                if {[string equal "--" [lindex $argsList 0]]} {
                                    set argsList [lrange $argsList 1 end]
                                }

                                set oneof ""
                                if {$type == "arg"} {
                                    set charclass an
                                } elseif {$type == "oneof"} {
                                    set oneof ", one of $charclass"
                                    set charclass an
                                }

                                if {$quantifier == "?"} {
                                    set retval 1
                                    set retvar $opt
                                    set optarg ""
                                } elseif {$quantifier == "+"} {
                                    set retvar $opt
                                    if {[llength $optarg] < 1} {
                                        set retval -2
                                        set optarg "Option requires at least one $charclass argument$oneof -- $opt"
                                    } else {
                                        set retval 1
                                    }
                                } elseif {$quantifier == "*"} {
                                    set retval 1
                                    set retvar $opt
                                } else {
                                    set optarg "Option requires $charclass argument$oneof -- $opt"
                                    set retvar $opt
                                    set retval -2
                                }
                                set quantifier ""
                            } elseif {($type == "arg")
                                    || (($type == "oneof")
                                    && [string first "|[lindex $argsList 0]|" "|$charclass|"] != -1)
                                    || (($type == "class")
                                    && [string is $charclass [lindex $argsList 0]])} {
                                set retval 1
                                set retvar $opt
                                lappend optarg [lindex $argsList 0]
                                set argsList [lrange $argsList 1 end]
                            } else {
                                set oneof ""
                                if {$type == "arg"} {
                                    set charclass an
                                } elseif {$type == "oneof"} {
                                    set oneof ", one of $charclass"
                                    set charclass an
                                }
                                set optarg "Option requires $charclass argument$oneof -- $opt"
                                set retvar $opt
                                set retval -3

                                if {$quantifier == "?"} {
                                    set retval 1
                                    set optarg ""
                                }
                                set quantifier ""
                            }
                             if {![regexp -- {[+*]} $quantifier]} {
                                break;
                            }
                        }
                    } else {
                        Error \
			    "Illegal option type specification: must be one of $charclasses" \
			    BAD OPTION TYPE
                    }
                } else {
                    set optarg "Illegal option -- $_opt"
                    set retvar $_opt
                    set retval -1
                }
            }
	    default {
		# Skip ahead
	    }
        }
    }

    return $retval
}

# ::cmdline::typedGetoptions --
#
#	Process a set of command line options, filling in defaults
#	for those not specified. This also generates an error message
#	that lists the allowed options if an incorrect option is
#	specified.
#
# Arguments:
#	argvVar		The name of the argument list, typically argv
#	optlist		A list-of-lists where each element specifies an option
#			in the form:
#
#				option default comment
#
#			Options formatting is as described for the optstring
#			argument of typedGetopt. Default is for optionally
#			specifying a default value. Comment is for optionally
#			specifying a comment for the usage display. The
#			options "--", "-help", and "-?" are automatically included
#			in optlist.
#
# Argument syntax miscellany:
#	Options formatting and syntax is as described in typedGetopt.
#	There are two additional suffixes that may be applied when
#	passing options to typedGetoptions.
#
#	You may add ".multi" as a suffix to any option. For options
#	that take an argument, this means that the option may be used
#	more than once on the command line and that each additional
#	argument will be appended to a list, which is then returned
#	to the application.
#		foo.double.multi
#
#	If a non-argument option is specified as ".multi", it is
#	toggled on and off for each time it is used on the command
#	line.
#		foo.multi
#
#	If an option specification does not contain the ".multi"
#	suffix, it is not an error to use an option more than once.
#	In this case, the behavior for options with arguments is that
#	the last argument is the one that will be returned. For
#	options that do not take arguments, using them more than once
#	has no additional effect.
#
#	Options may also be hidden from the usage display by
#	appending the suffix ".secret" to any option specification.
#	Please note that the ".secret" suffix must be the last suffix,
#	after any argument type specification and ".multi" suffix.
#		foo.xdigit.multi.secret
#
# Results
#	Name value pairs suitable for using with array set.

proc ::cmdline::typedGetoptions {argvVar optlist {usage options:}} {
    variable charclasses

    upvar 1 $argvVar argv

    set opts {? help}
    foreach opt $optlist {
        set name [lindex $opt 0]
        if {[regsub -- {\.secret$} $name {} name] == 1} {
            # Remove this extension before passing to typedGetopt.
        }
        if {[regsub -- {\.multi$} $name {} name] == 1} {
            # Remove this extension before passing to typedGetopt.

            regsub -- {\..*$} $name {} temp
            set multi($temp) 1
        }
        lappend opts $name
        if {[regsub -- "\\.(arg|$charclasses|\\(.+).?\$" $name {} name] == 1} {
            # Set defaults for those that take values.
            # Booleans are set just by being present, or not

            set dflt [lindex $opt 1]
            if {$dflt != {}} {
                set defaults($name) $dflt
            }
        }
    }
    set argc [llength $argv]
    while {[set err [typedGetopt argv $opts opt arg]]} {
        if {$err == 1} {
            if {[info exists result($opt)]
                    && [info exists multi($opt)]} {
                # Toggle boolean options or append new arguments

                if {$arg == ""} {
                    unset result($opt)
                } else {
                    set result($opt) "$result($opt) $arg"
                }
            } else {
                set result($opt) "$arg"
            }
        } elseif {($err == -1) || ($err == -3)} {
            Error [typedUsage $optlist $usage] USAGE
        } elseif {$err == -2 && ![info exists defaults($opt)]} {
            Error [typedUsage $optlist $usage] USAGE
        }
    }
    if {[info exists result(?)] || [info exists result(help)]} {
        Error [typedUsage $optlist $usage] USAGE
    }
    foreach {opt dflt} [array get defaults] {
        if {![info exists result($opt)]} {
            set result($opt) $dflt
        }
    }
    return [array get result]
}

# ::cmdline::typedUsage --
#
#	Generate an error message that lists the allowed flags,
#	type of argument taken (if any), default value (if any),
#	and an optional description.
#
# Arguments:
#	optlist		As for cmdline::typedGetoptions
#
# Results
#	A formatted usage message

proc ::cmdline::typedUsage {optlist {usage {options:}}} {
    variable charclasses

    set str "[getArgv0] $usage\n"
    set longest 20
    set lines {}
    foreach opt [concat $optlist \
            {{help "Print this message"} {? "Print this message"}}] {
        set name "-[lindex $opt 0]"
        if {[regsub -- {\.secret$} $name {} name] == 1} {
            # Hidden option
	    continue
	}

	if {[regsub -- {\.multi$} $name {} name] == 1} {
	    # Display something about multiple options
	}

	if {[regexp -- "\\.(arg|$charclasses)\$" $name dummy charclass] ||
	    [regexp -- {\.\(([^)]+)\)} $opt dummy charclass]
	} {
	    regsub -- "\\..+\$" $name {} name
	    append name " $charclass"
	    set desc [lindex $opt 2]
	    set default [lindex $opt 1]
	    if {$default != ""} {
		append desc " <$default>"
	    }
	} else {
	    set desc [lindex $opt 1]
	}
	lappend accum $name $desc
	set n [string length $name]
	if {$n > $longest} { set longest $n }
	# max not available before 8.5 - set longest [expr {max($longest, [string length $name])}]
    }
    foreach {name desc} $accum {
	append str "[string trimright [format " %-*s %s" $longest $name $desc]]\n"
    }
    return $str
}

# ::cmdline::prefixSearch --
#
#	Search a Tcl list for a pattern; searches first for an exact match,
#	and if that fails, for a unique prefix that matches the pattern
#	(i.e, first "lsearch -exact", then "lsearch -glob $pattern*"
#
# Arguments:
#	list		list of words
#	pattern		word to search for
#
# Results:
#	Index of found word is returned. If no exact match or
#	unique short version is found then -1 is returned.

proc ::cmdline::prefixSearch {list pattern} {
    # Check for an exact match

    if {[set pos [::lsearch -exact $list $pattern]] > -1} {
        return $pos
    }

    # Check for a unique short version

    set slist [lsort $list]
    if {[set pos [::lsearch -glob $slist $pattern*]] > -1} {
        # What if there is nothing for the check variable?

        set check [lindex $slist [expr {$pos + 1}]]
        if {[string first $pattern $check] != 0} {
            return [::lsearch -exact $list [lindex $slist $pos]]
        }
    }
    return -1
}
# ::cmdline::Error --
#
#	Internal helper to throw errors with a proper error-code attached.
#
# Arguments:
#	message		text of the error message to throw.
#	args		additional parts of the error code to use,
#                       with CMDLINE as basic prefix added by this command.
#
# Results:
#	An error is thrown, always.

proc ::cmdline::Error {message args} {
    return -code error -errorcode [linsert $args 0 CMDLINE] $message
}
