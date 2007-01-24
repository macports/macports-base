# Test file for Pextlib's curl.
# Syntax:
# tclsh curl.tcl <Pextlib name>

proc main {pextlibname} {
	load $pextlibname

	set tempfile /tmp/darwinports-pextlib-testcurl

	# download a dummy file over HTTP.
	curl fetch http://www.opendarwin.org/~pguyot/kilroy $tempfile
	
	# check the md5 sum of the file.
	if {[md5 file $tempfile] != "a1b1cca7ffaa377e7dcdaaf2f619d8ae"} {
		puts {[md5 file $tempfile] != "a1b1cca7ffaa377e7dcdaaf2f619d8ae"}
		exit 1
	}

	# check we indeed get a 404 a dummy file over HTTP.
	if {![catch {curl fetch http://www.opendarwin.org/~pguyot/curl-test-404 $tempfile}]} {
		puts {![catch {curl fetch http://www.opendarwin.org/~pguyot/curl-test-404 $tempfile}]}
		exit 1
	}
	
	# check the modification date of the dummy file.
	# 20050801->1122822000
	if {![curl isnewer http://www.opendarwin.org/~pguyot/kilroy 1122822000]} {
		puts {![curl isnewer http://www.opendarwin.org/~pguyot/kilroy 1122822000]}
		exit 1
	}
	# 20050811->1123686000
	if {[curl isnewer http://www.opendarwin.org/~pguyot/kilroy 1123686000]} {
		puts {[curl isnewer http://www.opendarwin.org/~pguyot/kilroy 1123686000]}
		exit 1
	}
	
	# use --disable-epsv
	curl fetch --disable-epsv ftp://ftp.cup.hp.com/dist/networking/benchmarks/netperf/archive/netperf-2.2pl5.tar.gz $tempfile
	if {[md5 file $tempfile] != "a4b0f4a5fbd8bec23002ad8023e01729"} {
		puts {[md5 file $tempfile] != "a4b0f4a5fbd8bec23002ad8023e01729"}
		exit 1
	}
	
	# use -u
	curl fetch -u "I accept www.opensource.org/licenses/cpl:." http://www.research.att.com/~gsf/download/tgz/ast-ksh.2007-01-11.tgz $tempfile
	if {[md5 file $tempfile] != "a24a0b8d8dc81600d624e3c0f2159e38"} {
		puts {[md5 file $tempfile] != "a24a0b8d8dc81600d624e3c0f2159e38"}
		exit 1
	}
	
	file delete -force $tempfile
}

main $argv
