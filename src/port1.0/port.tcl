# et:ts=4
# port.tcl
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
# standard package load
package provide port 1.0

#package require portmain 1.0
#package require portdepends 1.0
#package require portfetch 1.0
#package require portchecksum 1.0
#package require portextract 1.0
#package require portpatch 1.0
#package require portconfigure 1.0
#package require portbuild 1.0
#package require portinstall 1.0
#package require portuninstall 1.0
#package require portregistry 1.0
#package require portclean 1.0
#package require portpackage 1.0
#package require portcontents 1.0
#package require portmpkg 1.0

##### Port API #####

package require portutil 1.0

proc tname {ditem args} {
	ditem_key $ditem name [lindex $args 0] 
}

# Load the targets in their own sub interpreters
# XXX: this should dynamically discover targets from a list of target paths

proc porthooks {ditem} {
    # Register the pre-/post- hooks for use in Portfile.
    # Portfile syntax: pre-fetch { puts "hello world" }
    # User-code exceptions are caught and returned as a result of the target.
    # Thus if the user code breaks, dependent targets will not execute.
    foreach target [ditem_key $ditem provides] {
		#set origproc [ditem_key $ditem procedure]
	
		set requires [ditem_key $ditem requires]
		if {[llength $requires] == 0} { set requires {{}} }
		set uses [ditem_key $ditem uses]
		set runtype [ditem_key $ditem runtype]
		
		if {[llength $uses] == 0} { set uses {{}} }
		
		if {[info commands $target] == ""} {
			eval "proc $target \{args\} \{ \n\
				make_custom_target $target \{$requires\} \{$uses\} \"\" \$args \n\
			\}"
			
	# XXX: eval \"proc do-$target \{\} \{ $origproc $target\}\"
	
			eval "proc pre-${target} \{args\} \{ \n\
				set new_target \[make_custom_target pre-${target} \{$requires\} \{$uses\} \"$runtype\" \$args\] \n\
				#global targets \n\
				#set dlist \[dlist_search \$targets provides ${target}\] \n\
				#foreach ditem \$dlist \{ \n\
				#	if \{\$ditem == \$new_target\} \{ continue \}
				#	ui_debug \"making \[ditem_key \$ditem name\] require pre-${target}\" \n\
				#	ditem_append \$ditem requires pre-${target} \n\
				#\} \n\
			\}"
	
			eval "proc post-${target} \{args\} \{ \n\
				set new_target \[make_custom_target post-${target} $target \{$uses\} \"$runtype\" \$args\] \n\
				#global targets \n\
				#set dlist \[dlist_search \$targets requires ${target}\] \n\
				#foreach ditem \$dlist \{ \n\
				#	if \{\$ditem == \$new_target\} \{ continue \}
				#	ui_debug \"making \[ditem_key \$ditem name\] require post-${target}\" \n\
				#	ditem_append \$ditem requires post-${target} \n\
				#\} \n\
			\}"
		}
	}
}

proc noop {args} {}

proc portinit {} {
	foreach target_file {portmain.tcl portbuild.tcl portpatch.tcl portconfigure.tcl portinstall.tcl portclean.tcl portpackage.tcl portdestroot.tcl portdeploy.tcl portdistfiles.tcl portdistcache.tcl portcurl.tcl portwget.tcl portmd5.tcl portgzip.tcl} {
#	ui_debug "loading $target_file"
		set ditem [target_new $target_file main]
		set worker [interp create]
		ditem_key $ditem worker $worker
		
		$worker eval {proc PortTarget {args} {
			package require msgcat
		}}
		
		# Target API
		$worker alias name tname $ditem
		$worker alias maintainers noop
		$worker alias description noop
		$worker alias requires target_requires $ditem
		$worker alias provides target_provides $ditem
		$worker alias uses target_uses $ditem
		$worker alias runtype target_runtype $ditem
		# XXX: deprecated
		$worker alias init target_init $ditem
		$worker alias prerun target_prerun $ditem
		$worker alias postrun target_postrun $ditem
	
		# DarwinPorts API
		$worker alias ui_msg ui_msg
		$worker alias ui_info ui_info
		$worker alias ui_warn ui_warn
		$worker alias ui_error ui_error
		$worker alias ui_debug ui_debug
	
		# Port Util API
		$worker alias option option
		$worker alias exists exists
		$worker alias options options
		$worker alias options_export options_export
		$worker alias option_proc option_proc
		$worker alias option_deprecate option_deprecate
		$worker alias default default $ditem
		$worker alias commands commands
		$worker alias command command
		$worker alias tbool tbool
		$worker alias system system
		$worker alias readdir readdir
		
		# XXX: this should have a better name
		$worker alias eval_targets eval_targets
		
		$worker alias registry_new registry_new
		$worker alias registry_store registry_store
		$worker alias registry_close registry_close
		$worker alias fileinfo_for_index fileinfo_for_index
	
		# XXX: use the targetpath variable
		$worker eval source [file join /opt/local/share/darwinports/Tcl/port1.0 $target_file]
		
		# Set up the override, pre-, post- hooks.
		porthooks $ditem
	}
}
