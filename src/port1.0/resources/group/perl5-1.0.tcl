# et:ts=4
# perl5-1.0.tcl
#
# $Id: perl5-1.0.tcl,v 1.6 2004/04/08 20:17:56 toby Exp $

# Set some variables.
set perl5.bin ${prefix}/bin/perl

proc perl5.extract_config {var {default ""}} {
	global perl5.bin

	if {[catch {set val [lindex [split [exec ${perl5.bin} -V:${var}] {'}] 1]}]} {
		set val ${default}
	}

	return $val
}

set perl5.version [perl5.extract_config version]
set perl5.arch [perl5.extract_config archname ${os.platform}]

# define installation libraries as vendor location
set perl5.lib ${prefix}/lib/perl5/vendor_perl/${perl5.version}
set perl5.archlib ${perl5.lib}/${perl5.arch}

# define these empty initially, they are set by perl5.setup arguments
set perl5.module ""
set perl5.cpandir ""

# perl5 group setup procedure
proc perl5.setup {module vers {cpandir ""}} {
	global perl5.bin perl5.lib perl5.module perl5.cpandir

	# define perl5.module
	set perl5.module ${module}

	# define perl5.cpandir
	# check if optional CPAN dir specified to perl5.setup
	if {[string length ${cpandir}] == 0} {
		# if not, default to the first word (before a dash) from the
		# module name, this is the normal convention on CPAN
		set perl5.cpandir [lindex [split ${perl5.module} {-}] 0]
	} else {
		# else, use what was passed
		set perl5.cpandir ${cpandir}
	}

	name                p5-[string tolower ${perl5.module}]
	version             ${vers}
	categories          perl
	homepage            http://search.cpan.org/dist/${perl5.module}/

	master_sites        perl_cpan:${perl5.cpandir}
	distname            ${perl5.module}-${vers}
	dist_subdir         perl5

	depends_build       path:${perl5.bin}:perl5.8

	configure.cmd       ${perl5.bin}
	configure.pre_args  Makefile.PL
	configure.args      INSTALLDIRS=vendor

	test.run            yes

	destroot.target     pure_install

	post-destroot {
		foreach packlist [exec find ${destroot}${perl5.lib} -name .packlist] {
			ui_info "Fixing packlist ${packlist}"
			reinplace "s|${destroot}||" ${packlist}
		}
	}
}
