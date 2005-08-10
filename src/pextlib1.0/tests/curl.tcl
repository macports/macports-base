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

	file delete -force "$tempfile"

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
}

main $argv
