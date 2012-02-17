# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:filetype=tcl:et:sw=4:ts=4:sts=4
# portmain.tcl
# $Id$
#
# Copyright (c) 2004 - 2005, 2007 - 2011 The MacPorts Project
# Copyright (c) 2002 - 2003 Apple Inc.
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

# the 'main' target is provided by this package
# main is a magic target and should not be replaced

package provide portmain 1.0
package require portutil 1.0

set org.macports.main [target_new org.macports.main portmain::main]
target_provides ${org.macports.main} main
target_state ${org.macports.main} no

namespace eval portmain {
}

set_ui_prefix

# define options
options prefix name version revision epoch categories maintainers \
        long_description description homepage notes license \
        provides conflicts replaced_by \
        worksrcdir filesdir distname portdbpath libpath distpath sources_conf \
        os.platform os.subplatform os.version os.major os.arch os.endian \
        platforms default_variants install.user install.group \
        macosx_deployment_target universal_variant os.universal_supported \
        supported_archs depends_skip_archcheck installs_libs \
        license_noconflict copy_log_files \
        compiler.cpath compiler.library_path \
        add_users

# Order of option_proc and option_export matters. Filter before exporting.

# Assign option procedure to default_variants
option_proc default_variants handle_default_variants
# Handle notes special for better formatting
option_proc notes handle_option_string

# Export options via PortInfo
options_export name version revision epoch categories maintainers platforms description long_description notes homepage license provides conflicts replaced_by installs_libs license_noconflict

default subport {[portmain::get_default_subport]}
proc portmain::get_default_subport {} {
    global name portpath
    if {[info exists name]} {
        return $name
    }
    return [file tail $portpath]
}
default subbuildpath {[portmain::get_subbuildpath]}
proc portmain::get_subbuildpath {} {
    global portpath portbuildpath subport
    if {$subport != ""} {
        set subdir $subport
    } else {
        set subdir [file tail $portpath]
    }
    return [file join $portbuildpath $subdir]
}
default workpath {[getportworkpath_from_buildpath $subbuildpath]}
default prefix /opt/local
default applications_dir /Applications/MacPorts
default frameworks_dir {${prefix}/Library/Frameworks}
default developer_dir {[portmain::get_developer_dir]}
default destdir destroot
default destpath {${workpath}/${destdir}}
# destroot is provided as a clearer name for the "destpath" variable
default destroot {${destpath}}
default filesdir files
default revision 0
default epoch 0
default license unknown
default distname {${name}-${version}}
default worksrcdir {$distname}
default filespath {[file join $portpath $filesdir]}
default worksrcpath {[file join $workpath $worksrcdir]}
# empty list means all archs are supported
default supported_archs {}
default depends_skip_archcheck {}
default add_users {}

# Configure settings
default install.user {${portutil::autoconf::install_user}}
default install.group {${portutil::autoconf::install_group}}

# Platform Settings
default os.platform {$os_platform}
default os.version {$os_version}
default os.major {$os_major}
default os.arch {$os_arch}
default os.endian {$os_endian}

set macosx_version_text {}
if {[option os.platform] == "darwin"} {
    set macosx_version_text "(Mac OS X ${macosx_version}) "
}
ui_debug "OS [option os.platform]/[option os.version] ${macosx_version_text}arch [option os.arch]"

default universal_variant {${use_configure}}

# sub-platforms of darwin
if {[option os.platform] == "darwin"} {
    if {[file isdirectory /System/Library/Frameworks/Carbon.framework]} {
        default os.subplatform macosx
        # we're on Mac OS X and can therefore build universal
        default os.universal_supported yes
    } else {
        default os.subplatform puredarwin
        default os.universal_supported no
    }
} else {
    default os.subplatform {}
    default os.universal_supported no
}

default compiler.cpath {${prefix}/include}
default compiler.library_path {${prefix}/lib}


proc is_valid_developer_dir { dir } {
	# Check whether specified directory looks valid for an Xcode installation
	
	# Verify that the directory exists
	if {![file isdirectory $dir]} {
		return 0
	}
	
	# Verify that the directory has some key subdirectories
	foreach subdir {Headers Library usr} {
		if {![file isdirectory "${dir}/${subdir}"]} {
			return 0
		}
	}
	
	# The specified directory seems valid for Xcode
	return 1
}


proc get_xcode_suggestions {} {
	# Ask mdfind where Xcode is
	set result ""
    if {![catch {set mdfind [binaryInPath mdfind]}]} {
    	set result [exec $mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'"]
	}
	return $result
}


proc portmain::get_developer_dir {} {
	set devdir ""

	# Look for xcodeselect, and make sure it has a valid value
    if {![catch {set xcodeselect [binaryInPath xcode-select]}]} {
		
		# We have xcodeselect: ask it where xcode is
    	set devdir [exec $xcodeselect -print-path 2> /dev/null]

		# If the the directory is valid, use it
    	if {[is_valid_developer_dir $devdir]} {
    		return $devdir
    	}
    	
    	# The directory from xcodeselect isn't correct.
    	# Make some suggestions for the user
    	set installed_xcodes [get_xcode_suggestions]
    	if {[llength $installed_xcodes] == 0} {
    		# No installed Xcodes found
    		ui_error "No Xcode installation was found; please install Xcode"
    	} else {
    		# One, or more than one, Xcode installations found
    		ui_error "No valid Xcode installation is properly selected"
    		
    		ui_error
    		ui_error "Please use xcode-select to select an Xcode version:"
    		foreach xcode $installed_xcodes {
    			ui_error "    sudo xcode-select -switch ${xcode}"
    		}
    		ui_error
    	}
    }
    
    # xcode-select wasn't found, look for Xcode at /Developer
    set devdir "/Developer"
    if {[is_valid_developer_dir $devdir]} {
    	return $devdir
    }
    
    ui_error
	ui_error "No valid Xcode installation was found: please install Xcode"
    ui_error
    
    # We return /Developer here even though we know it's wrong. Abort instead?
    return "/Developer"
}

# start gsoc08-privileges

# Record initial euid/egid
set euid [geteuid]
set egid [getegid]

# resolve the alternate work path in ~/.macports
proc portmain::set_altprefix {} {
    global altprefix env euid

    # do tilde expansion manually - Tcl won't expand tildes automatically for curl, etc.
    if {[info exists env(HOME)]} {
        # HOME environment var is set, use it.
        set userhome "$env(HOME)"
    } elseif {$euid == 0 && [info exists env(SUDO_USER)] && $env(SUDO_USER) != ""} {
        set userhome [file normalize "~$env(SUDO_USER)"]
    } else {
        # the environment var isn't set, expand ~user instead
        set username [uid_to_name [getuid]]
        if {[catch {set userhome [file normalize "~$username"]}]} {
            set userhome ""
        }
    }

    set altprefix [file join $userhome .macports]
}

# if unable to write to workpath, implies running without either root privileges
# or a shared directory owned by the group so use ~/.macports
portmain::set_altprefix
if { $euid != 0 && (([info exists workpath] && [file exists $workpath] && ![file writable $workpath]) || ([info exists portdbpath] && ![file writable [file join $portdbpath build]])) } {

    # set global variable indicating to other functions to use ~/.macports as well
    set usealtworkpath yes

    default worksymlink {[file join ${altprefix}${portpath} work]}
    default distpath {[file join ${altprefix}${portdbpath} distfiles ${dist_subdir}]}
    set portbuildpath "${altprefix}${portbuildpath}"

    ui_debug "Going to use alternate build prefix: $altprefix"
    ui_debug "workpath = $workpath"
} else {
    set usealtworkpath no
    default worksymlink {[file join $portpath work]}
    default distpath {[file join $portdbpath distfiles ${dist_subdir}]}
}

# end gsoc08-privileges

proc portmain::main {args} {
    return 0
}
