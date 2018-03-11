# textutil.tcl --
#
#	Utilities for manipulating strings, words, single lines,
#	paragraphs, ...
#
# Copyright (c) 2000      by Ajuba Solutions.
# Copyright (c) 2000      by Eric Melski <ericm@ajubasolutions.com>
# Copyright (c) 2002      by Joe English <jenglish@users.sourceforge.net>
# Copyright (c) 2001-2006 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: textutil.tcl,v 1.17 2006/09/21 06:46:24 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.2

namespace eval ::textutil {}

# ### ### ### ######### ######### #########
## API implementation
## All through sub-packages imported here.

package require textutil::string
package require textutil::repeat
package require textutil::adjust
package require textutil::split
package require textutil::tabify
package require textutil::trim

namespace eval ::textutil {
    # Import the miscellaneous string command for public export

    namespace import -force string::chop string::tail
    namespace import -force string::cap string::uncap string::capEachWord
    namespace import -force string::longestCommonPrefix
    namespace import -force string::longestCommonPrefixList

    # Import the repeat commands for public export

    namespace import -force repeat::strRepeat repeat::blank

    # Import the adjust commands for public export

    namespace import -force adjust::adjust adjust::indent adjust::undent

    # Import the split commands for public export

    namespace import -force split::splitx split::splitn

    # Import the trim commands for public export

    namespace import -force trim::trim trim::trimleft trim::trimright
    namespace import -force trim::trimPrefix trim::trimEmptyHeading

    # Import the tabify commands for public export

    namespace import -force tabify::tabify tabify::untabify
    namespace import -force tabify::tabify2 tabify::untabify2

    # Re-export all the imported commands

    namespace export chop tail cap uncap capEachWord
    namespace export longestCommonPrefix longestCommonPrefixList
    namespace export strRepeat blank
    namespace export adjust indent undent
    namespace export splitx splitn
    namespace export trim trimleft trimright trimPrefix trimEmptyHeading
    namespace export tabify untabify tabify2 untabify2
}


# ### ### ### ######### ######### #########
## Ready

package provide textutil 0.8
