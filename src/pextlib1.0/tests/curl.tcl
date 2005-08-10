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
	if {![curl isnewer http://www.opendarwin.org/~pguyot/kilroy 20050801]} {
		puts {![curl isnewer http://www.opendarwin.org/~pguyot/kilroy 20050801]}
		exit 1
	}
	if {[curl isnewer http://www.opendarwin.org/~pguyot/kilroy 20050811]} {
		puts {[curl isnewer http://www.opendarwin.org/~pguyot/kilroy 20050811]}
		exit 1
	}
	
	# use --disable-epsv
	curl fetch --disable-epsv ftp://www-126.ibm.com/pub/jikes/JikesPG/1.3/jikespg.tar.gz $tempfile
	if {[md5 file $tempfile] != "eba183713d9ae61a887211be80eeb21f"} {
		puts {[md5 file $tempfile] != "eba183713d9ae61a887211be80eeb21f"}
		exit 1
	}
	
	# use -u
	curl fetch -u "I accept www.opensource.org/licenses/cpl:." http://www.research.att.com/~gsf/download/tgz/ast-ksh.2005-02-02.tgz $tempfile
	if {[md5 file $tempfile] != "fecce7e67b55fe986c7c2163346e0977"} {
		puts {[md5 file $tempfile] != "fecce7e67b55fe986c7c2163346e0977"}
		exit 1
	}
	
	file delete -force $tempfile
}

main $argv
