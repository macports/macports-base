# et:ts=4
# port.tcl
#
# Copyright (c) 2002 Apple Computer, Inc.
# Copyright (c) 2004 Paul Guyot, DarwinPorts Team.
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
#
# port1.0 is built around the notion of state and the notion of operation.
# operations are transitions between states, although one operation can lead
# to various transitions depending on the original state (however, for a given
# state, an operation, if successful, only leads to one state).
#
# There actually are two different set of states, dependent but not as if they
# were part of a single state machine.
#
# The first set of states is the work set of states. The states are the
# following:
# - cleaned
# - fetched
# - extracted
# - patched
# - configured
# - built
# - destrooted
#
# The state is written in the state file in the work directory. If this file
# doesn't exist or if the work directory doesn't exist, the port is known to be
# in the cleaned state.
#
# The second set of states is the registry set of states. The states are the
# following:
# - uninstalled
# - installed
# - activated
#
# Operations require that the port is in a given 
#
# standard package load
package provide port 1.0

package require dp_package 1.0
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
package require portactivate 1.0
package require portdistclean 1.0
package require portclean 1.0
package require porttest 1.0
package require portsubmit 1.0
