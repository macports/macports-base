#-*- mode: Fundamental; tab-width: 4; -*-
# ex:ts=4
#
# Insert some license text here at some point soon.
#

# the 'main' target is provided by this package
# main is a magic target and should not be replaced

package provide portmain 1.0
package require portutil 1.0

register com.apple.main target build main
register com.apple.main provides main

# XXX Special case sysportpath. This variable is set by the bootstrap
# and may not exist
if [info exists sysportpath] {
	default distpath $sysportpath/distfiles
}
default prefix /usr/local/
default workdir work
default filedir files
default portrevision 0
default os_arch $tcl_platform(machine)
default os_version $tcl_platform(osVersion)

# define options
options portname portversion portrevision categories maintainers workdir worksrcdir no_worksubdir filedir distname sysportpath libpath

proc main {args} {
    global worksrcdir main_opts portname distname

    if {[tbool no_worksubdir]} {
	default worksrcdir ""
    } else {
	if {[info exists distname]} {
		default worksrcdir $distname
	}
    }
    return 0
}

