# et:ts=4
# port.tcl
#
# Copyright (c) 2002 Apple Inc.
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
# 3. Neither the name of Apple Inc. nor the names of its contributors
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
# standard package load
package provide port 1.0

# catch wrapper shared with macports1.0
# aliasing it in doesn't work right because of uplevel use
package require mpcommon 1.0

# Provide a callback registration mechanism for port subpackages. This needs to
# be done _before_ loading the subpackages.
namespace eval port {
	variable _callback_list [list]

	# Append a new procedure to a list of callbacks to be called when
	# port::run_callbacks is called from macports1.0 after evaluating
	# a Portfile
	proc register_callback {callback} {
		variable _callback_list
		lappend _callback_list ${callback}
	}

	# Run the callbacks registered in the callback list. Called from
	# macports1.0 in the child interpreter after evaluating the Portfile and
	# the variants. Clears the list of callbacks.
	proc run_callbacks {} {
		variable _callback_list
		foreach callback ${_callback_list} {
			ui_debug "Running callback ${callback}"
			${callback}
			ui_debug "Finished running callback ${callback}"
		}
		set _callback_list [list]
	}
}

package require mp_package 1.0
package require portmain 1.0
package require portdepends 1.0
package require portfetch 1.0
package require portchecksum 1.0
package require portextract 1.0
package require portpatch 1.0
package require portconfigure 1.0
package require portbuild 1.0
package require portdestroot 1.0
package require portinstall 1.0
package require portuninstall 1.0
package require portactivate 1.0
package require portdeactivate 1.0
package require portclean 1.0
package require porttest 1.0
package require portlint 1.0
package require porttrace 1.0
package require portdistcheck 1.0
package require portlivecheck 1.0
package require portmirror 1.0
package require portbump 1.0

package require portstartupitem 1.0
package require portload 1.0
package require portunload 1.0
package require portreload 1.0

package require portdistfiles 1.0
package require portsandbox 1.0
