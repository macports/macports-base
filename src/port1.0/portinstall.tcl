# et:ts=4
# portinstall.tcl
# $Id: portinstall.tcl,v 1.78.6.18 2006/02/20 14:56:58 olegb Exp $
#
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
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

package provide portinstall 1.0
package require portutil 1.0

set com.apple.install [target_new com.apple.install install_main]
target_state ${com.apple.install} no
target_provides ${com.apple.install} install
if { [info exists ports_binary_only] && $ports_binary_only == "yes" } {
	target_requires ${com.apple.install} main
} else {
	target_requires ${com.apple.install} main fetch extract checksum patch configure build destroot rpmpackage
}

proc install_main {args} {
	global portname portversion portpath categories description long_description homepage depends_run installPlist package-install uninstall workdir worksrcdir pregrefix UI_PREFIX destroot portrevision maintainers ports_force portvariants targets depends_lib PortInfo epoch prefix pkg_server ports_binary_only workpath

	# Map portname to suit RPM-ification
	set rpmportname [string map {- _} $portname]
	set portversion [string map {- _} $portversion]

	set arch [option os.arch]
	if {$arch eq "powerpc"} {
		set arch "ppc"
	}

	set distfile ${rpmportname}-${portversion}-${portrevision}.${arch}.rpm

	# Check if we have the package 
	set havepackage no
	if { [file exist [file join ${prefix}/src/apple/RPMS/${arch} ${distfile}]] } {
		ui_debug "Package ${distfile} present.."
		set havepackage yes
	}

	# If we want binary packages
	if { [info exists ports_binary_only] && $ports_binary_only == "yes" && $havepackage == "no" } {
		# Fetch the file $rpmportname-$portversion-$portrevision.$arch.rpm from $pkg_server 
		set fetched 0

		ui_msg "Using these package servers: ${pkg_server}"

		foreach site ${pkg_server} {

			ui_msg "$UI_PREFIX [format [msgcat::mc "Attempting to fetch %s from %s"] $distfile $site]"
			set file_url [portfetch::assemble_url $site $distfile]
			if {![catch {eval curl fetch {$file_url} ${prefix}/src/apple/RPMS/${arch}/${distfile}.TMP} result] && ![catch {system "mv ${prefix}/src/apple/RPMS/${arch}/${distfile}.TMP ${prefix}/src/apple/RPMS/${arch}/${distfile}"}]} {
				set fetched 1
				break
			}
		} 

		if {$fetched != 1} {
			# fetch failed
			ui_debug "[msgcat::mc "Fetching failed:"]: $result"
			exec rm -f ${prefix}/share/apple/RPMS/${arch}/{distfile}.TMP

			# XXX Not nice
			file delete -force ${workpath}/.darwinports.${portname}.state

			# Build our own rpmpackage
			dportinit ui_options options variation
			if {[catch {dportsearch $portname no exact} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				ui_error "port search failed: $result"
				return 1
			}
			# argh! port doesnt exist!
			if {$result == ""} {
				ui_error "No port $portname found."
				return 1
			}
			# fill array with information
			array set portinfo [lindex $result 1]

			# open porthandle    
			set porturl $portinfo(porturl)
			if {![info exists porturl]} {
				set porturl file://./    
			}    

			if {[catch {set workername [dportopen $porturl [array get options] ]} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				ui_error "Unable to open port: $result"        
				return 1
			}

			if {[catch {set result [dportexec $workername rpmpackage]} result]} {
				global errorInfo
				ui_debug "$errorInfo"
				ui_error "Unable to exec port: $result"
				return 1
			}
		}
	}

	ui_msg "$UI_PREFIX [format [msgcat::mc "Installing package: %s-%s-%s"] ${portname} ${portversion} ${portrevision}]"

	system "rpm -ivh --nodeps ${prefix}/src/apple/RPMS/${arch}/${rpmportname}-${portversion}-${portrevision}.${arch}.rpm"

    return 0
}
