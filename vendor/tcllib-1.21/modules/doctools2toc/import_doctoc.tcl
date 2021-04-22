# doctoc.tcl --
#
#	The doctoc import plugin. Bridge between import management and
#	the parsing of doctoc markup.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: import_doctoc.tcl,v 1.3 2009/11/15 05:50:03 andreas_kupries Exp $

# This package is a plugin for the the doctools::toc v2 system.  It
# takes text in docidx format and produces the list serialization of a
# table of contents.

# ### ### ### ######### ######### #########
## Requisites

# @mdgen NODEP: doctools::toc::import::plugin

package require Tcl 8.4
package require doctools::toc::import::plugin ; # The presence of this
						# pseudo package
						# indicates execution
						# of this code inside
						# of an interpreter
						# which was properly
						# initialized for use
						# by import plugins.
package require doctools::toc::parse          ; # The actual doctoc
						# parser used by the
						# plugin.

# ### ### ### ######### ######### #########

## We redefine the command 'doctools::toc::parse::GetFile' to use the
## 'include' alias provided by the plugin manager, as reguar file
## commands are not allowed in this 'safe' environment. However this
## is done if and only if we truly are in the plugin environment. The
## testsuite, for example, will leave out the definition of 'include',
## signaling in this way that the regular file operations can still be
## used.

if {[llength [info commands include]]} {

    # Note: We are poking directly into the implementation of the
    #       class. Any changes to the interface here have to reviewed
    #       for their impact on doctools::toc::parse, and possibly
    #       ported over.

    proc ::doctools::toc::parse::GetFile {currentfile path dv pv ev mv} {
	upvar 1 $dv data $pv fullpath $ev error $mv emessage
	foreach {ok data fullpath error emessage} [include $currentfile $path] break
	return $ok
    }
}

# ### ### ### ######### ######### #########
## API :: Convert text to canonical toc serialization.

proc import {text configuration} {
    global errorInfo errorCode

    doctools::toc::parse var load $configuration

    # Could be done better using a try/finally
    set code [catch {
	doctools::toc::parse text $text
    } serial]

    # Save error state if there was any.
    set ei $errorInfo
    set ec $errorCode

    # Cleanup parser configuration, regardless of errors or not.
    doctools::toc::parse var unset *

    # Rethrow any error, using the captured state.
    if {$code} {
	return -code $code -errorinfo $ei -errorcode $ec $serial
    }

    return $serial
}

# ### ### ### ######### ######### #########
## Ready

package provide doctools::toc::import::doctoc 0.1
return
