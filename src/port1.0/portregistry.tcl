# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portregistry 1.0
package require portutil 1.0

# For now, just write stuff to a file for debugging.

proc registry_new {portname {portversion 1.0}} {
    return [open "/tmp/$portname-$portversion" w 0644]
}

proc registry_store {rhandle data} {
    puts $rhandle "\# Contents Format: {{filename uid gid mode size {md5}} ... }"
    puts $rhandle $data
}

proc registry_fetch {rhandle} {
    return -1
}

proc registry_traverse {func} {
    return -1
}

proc registry_close {rhandle} {
    close $rhandle
}

