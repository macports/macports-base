# et:ts=4
# portportpkg.tcl
# $Id$
#
# Copyright (c) 2002 - 2004 Apple Inc.
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

package provide portportpkg 1.0
package require portutil 1.0

set org.macports.portpkg [target_new org.macports.portpkg portportpkg::portpkg_main]
target_runtype ${org.macports.portpkg} always
target_provides ${org.macports.portpkg} portpkg 
target_requires ${org.macports.portpkg} main

namespace eval portportpkg {
}

set_ui_prefix


proc portportpkg::xar_path {args} {
	global prefix_frozen
    set xar ""
    foreach path "${portutil::autoconf::xar_path} ${prefix_frozen}/bin/xar xar" {
 	if { [file executable ${path}] } {
 	   	  set xar $path
 	      break;
 	}
    }
    if { "${xar}" == "" } {
    	ui_error "The xar tool is required to make portpkgs"
    	ui_error "Please install the xar port before proceeding."
		return -code error [msgcat::mc "Portpkg failed"]
    }
    
    return $xar
}


# escape quotes, and things that make the shell cry
proc portportpkg::shell_escape {str} {
	regsub -all -- {\\} $str {\\\\} str
	regsub -all -- {"} $str {\"} str
	regsub -all -- {'} $str {\'} str
	return $str
}


proc portportpkg::putel { fd el data } {
	# Quote xml data
	set quoted [string map  { & &amp; < &lt; > &gt; } $data]
	# Write the element
	puts $fd "<${el}>${quoted}</${el}>"
}


proc portportpkg::putlist { fd listel itemel list } {
	puts $fd "<$listel>"
	foreach item $list {
		putel $fd $itemel $item
	}
	puts $fd "</$listel>"
}


proc portportpkg::create_portpkg {} {
    global name prefix UI_PREFIX workpath portpath

	set xar [xar_path]
	
    set dirname "portpkg"
    set dirpath "${workpath}/${dirname}"
    set pkgpath "${workpath}/${name}.portpkg"
    set metaname "portpkg_meta.xml"
    set metapath "${workpath}/${metaname}"
    
    # Expose and default some global variables
    set vars " maintainers categories description \
    	long_description master_sites homepage epoch version revision \
    	PortInfo \
    	submitter_name submitter_email submitter_key \
    	"
	eval "global $vars"
	foreach var $vars {
		if {![info exists $var]} { set $var {} }
	}
	
	# Unobscure the maintainer addresses
	set maintainers [unobscure_maintainers $maintainers]

    # Make sure our workpath is clean
    file delete -force $dirpath $metapath $pkgpath
    
    # Create the portpkg directory
    file mkdir $dirpath

    # Move in the Portfile
    file copy Portfile ${dirpath}
    
    # Move in files    
    if {[file isdirectory "files"]} {
        file copy files ${dirpath}
    }
    
    # Create the metadata subdoc
    set sd [open ${metapath} w]
    puts $sd "<portpkg version='1'>"
    
		puts $sd "<submitter>"
			putel $sd name $submitter_name
			putel $sd email $submitter_email
			
			# TODO provide means to set notes?
			putel $sd notes ""
		puts $sd "</submitter>"
		
		puts $sd "<package>"
			putel $sd name $name
			putel $sd homepage $homepage
			putlist $sd categories category $categories
			putlist $sd maintainers maintainer $maintainers
			
			putel $sd epoch $epoch
			putel $sd version $version
			putel $sd revision $revision
			
			putel $sd description [join $description]
			putel $sd long_description [join $long_description]
		
			# TODO: variants has platforms in it
			if {[info exists PortInfo(variants)]} {
				if {[info exists PortInfo(variant_desc)]} {
					array set descs $PortInfo(variant_desc)
				} else {
					array set descs ""
				}
	
				puts $sd "<variants>"
				foreach v $PortInfo(variants) {
					puts $sd "<variant>"
						putel $sd name $v
						if {[info exists descs($v)]} {
							putel $sd description $descs($v)
						}
					puts $sd "</variant>"
				}
				puts $sd "</variants>"
			} else {
				putel $sd variants ""
			}
			
			# TODO: Dependencies and platforms
			#putel $sd dependencies ""
			#putel $sd platforms ""
			
		puts $sd "</package>"
		
    puts $sd "</portpkg>"
    close $sd
    
    # Create portpkg.xar, including the metadata and the portpkg directory contents
    set cmd "cd ${workpath}; ${xar} -cf ${pkgpath} --exclude \\.DSStore --exclude \\.svn ${dirname} -s ${metapath} -n ${metaname}"
    if {[system $cmd] != ""} {
		return -code error [format [msgcat::mc "Failed to create portpkg for port : %s"] $name]
    }
    
    return ${pkgpath}
}


proc portportpkg::portpkg_main {args} {
    global name version portverbose prefix UI_PREFIX workpath portpath
    
    ui_msg "$UI_PREFIX [format [msgcat::mc "Creating portpkg for %s-%s"] ${name} ${version}]"

    # Make sure we have a work directory
    file mkdir ${workpath}
  
    # Create portpkg.xar in the work directory
    set pkgpath [create_portpkg]
 
    return 0
}
