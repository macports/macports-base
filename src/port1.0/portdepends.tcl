# ex:ts=4
# portdepends.tcl
#
# Copyright (c) 2002 Apple Computer, Inc.
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

# the 'main' target is provided by this package
# main is a magic target and should not be replaced

package provide portdepends 1.0
package require portutil 1.0

# define options
options depends_fetch depends_build depends_run depends_extract depends_lib
# Export options via PortInfo
options_export depends_lib depends_run

option_proc depends_fetch handle_depends_options
option_proc depends_build handle_depends_options
option_proc depends_run handle_depends_options
option_proc depends_extract handle_depends_options
option_proc depends_lib handle_depends_options

proc handle_depends_options {option action args} {
	global targets
	switch -regex $action {
		set|append {
			foreach depspec $args {
				if {[regexp {([A-Za-z\./0-9]+):([A-Za-z0-9\-\.$^\?\+\(\)\|\\]+):([A-Za-z\./0-9]+)} "$depspec" match deppath depregex portname] == 1} {
					switch $deppath {
						lib { set obj [libportfile_new $portname $depregex] }
						bin { set obj [binportfile_new $portname $depregex] }
						default { ui_error "unknown depspec type: $deppath" }
					}
					if {[info exists obj]} {
						$obj append provides $option portfile-$portname 
						lappend targets $obj
						foreach obj [depspec_get_matches $targets deplist $option] {
							$obj append requires portfile-$portname
						}
					}
				}
			}
		}
		delete {
			# xxx: need to delete requirement from each item in the deplist
		}
	}
}
