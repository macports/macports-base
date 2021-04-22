
[//000000001]: # (cmdline \- Command line and option processing)
[//000000002]: # (Generated from file 'cmdline\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (cmdline\(n\) 1\.5\.2 tcllib "Command line and option processing")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

cmdline \- Procedures to process command lines and options\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [::argv handling](#section2)

  - [API](#section3)

      - [Error Codes](#subsection1)

  - [EXAMPLES](#section4)

      - [cmdline::getoptions](#subsection2)

      - [cmdline::getopt](#subsection3)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require cmdline ?1\.5\.2?  

[__::cmdline::getopt__ *argvVar* *optstring* *optVar* *valVar*](#1)  
[__::cmdline::getKnownOpt__ *argvVar* *optstring* *optVar* *valVar*](#2)  
[__::cmdline::getoptions__ *argvVar* *optlist* ?*usage*?](#3)  
[__::cmdline::getKnownOptions__ *argvVar* *optlist* ?*usage*?](#4)  
[__::cmdline::usage__ *optlist* ?*usage*?](#5)  
[__::cmdline::getfiles__ *patterns* *quiet*](#6)  
[__::cmdline::getArgv0__](#7)  

# <a name='description'></a>DESCRIPTION

This package provides commands to parse command lines and options\.

# <a name='section2'></a>::argv handling

One of the most common variables this package will be used with is
__::argv__, which holds the command line of the current application\. This
variable has a companion __::argc__ which is initialized to the number of
elements in __::argv__ at the beginning of the application\.

The commands in this package will *not* modify the __::argc__ companion
when called with __::argv__\. Keeping the value consistent, if such is
desired or required, is the responsibility of the caller\.

# <a name='section3'></a>API

  - <a name='1'></a>__::cmdline::getopt__ *argvVar* *optstring* *optVar* *valVar*

    This command works in a fashion like the standard C based __getopt__
    function\. Given an option string and a pointer to an array of args this
    command will process the *first argument* and return info on how to
    proceed\. The command returns 1 if an option was found, 0 if no more options
    were found, and \-1 if an error occurred\.

    *argvVar* contains the name of the list of arguments to process\. If
    options are found the list is modified and the processed arguments are
    removed from the start of the list\.

    *optstring* contains a list of command options that the application will
    accept\. If the option ends in "\.arg" the command will use the next argument
    as an argument to the option, or extract it from the current argument, if it
    is of the form "option=value"\. Otherwise the option is a boolean that is set
    to 1 if present\.

    *optVar* refers to the variable the command will store the found option
    into \(without the leading '\-' and without the \.arg extension\)\.

    *valVar* refers to the variable to store either the value for the
    specified option into upon success or an error message in the case of
    failure\. The stored value comes from the command line for \.arg options,
    otherwise the value is 1\.

  - <a name='2'></a>__::cmdline::getKnownOpt__ *argvVar* *optstring* *optVar* *valVar*

    Like __::cmdline::getopt__, except it ignores any unknown options in the
    input\.

  - <a name='3'></a>__::cmdline::getoptions__ *argvVar* *optlist* ?*usage*?

    Processes the entire set of command line options found in the list variable
    named by *argvVar* and fills in defaults for those not specified\. This
    also generates an error message that lists the allowed flags if an incorrect
    flag is specified\. The optional *usage*\-argument contains a string to
    include in front of the generated message\. If not present it defaults to
    "options:"\.

    *argvVar* contains the name of the list of arguments to process\. If
    options are found the list is modified and the processed arguments are
    removed from the start of the list\.

    *optlist* contains a list of lists where each element specifies an option
    in the form: *flag* *default* *comment*\.

    If *flag* ends in "\.arg" then the value is taken from the command line\.
    Otherwise it is a boolean and appears in the result if present on the
    command line\. If *flag* ends in "\.secret", it will not be displayed in the
    usage\.

    The options __\-?__, __\-help__, and __\-\-__ are implicitly
    understood\. The first two abort option processing by throwing an error and
    force the generation of the usage message, whereas the the last aborts
    option processing without an error, leaving all arguments coming after for
    regular processing, even if starting with a dash\.

    The result of the command is a dictionary mapping all options to their
    values, be they user\-specified or defaults\.

  - <a name='4'></a>__::cmdline::getKnownOptions__ *argvVar* *optlist* ?*usage*?

    Like __::cmdline::getoptions__, but ignores any unknown options in the
    input\.

  - <a name='5'></a>__::cmdline::usage__ *optlist* ?*usage*?

    Generates and returns an error message that lists the allowed flags\.
    *optlist* is defined as for __::cmdline::getoptions__\. The optional
    *usage*\-argument contains a string to include in front of the generated
    message\. If not present it defaults to "options:"\.

  - <a name='6'></a>__::cmdline::getfiles__ *patterns* *quiet*

    Given a list of file *patterns* this command computes the set of valid
    files\. On windows, file globbing is performed on each argument\. On Unix,
    only file existence is tested\. If a file argument produces no valid files, a
    warning is optionally generated \(set *quiet* to true\)\.

    This code also uses the full path for each file\. If not given it prepends
    the current working directory to the filename\. This ensures that these files
    will never conflict with files in a wrapped zip file\. The last sentence
    refers to the pro\-tools\.

  - <a name='7'></a>__::cmdline::getArgv0__

    This command returns the "sanitized" version of *argv0*\. It will strip off
    the leading path and removes the extension "\.bin"\. The latter is used by the
    TclPro applications because they must be wrapped by a shell script\.

## <a name='subsection1'></a>Error Codes

Starting with version 1\.5 all errors thrown by the package have a proper
__::errorCode__ for use with Tcl's __[try](\.\./try/tcllib\_try\.md)__
command\. This code always has the word __CMDLINE__ as its first element\.

# <a name='section4'></a>EXAMPLES

## <a name='subsection2'></a>cmdline::getoptions

This example, taken from the package
__[fileutil](\.\./fileutil/fileutil\.md)__ and slightly modified,
demonstrates how to use __cmdline::getoptions__\. First, a list of options is
created, then the 'args' list is passed to cmdline for processing\. Subsequently,
different options are checked to see if they have been passed to the script, and
what their value is\.

            package require Tcl 8.5
            package require try         ;# Tcllib.
            package require cmdline 1.5 ;# First version with proper error-codes.

            # Notes:
            # - Tcl 8.6+ has 'try' as a builtin command and therefore does not
            #   need the 'try' package.
            # - Before Tcl 8.5 we cannot support 'try' and have to use 'catch'.
            #   This then requires a dedicated test (if) on the contents of
            #   ::errorCode to separate the CMDLINE USAGE signal from actual errors.

            set options {
                {a          "set the atime only"}
                {m          "set the mtime only"}
                {c          "do not create non-existent files"}
                {r.arg  ""  "use time from ref_file"}
                {t.arg  -1  "use specified time"}
            }
            set usage ": MyCommandName \[options] filename ...\noptions:"

            try {
                array set params [::cmdline::getoptions argv $options $usage]

    	    # Note: argv is modified now. The recognized options are
    	    # removed from it, leaving the non-option arguments behind.
            } trap {CMDLINE USAGE} {msg o} {
                # Trap the usage signal, print the message, and exit the application.
                # Note: Other errors are not caught and passed through to higher levels!
    	    puts $msg
    	    exit 1
            }

            if {  $params(a) } { set set_atime "true" }
            set has_t [expr {$params(t) != -1}]
            set has_r [expr {[string length $params(r)] > 0}]
            if {$has_t && $has_r} {
                return -code error "Cannot specify both -r and -t"
            } elseif {$has_t} {
    	    ...
            }

## <a name='subsection3'></a>cmdline::getopt

This example shows the core loop of __cmdline::getoptions__ from the
previous example\. It demonstrates how it uses __cmdline::get__ to process
the options one at a time\.

        while {[set err [getopt argv $opts opt arg]]} {
    	if {$err < 0} {
                set result(?) ""
                break
    	}
    	set result($opt) $arg
        }

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *cmdline* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[argument processing](\.\./\.\./\.\./\.\./index\.md\#argument\_processing),
[argv](\.\./\.\./\.\./\.\./index\.md\#argv), [argv0](\.\./\.\./\.\./\.\./index\.md\#argv0),
[cmdline processing](\.\./\.\./\.\./\.\./index\.md\#cmdline\_processing), [command
line processing](\.\./\.\./\.\./\.\./index\.md\#command\_line\_processing)

# <a name='category'></a>CATEGORY

Programming tools
