# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portextract 1.0
package require portutil 1.0

register com.apple.extract target extract_main 
register com.apple.extract swdep depends_lib
register com.apple.extract provides extract
register com.apple.extract requires fetch checksum

global extract_opts

# define options
options extract_opts extract.only extract.cmd extract.before_args extract.after_args

set UI_PREFIX "---> "

proc extract_main {args} {
    global portname portpath portpath workdir distname distpath distfiles use_bzip2 extract.only extract.cmd extract.before_args extract.after_args UI_PREFIX

    if {![info exists distfiles] && ![info exists extract.only]} {
	# nothing to do
	return 0
    }

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

    ui_msg "$UI_PREFIX Extracting for $distname"

    cd $portpath/$workdir
    foreach distfile ${extract.only} {
	ui_info "$UI_PREFIX Extracting $distfile ... " -nonewline
	set cmd "${extract.cmd} [join ${extract.before_args}] $distpath/$distfile [join ${extract.after_args}]"
	if [catch {system $cmd} result] {
	    ui_error "$result"
	    return -1
	}
	ui_info "Done"
    }
    return 0
}

