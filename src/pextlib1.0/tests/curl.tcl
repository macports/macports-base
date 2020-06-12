# Test file for Pextlib's curl.
# Syntax:
# tclsh curl.tcl <Pextlib name>

proc main {pextlibname} {
	load $pextlibname

	set tempfile /tmp/macports-pextlib-testcurl

	# download a dummy file over HTTP.
	set dummyfile http://distfiles.macports.org/MacPorts/MacPorts-2.6.2.tar.gz.asc
	curl fetch $dummyfile $tempfile
	
	# check the md5 sum of the file.
	test {[md5 file $tempfile] == "41023b6070d3dda3b5d34b7e773b40fc"}

	# check we indeed get a 404 a dummy file over HTTP.
	test {[catch {curl fetch $dummyfile/404 $tempfile}]}
	
	# check the modification date of the dummy file.
	test {[curl isnewer $dummyfile [clock scan 2019-10-20Z]]}
	test {![curl isnewer $dummyfile [clock scan 2019-10-21Z]]}
	
	# use --disable-epsv
	#curl fetch --disable-epsv ftp://ftp.cup.hp.com/dist/networking/benchmarks/netperf/archive/netperf-2.2pl5.tar.gz $tempfile
	#test {[md5 file $tempfile] == "a4b0f4a5fbd8bec23002ad8023e01729"}
	
	# use -u
	# This URL does not work anymore, disabled the test
	#curl fetch -u "I accept www.opensource.org/licenses/cpl:." http://www.research.att.com/~gsf/download/tgz/sfio.2005-02-01.tgz $tempfile
	#test {[md5 file $tempfile] == "48f45c7c77c23ab0ccca48c22b3870de"}
	
	file delete -force $tempfile
}

proc test {args} {
    if {[catch {uplevel 1 expr $args} result] || !$result} {
        puts "[uplevel 1 subst -nocommands $args] == $result"
        exit 1
    }
}

main $argv
