# et:ts=4
# zope-1.0.tcl
#
# $Id: zope-1.0.tcl,v 1.5 2004/09/24 20:33:59 rshaw Exp $
# 
# Group file for 'zope' group.
#
# Copyright (c) 2004 Robert Shaw <rshaw@opendarwin.org>
# Copyright (c) 2002 Apple Computer, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Computer, Inc. nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# Set some variables.
set python.bin	${prefix}/bin/python2.3
set python.lib	${prefix}/lib/python2.3

set zope.home		${prefix}/libexec/Zope
set zope.softhome	${zope.home}/lib/python
set zope.prodhome	${zope.softhome}/Products
set zope.insthome	${prefix}/www/Zope
set zope.exthome	${zope.insthome}/Extensions

set zope.user	zope
set zope.group	www

# Zope group options
options zope.need_subdir
default zope.need_subdir yes
option_proc zope.need_subdir zope.fix_extract_dir

options zope.need_cvsdir
default zope.need_cvsdir yes
option_proc zope.need_cvsdir zope.fix_cvs_dir

# Zope group default for extract.dir & cvs.dir is different
default extract.dir {${worksrcpath}}
default cvs.dir {${worksrcpath}}

# define this empty initially, it is set by zope.setup arguments
set zope.product ""
set zope.products {}
set zope.extensions {}

# Zope group setup procedure
proc zope.setup {product vers {products {}} {extensions {}}} {
	global workpath worksrcpath
	global python.bin python.lib
	global zope.home zope.softhome zope.prodhome zope.insthome zope.exthome
	global zope.user zope.group
	global zope.product zope.products zope.extensions zope.need_subdir

	# define zope.product & zope.products & zope.extensions
	set zope.product ${product}
	if {[llength $products] > 0} {
		set zope.products ${products}
		zope.need_subdir no
	} else {
		set zope.products "${product}"
	}
	if {[llength $extensions] > 0} {
		if {[llength $products] == 0} {
			set zope.products {}
		}
		set zope.extensions ${extensions}
	}

	name			zope-[string tolower ${zope.product}]
	version			${vers}
	categories		www zope python

	distname		${zope.product}-${vers}
	dist_subdir		zope

	depends_lib		path:${zope.home}/bin/compilezpy.py:zope

	platform freebsd {
		extract.post_args	| gtar -xf -
	}

	pre-extract {
		if {[tbool zope.need_subdir]} {
			ui_debug "mkdir: ${worksrcpath}"
			file mkdir ${worksrcpath}
		}
	}

	post-patch {
		foreach item [glob ${worksrcpath}/*] {
			if {[file isdirectory $item]} {
				set product [file tail $item]
				if {[lsearch -exact ${zope.products} $product] < 0} {
					ui_debug "rmdir: $product: $item"
					file delete -force $item
				}
			}
		}
		system "find ${worksrcpath} -name '*.py\[co\]' | xargs rm"
		system "find ${worksrcpath} -type d -name CVS | xargs rm -rf"
		system "find ${worksrcpath} -name '.#*' | xargs rm"
	}

	use_configure	no

	pre-build {
		file copy -force ${zope.home}/bin/compilezpy.py ${workpath}
		reinplace "s|^.*sys.stdout|#&|" ${workpath}/compilezpy.py
		system "find ${worksrcpath} -name '*.py\[co\]' | xargs rm"
	}
	build {
		# Precompile all product files
		system "cd ${worksrcpath} && ${python.bin} ${workpath}/compilezpy.py"
	}

	destroot {
		# Warn user if not running as root
		if {$env(USER) != "root"} {
			ui_msg "-----------------------------------------------------------"
			ui_msg "Note that you are not running as root, so files installed"
			ui_msg "by this port will not end up with proper ownership and"
			ui_msg "likely not work correctly with Zope."
			ui_msg "-----------------------------------------------------------"
		}
		cd ${worksrcpath}

		# Install product(s)
		if {[llength ${zope.products}] > 0} {
			xinstall -d -m 0755 ${destroot}${zope.prodhome}
			foreach item ${zope.products} {
				set cmd "cp -R ${item} ${destroot}${zope.prodhome}/${item}"
				ui_info ${cmd}; system ${cmd}
			}
		}

		# Install extension(s)
		if {[llength ${zope.extensions}] > 0} {
			xinstall -d -m 0755 ${destroot}${zope.exthome}
			foreach item ${zope.extensions} {
				set cmd "cp -R ${item} ${destroot}${zope.exthome}/${item}"
				ui_info ${cmd}; system ${cmd}
			}
		}

		# Fix owner and group on installed data
		if {$env(USER) == "root"} {
			if {[llength ${zope.products}] > 0} {
				set cmd "chown -R ${zope.user} ${destroot}${zope.home}"
				ui_info ${cmd}; system ${cmd}
				set cmd "chgrp -R ${zope.group} ${destroot}${zope.home}"
				ui_info ${cmd}; system ${cmd}
			}
			if {[llength ${zope.extensions}] > 0} {
				set cmd "chown -R ${zope.user} ${destroot}${zope.insthome}"
				ui_info ${cmd}; system ${cmd}
				set cmd "chgrp -R ${zope.group} ${destroot}${zope.insthome}"
				ui_info ${cmd}; system ${cmd}
			}
		}
	}
}

# define these empty initially, they are set by zope.setup_cvs arguments
set zope.cvsroot	""
set zope.cvsmodule	""
set zope.cvsdefault	""

# Zope group CVS variant setup procedure
proc zope.setup_cvs {cvsroot {module ""}} {
	global version distname workpath worksrcpath
	global zope.product
	global zope.cvsroot zope.cvsmodule zope.cvsdefault zope.need_cvsdir

	switch -glob ${cvsroot} {
		zope {
			set zope.cvsroot :pserver:anonymous@cvs.zope.org:/cvs-repository
			set zope.cvsdefault Products/${zope.product}
		}
		collective {
			set zope.cvsroot :pserver:anonymous@cvs.sourceforge.net:/cvsroot/collective
			set zope.cvsdefault ${zope.product}
		}
		sourceforge {
			set project [string tolower ${zope.product}]
			set zope.cvsroot :pserver:anonymous@cvs.sourceforge.net:/cvsroot/${project}
			set zope.cvsdefault ${zope.product}
		}
		sourceforge:* {
			set project [lindex [split ${cvsroot} {:}] 1]
			set zope.cvsroot :pserver:anonymous@cvs.sourceforge.net:/cvsroot/${project}
			set zope.cvsdefault ${zope.product}
		}
		default {
			set zope.cvsroot :pserver:${cvsroot}
			set zope.cvsdefault ${zope.product}
		}
	}
	if {[string length ${module}] == 0} {
		set zope.cvsmodule ${zope.cvsdefault}
	} else {
		set zope.cvsmodule ${module}
	}

	version		[clock format [clock seconds] -format %Y%m%d]
	distname	${zope.product}-${version}

	fetch.type	cvs
	cvs.root	${zope.cvsroot}
	cvs.module	${zope.cvsmodule}

	if {[tbool zope.need_cvsdir]} {
		cvs.args	-d ${zope.product}
		cvs.dir		${worksrcpath}
	} else {
		cvs.args	-d ${distname}
	}
	pre-fetch {
		if {[tbool zope.need_cvsdir]} {
			ui_debug "mkdir: ${worksrcpath}"
			file mkdir ${worksrcpath}
		}
	}
}

# Zope group option procedures
proc zope.fix_extract_dir {option action args} {
	global workpath worksrcpath
	if {[string equal ${action} "set"]} {
		if {[tbool args]} {
			extract.dir ${worksrcpath}
		} else {
			extract.dir ${workpath}
		}
	}
}

proc zope.fix_cvs_dir {option action args} {
	global workpath worksrcpath distname zope.product
	if {[string equal ${action} "set"]} {
		if {[tbool args]} {
			cvs.args	-d ${zope.product}
			cvs.dir		${worksrcpath}
		} else {
			cvs.args	-d ${distname}
			cvs.dir		${workpath}
		}
	}
}
