# ex:ts=4
#
# Insert some license text here at some point soon.
#

# the 'main' target is provided by this package
# main is a magic target and should not be replaced

package provide portmain 1.0
package require portutil 1.0

register com.apple.main target main always
register com.apple.main provides main

# define options
options portname portversion portrevision categories maintainers workdir worksrcdir no_worksubdir filedir distname sysportpath libpath dist_subdir distpath

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

proc main {args} {
    global worksrcdir main_opts portname distname distpath dist_subdir

    if {[tbool no_worksubdir]} {
	default worksrcdir ""
    } else {
	if {[info exists distname]} {
		default worksrcdir $distname
	}
    }
    if {[info exists distpath] && [info exists dist_subdir]} {
	set distpath ${distpath}/${dist_subdir}
    }

    return 0
}

