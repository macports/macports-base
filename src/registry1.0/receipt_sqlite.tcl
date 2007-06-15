# receipt_sqlite.tcl
# $Id$
#
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

package provide receipt_sqlite 1.0

package require macports 1.0

##
# Receipts Code supporting flat-files
##
namespace eval receipt_sqlite {

# receipt_list will hold a reference to each "receipt" that is currently open
variable receipt_list
namespace export receipt_list

# Create a new entry and place it in the receipt_list
proc new_entry {} {
	return -1
}

# Open an existing entry and place it in the receipt_list
proc open_entry {name {version 0} {revision 0} {variants ""}} {
	return -1
}

# Write an entry from the receipt_list
proc write_entry {ref name version {revision 0} {variants ""}} {
	return -1
}

# Check to see if an entry exists
proc entry_exists {name version {revision 0} {variants ""}} {
	return -1
}

# Store a property to a receipt current in the receipt_list
proc property_store {ref property value} {
	return -1
}

# Retrieve a property from a receipt currently in the receipt_list
proc property_retrieve {ref property} {
	return -1
}

# Delete an entry
proc delete_entry {name version {revision 0} {variants ""}} {
	return -1
}

# Return all installed ports
proc installed {{name ""} {version ""}} {
	return -1
}

# Return whether a file is registered to a port
proc file_registered {file} {
	return -1
}

# End of receipt_flat namespace
}

