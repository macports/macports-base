# Test file for Pextlib's curl.
# Syntax:
# tclsh curl.tcl <Pextlib name>

proc main {pextlibname} {
	load $pextlibname

	set tempfile /tmp/macports-pextlib-testcurl

	# download a dummy file over HTTP.
	set dummyroot http://svn.macports.org/repository/macports/users/eridius/curltest
	curl fetch $dummyroot/dummy $tempfile
	
	# check the md5 sum of the file.
	test {[md5 file $tempfile] == "5421fb0f76c086a1e14bf33d25b292d4"}

	# check we indeed get a 404 a dummy file over HTTP.
	test {[catch {curl fetch $dummyroot/404 $tempfile}]}
	
	# check the modification date of the dummy file.
	set seconds [clock scan 2007-06-16Z]
	test {[curl isnewer $dummyroot/dummy [clock scan 2007-06-16Z]]}
	set seconds [clock scan 2007-06-17Z]
	test {![curl isnewer $dummyroot/dummy [clock scan 2007-06-17Z]]}
	
	# use --disable-epsv
	curl fetch --disable-epsv ftp://ftp.cup.hp.com/dist/networking/benchmarks/netperf/archive/netperf-2.2pl5.tar.gz $tempfile
	test {[md5 file $tempfile] == "a4b0f4a5fbd8bec23002ad8023e01729"}
	
	# use -u
	curl fetch -u "I accept www.opensource.org/licenses/cpl:." http://www.research.att.com/~gsf/download/tgz/ast-ksh.2008-02-02.tgz $tempfile
	test {[md5 file $tempfile] == "d2a71e320fbaa7a0fd950a27c7e4b099"}
	
	file delete -force $tempfile
}

proc test {args} {
    if {[catch {uplevel 1 expr $args} result] || !$result} {
        puts "[uplevel 1 subst -nocommands $args] == $result"
        exit 1
    }
}

main $argv
