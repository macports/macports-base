# global port routines
# the 'main' target is provided by this package
# main is a magic target and should not be replaced
package provide portmain 1.0
package require portutil 1.0

register com.apple.main target build main
register com.apple.main provides main

global main_opts
global targets

# define options
options main_opts portname portversion portrevision categories maintainers workdir worksrcdir no_worksubdir filedir distname

proc main {args} {
    global main_opts portname distname

    default main_opts workdir work
    default main_opts filedir files
    default main_opts portrevision 0
    if {[tbool opts no_worksubdir]} {
	default opts worksrcdir ""
    } else {
	default opts worksrcdir $opts(distname)
    }
    return 0
}

