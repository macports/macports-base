# global port routines
package provide portconfigure 1.0
package require portutil 1.0

register com.apple.configure target build configure_main
register com.apple.configure provides configure
register com.apple.configure requires main fetch extract checksum patch

global configure_opts

# define options
options configure_opts configure configure.type configure.args configure.worksrcdir automake automake.env automake.args autoconf autoconf.env autoconf.args xmkmf libtool

proc configure_main {args} {
    global configure_opts
    global portname portpath workdir worksrcdir prefix

    if [info exists configure_opts(configure.worksrcdir)] {
	set configpath ${portpath}/${workdir}/${worksrcdir}/${configure.worksrcdir}
    } else {
	set configpath ${portpath}/${workdir}/${worksrcdir}
    }

    cd $configpath
    if [tbool configure_opts automake] {
	# XXX depend on automake
    }

    if [tbool configure_opts configure]  {
	if [info exists configure_opts(configure.args)] {
	    system "./configure --prefix=${prefix} configure_opts(configure.args)"
	} else {
	    system "./configure --prefix=${prefix}"
	}
    }
    return 0
}

