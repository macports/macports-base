# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portextract 1.0
package require portutil 1.0

register com.apple.extract target build extract_main 
register com.apple.extract swdep build depend_libs
register com.apple.extract provides extract
register com.apple.extract requires fetch checksum

global extract_opts

# define options
options extract_opts extract.only extract.cmd extract.before_args extract.after_args

proc extract_main {args} {
    global portname portpath portpath workdir distname distpath distfiles use_bzip2 extract.only extract.cmd extract.before_args extract.after_args

    # Set up defaults
    default extract.only $distfiles
    default extract.cmd gzip
    default extract.before_args -dc
    default extract.after_args "| tar -xf -"

    if [info exists use_bzip2] {
	set extract.cmd bzip2
    } elseif [info exists use_zip] {
	set extract.cmd unzip
	set extract.before_args -q
	set extract.after_args "-d $portpath/$workdir"
    }

    ui_puts "Extracting for $distname"

    cd $portpath/$workdir
    foreach distfile ${extract.only} {
	ui_puts "$distfile: " -nonewline
	flush stdout
	set cmd "${extract.cmd} [join ${extract.before_args}] $distpath/$distfile [join ${extract.after_args}]"
	if [catch {system $cmd} result] {
	    ui_puts $result
	    return -1
	}
	ui_puts "done"
    }
    return 0
}

