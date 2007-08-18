# et:ts=4
# registry_util.tcl
# $Id$
#
# Copyright (c) 2007 Chris Pickel
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

package provide registry_util 2.0

package require registry2 2.0

namespace eval registry {

## Decodes a version specifier into its component values. Values will be
## returned into the variables named by `version`, `revision`, and `variants`,
## with `revision` and `variants` possibly being set to the empty string if none
## were specified.
##
## This accept a full specifier such as `1.2.1_3+cool-lame` (to disable MP3
## support) or a bare version, such as `1.2.1`. If a revision is not specified,
## then the returned revision and variants will be empty.
##
## @param [in] specifier a specifier, as described above
## @param [out] version  name of a variable to return version into
## @param [out] revision name of a variable to return revision into
## @param [out] variants name of a variable to return variants into
## @return               true if `specifier` is a valid specifier, else false
proc decode_spec {specifier version revision variants} {
    upvar 1 $version ver $revision rev $variants var
    return [regexp {^([^-+_]+)(_([^-+]+)(([-+][^-+]+)*))?$} - ver - rev var]
}

## Checks that the given port has no dependent ports. If it does, throws an
## error if force wasn't set (emits a message if it is).
##
## @param [in] port  a registry::entry to check
## @param [in] force if true, continue even if there are dependents
proc check_dependents {port force} {
    # Check and make sure no ports depend on this one
    set deplist [$port dependents]
    if { [llength $deplist] > 0 } {
        ui_msg "$UI_PREFIX [format [msgcat::mc "Unable to uninstall %s %s_%s%s, the following ports depend on it:"] $portname $version $revision $variants]"
        foreach depport $deplist {
            ui_msg "$UI_PREFIX [format [msgcat::mc "	%s"] $depport]"
        }
        if { [string is true $force] } {
            ui_warn "Uninstall forced.  Proceeding despite dependencies."
        } else {
            throw registry::uninstall-error "Please uninstall the ports that depend on $portname first."
        }
    }
}

}
