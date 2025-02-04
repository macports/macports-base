
The example shown below is the specification of queue data structure,
with most of the method implementations and support code omitted to
keep the size down.

[para] The full implementation can be found in the directory
[file examples/queue] of the critcl source distribution/repository.

[example {
package require Tcl 8.6
package require critcl 3.2

critcl::buildrequirement {
    package require critcl::class ; # DSL, easy spec of Tcl class/object commands.
}

critcl::cheaders util.h

critcl::class::define ::queuec {
    include util.h

    insvariable Tcl_Obj* unget {
	List object unget elements
    } {
	instance->unget = Tcl_NewListObj (0,NULL);
	Tcl_IncrRefCount (instance->unget);
    } {
	Tcl_DecrRefCount (instance->unget);
    }

    insvariable Tcl_Obj* queue {
	List object holding the main queue
    } {
	instance->queue = Tcl_NewListObj (0,NULL);
	Tcl_IncrRefCount (instance->queue);
    } {
	Tcl_DecrRefCount (instance->queue);
    }

    insvariable Tcl_Obj* append {
	List object holding new elements
    } {
	instance->append = Tcl_NewListObj (0,NULL);
	Tcl_IncrRefCount (instance->append);
    } {
	Tcl_DecrRefCount (instance->append);
    }

    insvariable int at {
	Index of next element to return from the main queue
    } {
	instance->at = 0;
    }

    support {... queue_peekget, queue_size, etc.}

    method clear {} {...}
    method destroy {...}

    method get  as queue_peekget 1
    method peek as queue_peekget 0

    method put {item ...}

    method size {} {
	if ((objc != 2)) {
	    Tcl_WrongNumArgs (interp, 2, objv, NULL);
	    return TCL_ERROR;
	}

	Tcl_SetObjResult (interp, Tcl_NewIntObj (queue_size (instance, NULL, NULL, NULL)));
	return TCL_OK;
    }

    method unget {item} {...}
}

package provide queuec 1
}]
