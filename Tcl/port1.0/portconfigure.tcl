# global port routines
package provide portconfigure 1.0
package require portutil 1.0

register com.apple.configure target build configure_main
register com.apple.configure provides configure
register com.apple.configure requires main fetch extract checksum patch

# define options
options configure configure.type configure.args configure.worksrcdir automake automake.env automake.args autoconf autoconf.env autoconf.args xmkmf libtool

proc configure_main {args} {
    global configure configure.type configure.args configure.worksrcdir automake automake.env automake.args autoconf autoconf.env autoconf.args xmkmf libtool portname portpath workdir worksrcdir prefix

    if [info exists configure.worksrcdir] {
	set configpath ${portpath}/${workdir}/${worksrcdir}/${configure.worksrcdir}
    } else {
	set configpath ${portpath}/${workdir}/${worksrcdir}
    }

    cd $configpath
    if [tbool automake] {
	# XXX depend on automake
    }

    if [tbool configure]  {
	if [info exists configure.args] {
	    system "./configure --prefix=${prefix} ${configure.args}"
	} else {
	    system "./configure --prefix=${prefix}"
	}
    }
    return 0
}

