# global port routines
package provide portextract 1.0
package require portutil 1.0

register com.apple.extract target build extract_main 
register com.apple.extract provides extract
register com.apple.extract requires fetch checksum

global extract_opts

# define options
options extract_opts extract.only extract.cmd extract.before_args extract.after_args

proc extract_main {args} {
    global extract_opts
    global portname portpath portpath workdir distname distpath distfiles use_bzip2

    # Set up defaults
    default extract_opts extract.only $distfiles
    default extract_opts extract.cmd gzip
    default extract_opts extract.before_args -dc
    default extract_opts extract.after_args "| tar -xf -"

    if [info exists use_bzip2] {
	set extract_opts(extract.cmd) bzip2
    } elseif [info exists use_zip] {
	set extract_opts(extract.cmd) unzip
	set extract_opts(extract.before_args) -q
	set extract_opts(extract.after_args) "-d $portpath/$workdir"
    }

    puts "Extracting for $distname"
    if [file exists $workdir] {
	file delete -force $portpath/$workdir
    }

    file mkdir $portpath/$workdir
    cd $portpath/$workdir
    foreach distfile $extract_opts(extract.only) {
	puts -nonewline "$distfile: "
	flush stdout
	set cmd "$extract_opts(extract.cmd) $extract_opts(extract.before_args) $distpath/$distfile $extract_opts(extract.after_args)"
	if [catch {system $cmd} result] {
	    puts $result
	    return -1
	}
	puts "done"
    }
    return 0
}

