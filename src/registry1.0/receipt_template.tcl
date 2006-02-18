# registry.tcl
#
# Copyright (c) 2006 Ole Guldberg Jensen <olegb@opendarwin.org>
# Copyright (c) 2004 Will Barton <wbb4@opendarwin.org>
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

package provide receipt_ 1.0

package require darwinports 1.0

namespace eval receipt_ {

# Check to see if an entry exists in the registry.  This is passed straight 
# through to the receipts system
proc entry_exists {name version {revision 0} {variants ""}} {
}

# If only one version of the port is installed, this process returns that
# version's parts.  Otherwise, it lists the versions installed and exists.
proc installed {{name ""} {version ""}} {
}

proc location {portname portversion} {
}	

proc file_registered {file} {
}

proc port_registered {name} {
}

# List all dependencies for this port
proc list_depends {name} {
}

# Return a list of *all* ports that $name depends on (recurse)
proc rdeps {name} {
}

# pretty deps
proc pdeps {portname} {
}

# List all the ports that depend on this port
proc list_dependents {name} {
}

# Verifies an installed port
proc verify {name} {
}

# End of registry namespace
}

