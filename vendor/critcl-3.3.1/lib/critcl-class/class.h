/*
 * For package "@package@".
 * Implementation of Tcl Class "@class@".
 *
 * Flags: @buildflags@
 */

#ifndef @stem@_IMPLEMENTATION
#define @stem@_IMPLEMENTATION (1)
/* # # ## ### ##### ######## ############# ##################### */

@includes@
#line 14 "class.h"
/*
 * Instance method names and enumeration.
 */

static CONST char* @stem@_methodnames [] = {
@method_names@
#line 21 "class.h"
    NULL
};

typedef enum @stem@_methods {
@method_enumeration@
#line 27 "class.h"
} @stem@_methods;

/*
 * Class method names and enumeration.
 */

static CONST char* @stem@_class_methodnames [] = {
    "create",
    "new",@class_method_names@
#line 37 "class.h"
    NULL
};

typedef enum @stem@_classmethods {
    @stem@_CM_create,
    @stem@_CM_new@class_method_enumeration@
#line 44 "class.h"
} @stem@_classmethods;

/*
 * Class structures I. Class variables.
 */

typedef struct @classtype@__ {
@ctypedecl@
#line 53 "class.h"
} @classtype@__;
typedef struct @classtype@__* @classtype@;

/*
 * Class structures II. Creation management.
 */

typedef struct @classtype@_mgr_ {
@classmgrstruct@
#line 63 "class.h"
    @classtype@__ user;                       /* User-specified class variables */
} @classtype@_mgr_;
typedef struct @classtype@_mgr_* @classtype@_mgr;

/*
 * Instance structure.
 */

@itypedecl@
#line 73 "class.h"

/* # # ## ### ##### ######## User: General support */
@support@
#line 77 "class.h"
/* # # ## ### ##### ######## */

/*
 * Class support functions.
 */

static void
@stem@_ClassRelease (ClientData cd, Tcl_Interp* interp)
{
    @classtype@_mgr classmgr = (@classtype@_mgr) cd;
    @classtype@     class    = &classmgr->user;
    @classdestructor@
#line 90 "class.h"
    ckfree((char*) cd);
}

static @classtype@_mgr
@stem@_Class (Tcl_Interp* interp)
{
#define KEY "@package@/@class@"

    Tcl_InterpDeleteProc* proc = @stem@_ClassRelease;
    @classtype@_mgr       classmgr;
    @classtype@           class;

    classmgr = Tcl_GetAssocData (interp, KEY, &proc);
    if (classmgr) {
	return classmgr;
    }

    classmgr = (@classtype@_mgr) ckalloc (sizeof (@classtype@_mgr_));
@classmgrsetup@
#line 110 "class.h"
    class = &classmgr->user;

    @classconstructor@
#line 114 "class.h"

    Tcl_SetAssocData (interp, KEY, proc, (ClientData) classmgr);
    return classmgr;
 error:
    ckfree ((char*) classmgr);
    return NULL;
#undef KEY
}
@classmgrnin@
#line 124 "class.h"
/* # # ## ### ##### ######## */

static @instancetype@
@stem@_Constructor (Tcl_Interp* interp,
		    @classtype@ class,
		    Tcl_Size       objcskip,
		    Tcl_Size       objc,
		    Tcl_Obj*const* objv)
{
@ivardecl@;
    /* # # ## ### ##### ######## User: Constructor */
    @constructor@
#line 137 "class.h"
    /* # # ## ### ##### ######## */
    return instance;
@ivarerror@;
#line 141 "class.h"
}

static void
@stem@_PostConstructor (Tcl_Interp* interp,
		        @instancetype@ instance,
		        Tcl_Command cmd,
			Tcl_Obj* fqn)
{
    /* # # ## ### ##### ######## User: Post Constructor */
    @postconstructor@
#line 152 "class.h"
    /* # # ## ### ##### ######## */
}

static void
@stem@_Destructor (ClientData clientData)
{
    @instancetype@ instance = (@instancetype@) clientData;
    /* # # ## ### ##### ######## User: Destructor */
    @destructor@
#line 162 "class.h"
    /* # # ## ### ##### ######## */
@ivarrelease@;
#line 165 "class.h"
}

/* # # ## ### ##### ######## User: Methods */
@method_implementations@
#line 170 "class.h"
/* # # ## ### ##### ######## */

/*
 * Instance command, method dispatch
 */

static int
@stem@_InstanceCommand (ClientData      clientData,
			Tcl_Interp*     interp,
			Tcl_Size        objc,
			Tcl_Obj* CONST* objv)
{
    @instancetype@ instance = (@instancetype@) clientData;
    int mcode;

    if (objc < 2) {
	Tcl_WrongNumArgs (interp, objc, objv, "option ?arg arg ...?");
	return TCL_ERROR;
    } else if (Tcl_GetIndexFromObj (interp, objv [1],
				    (const char**) @stem@_methodnames,
				    "option", 0, &mcode) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Dispatch to methods. They check the #args in detail before performing
     * the requested functionality
     */

    switch ((@stem@_methods) mcode) {
@method_dispatch@
#line 202 "class.h"
    }
    /* Not coming to this place */
    return TCL_ERROR;
}

@cconscmd@
#line 209 "class.h"
@capiclassvaraccess@
#line 211 "class.h"
@tclconscmd@
#line 213 "class.h"
/* # # ## ### ##### ######## User: Class Methods */
@class_method_implementations@
#line 216 "class.h"
@classcommand@
#line 218 "class.h"
/* # # ## ### ##### ######## ############# ##################### */
#endif /* @stem@_IMPLEMENTATION */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */

#line 230 "class.h"
	const char*   name;                       /* Class name, for debugging */
	long int      counter;                    /* Id generation counter */
	char          buf [sizeof("@class@")+20]; /* Stash for the auto-generated object names. */

	classmgr->name = "@stem@";
	classmgr->counter = 0;

#line 238 "class.h"
static CONST char*
@stem@_NewInstanceName (@classtype@_mgr classmgr)
{
    classmgr->counter ++;
    sprintf (classmgr->buf, "@class@%ld", classmgr->counter);
    return classmgr->buf;
}

#line 247 "class.h"
/* # # ## ### ##### ######## */
/*
 * Tcl API :: Class command, class method, especially instance construction.
 */

int
@stem@_ClassCommand (ClientData      clientData,
		     Tcl_Interp*     interp,
		     Tcl_Size        objc,
		     Tcl_Obj* CONST* objv)
{
    @classtype@_mgr classmgr;
    @classtype@     class;
    int mcode;

    if (objc < 2) {
	Tcl_WrongNumArgs (interp, 0, objv, "method ?args...?");
	return TCL_ERROR;
    }

    if (Tcl_GetIndexFromObj (interp, objv [1],
			     (const char**) @stem@_class_methodnames,
			     "option", 0, &mcode) != TCL_OK) {
	return TCL_ERROR;
    }

    classmgr = @stem@_Class (interp);
    if (!classmgr) {
	return TCL_ERROR;
    }
    class = &classmgr->user;

    /*
     * Dispatch to methods. They check the #args in detail before performing
     * the requested functionality
     */

    switch ((@stem@_classmethods) mcode) {
    case @stem@_CM_create: return @stem@_CM_createCmd (classmgr, interp, objc, objv); break;
    case @stem@_CM_new:    return @stem@_CM_newCmd    (classmgr, interp, objc, objv); break;@class_method_dispatch@
#line 288 "class.h"
    }
    /* Not coming to this place */
    return TCL_ERROR;
}

#line 294 "class.h"
/* # # ## ### ##### ########: Predefined class methods */
static int
@stem@_NewInstance (const char*     name,
		    @classtype@_mgr classmgr,
		    Tcl_Interp*     interp,
		    Tcl_Size        objcskip,
		    Tcl_Size        objc,
		    Tcl_Obj* CONST* objv)
{
    @instancetype@ instance;
    Tcl_Obj*    fqn;
    Tcl_CmdInfo ci;
    Tcl_Command cmd;

    /*
     * Compute the fully qualified command name to use, putting
     * the command into the current namespace if necessary.
     */

    if (!Tcl_StringMatch (name, "::*")) {
	/* Relative name. Prefix with current namespace */

	Tcl_Eval (interp, "namespace current");
	fqn = Tcl_GetObjResult (interp);
	fqn = Tcl_DuplicateObj (fqn);
	Tcl_IncrRefCount (fqn);

	if (!Tcl_StringMatch (Tcl_GetString (fqn), "::")) {
	    Tcl_AppendToObj (fqn, "::", -1);
	}
	Tcl_AppendToObj (fqn, name, -1);
    } else {
	fqn = Tcl_NewStringObj (name, -1);
	Tcl_IncrRefCount (fqn);
    }
    Tcl_ResetResult (interp);

    /*
     * Check if the commands exists already, and bail out if so.
     * We will not overwrite an existing command.
     */

    if (Tcl_GetCommandInfo (interp, Tcl_GetString (fqn), &ci)) {
	Tcl_Obj* err;

	err = Tcl_NewObj ();
	Tcl_AppendToObj    (err, "command \"", -1);
	Tcl_AppendObjToObj (err, fqn);
	Tcl_AppendToObj    (err, "\" already exists, unable to create @class@ instance", -1);

	Tcl_DecrRefCount (fqn);
	Tcl_SetObjResult (interp, err);
	return TCL_ERROR;
    }

    /*
     * Construct instance state, and command.
     */

    instance = @stem@_Constructor (interp, &classmgr->user, objcskip, objc, objv);
    if (!instance) {
	return TCL_ERROR;
    }

    cmd = Tcl_CreateObjCommand2 (interp, Tcl_GetString (fqn),
				 @stem@_InstanceCommand,
				 (ClientData) instance,
				 @stem@_Destructor);

    @stem@_PostConstructor (interp, instance, cmd, fqn);

    Tcl_SetObjResult (interp, fqn);
    Tcl_DecrRefCount (fqn);
    return TCL_OK;
}

static int
@stem@_CM_createCmd (@classtype@_mgr classmgr,
		     Tcl_Interp*     interp,
		     Tcl_Size        objc,
		     Tcl_Obj* CONST* objv)
{
    /* <class> create <name> ... */
    char* name;

    if (objc < 3) {
	Tcl_WrongNumArgs (interp, 1, objv, "name ?args...?");
	return TCL_ERROR;
    }

    name = Tcl_GetString (objv [2]);

    objc -= 3;
    objv += 3;

    return @stem@_NewInstance (name, classmgr, interp, 3, objc, objv);
}

static int
@stem@_CM_newCmd (@classtype@_mgr classmgr,
		  Tcl_Interp*     interp,
		  Tcl_Size        objc,
		  Tcl_Obj* CONST* objv)
{
    /* <class> new ... */
    const char* name;

    if (objc < 2) {
	Tcl_WrongNumArgs (interp, 1, objv, "?args...?");
	return TCL_ERROR;
    }

    objc -= 2;
    objv += 2;

    name = @stem@_NewInstanceName (classmgr);
    return @stem@_NewInstance (name, classmgr, interp, 2, objc, objv);
}

#line 414 "class.h"
/* # # ## ### ##### ######## */
/*
 * C API :: Instance (de)construction, dispatch
 */

typedef struct @instancetype@__ @capiprefix@;
typedef struct @capiprefix@* @capiprefix@_p;

@capiprefix@_p
@capiprefix@_new (Tcl_Interp*	  interp,
		  Tcl_Size	  objc,
		  Tcl_Obj* CONST* objv)
{
    @classtype@_mgr classmgr = @stem@_Class (interp);
    @instancetype@ instance;

    /*
     * Construct instance state
     */

    instance = @stem@_Constructor (interp, &classmgr->user, 0, objc, objv);
    if (!instance) {
	return NULL;
    }

    @stem@_PostConstructor (interp, instance, 0, 0);

    return (@capiprefix@_p) instance;
}

void
@capiprefix@_destroy (@capiprefix@_p instance)
{
    @stem@_Destructor (instance);
}

int
@capiprefix@_invoke (@capiprefix@_p instance,
		     Tcl_Interp*     interp,
		     Tcl_Size	     objc,
		     Tcl_Obj* CONST* objv)
{
    Tcl_Obj** v = (Tcl_Obj**) ckalloc ((objc+1)*sizeof (Tcl_Obj*));
    Tcl_Obj* i = Tcl_NewStringObj ("@capiprefix@", sizeof ("@capiprefix@")-1);
    Tcl_IncrRefCount (i);

    v[0] = i;
    memcpy (v+1, objv, objc * sizeof (Tcl_Obj*));

    int r = @stem@_InstanceCommand (instance, interp, objc+1, v);

    Tcl_DecrRefCount (i);
    ckfree ((char*) v);
    return r;
}
