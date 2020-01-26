# Test file for Pextlib's curl.
# Syntax:
# tclsh curl.tcl <Pextlib name>

proc main {pextlibname} {
	load $pextlibname

	set tempfile /tmp/macports-pextlib-testcurl

	# download a dummy file over HTTP.
	set dummyroot http://svn.macports.org/repository/macports/users/eridius/curltest
	curl fetch --ignore-ssl-cert $dummyroot/dummy $tempfile
	
	# check the md5 sum of the file.
	test "md5sum" {[md5 file $tempfile] == "5421fb0f76c086a1e14bf33d25b292d4"}

	# check we indeed get a 404 a dummy file over HTTP.
	test "dummy404" {[catch {curl fetch --ignore-ssl-cert $dummyroot/404 $tempfile}]}
	
	# check the modification date of the dummy file.
	set seconds [clock scan 2007-06-16Z]
	test "mtime1" {[curl isnewer --ignore-ssl-cert $dummyroot/dummy [clock scan 2007-06-16Z]]}
	set seconds [clock scan 2007-06-17Z]
	test "mtime2" {![curl isnewer --ignore-ssl-cert $dummyroot/dummy [clock scan 2007-06-17Z]]}
	
	# use --disable-epsv
	#curl fetch --disable-epsv ftp://ftp.cup.hp.com/dist/networking/benchmarks/netperf/archive/netperf-2.2pl5.tar.gz $tempfile
	#test {[md5 file $tempfile] == "a4b0f4a5fbd8bec23002ad8023e01729"}
	
	# use -u
	# This URL does not work anymore, disabled the test
	#curl fetch -u "I accept www.opensource.org/licenses/cpl:." http://www.research.att.com/~gsf/download/tgz/sfio.2005-02-01.tgz $tempfile
	#test {[md5 file $tempfile] == "48f45c7c77c23ab0ccca48c22b3870de"}
	
	curl fetch --enable-compression https://www.whatsmyip.org/http-compression-test/ $tempfile
	grepper $tempfile {gz_yes}

	curl fetch https://www.whatsmyip.org/http-compression-test/ $tempfile
	grepper $tempfile {gz_no}

	file delete -force $tempfile
}

proc test {test_name args} {
	if {[catch {uplevel 1 expr $args} result] || !$result} {
		puts "test $test_name failed: [uplevel 1 subst -nocommands $args] == $result"
		exit 1
	}
}

proc grepper {filepath regex} {
	set hasMatch 0
	set fd [open $filepath]
	while {[gets $fd line] != -1} {
		if {[regexp $regex $line all]} {
			set hasMatch 1
		}
	}
	close $fd
	test "grepper $regex" {$hasMatch == 1}
}

main $argv
