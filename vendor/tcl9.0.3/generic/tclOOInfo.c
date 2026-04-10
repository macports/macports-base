/*
 * tclOODefineCmds.c --
 *
 *	This file contains the implementation of the ::oo-related [info]
 *	subcommands.
 *
 * Copyright © 2006-2019 Donal K. Fellows
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif
#include "tclInt.h"
#include "tclOOInt.h"

static Tcl_ObjCmdProc InfoObjectCallCmd;
static Tcl_ObjCmdProc InfoObjectClassCmd;
static Tcl_ObjCmdProc InfoObjectDefnCmd;
static Tcl_ObjCmdProc InfoObjectFiltersCmd;
static Tcl_ObjCmdProc InfoObjectForwardCmd;
static Tcl_ObjCmdProc InfoObjectIdCmd;
static Tcl_ObjCmdProc InfoObjectIsACmd;
static Tcl_ObjCmdProc InfoObjectMethodsCmd;
static Tcl_ObjCmdProc InfoObjectMethodTypeCmd;
static Tcl_ObjCmdProc InfoObjectMixinsCmd;
static Tcl_ObjCmdProc InfoObjectNsCmd;
static Tcl_ObjCmdProc InfoObjectVarsCmd;
static Tcl_ObjCmdProc InfoObjectVariablesCmd;
static Tcl_ObjCmdProc InfoClassCallCmd;
static Tcl_ObjCmdProc InfoClassConstrCmd;
static Tcl_ObjCmdProc InfoClassDefnCmd;
static Tcl_ObjCmdProc InfoClassDefnNsCmd;
static Tcl_ObjCmdProc InfoClassDestrCmd;
static Tcl_ObjCmdProc InfoClassFiltersCmd;
static Tcl_ObjCmdProc InfoClassForwardCmd;
static Tcl_ObjCmdProc InfoClassInstancesCmd;
static Tcl_ObjCmdProc InfoClassMethodsCmd;
static Tcl_ObjCmdProc InfoClassMethodTypeCmd;
static Tcl_ObjCmdProc InfoClassMixinsCmd;
static Tcl_ObjCmdProc InfoClassSubsCmd;
static Tcl_ObjCmdProc InfoClassSupersCmd;
static Tcl_ObjCmdProc InfoClassVariablesCmd;

/*
 * List of commands that are used to implement the [info object] subcommands.
 */

static const EnsembleImplMap infoObjectCmds[] = {
    {"call",	   InfoObjectCallCmd,	    TclCompileBasic2ArgCmd, NULL, NULL, 0},
    {"class",	   InfoObjectClassCmd,	    TclCompileInfoObjectClassCmd, NULL, NULL, 0},
    {"creationid", InfoObjectIdCmd,	    TclCompileBasic1ArgCmd, NULL, NULL, 0},
    {"definition", InfoObjectDefnCmd,	    TclCompileBasic2ArgCmd, NULL, NULL, 0},
    {"filters",	   InfoObjectFiltersCmd,    TclCompileBasic1ArgCmd, NULL, NULL, 0},
    {"forward",	   InfoObjectForwardCmd,    TclCompileBasic2ArgCmd, NULL, NULL, 0},
    {"isa",	   InfoObjectIsACmd,	    TclCompileInfoObjectIsACmd, NULL, NULL, 0},
    {"methods",	   InfoObjectMethodsCmd,    TclCompileBasicMin1ArgCmd, NULL, NULL, 0},
    {"methodtype", InfoObjectMethodTypeCmd, TclCompileBasic2ArgCmd, NULL, NULL, 0},
    {"mixins",	   InfoObjectMixinsCmd,	    TclCompileBasic1ArgCmd, NULL, NULL, 0},
    {"namespace",  InfoObjectNsCmd,	    TclCompileInfoObjectNamespaceCmd, NULL, NULL, 0},
    {"properties", TclOOInfoObjectPropCmd,  TclCompileBasicMin1ArgCmd, NULL, NULL, 0},
    {"variables",  InfoObjectVariablesCmd,  TclCompileBasic1Or2ArgCmd, NULL, NULL, 0},
    {"vars",	   InfoObjectVarsCmd,	    TclCompileBasic1Or2ArgCmd, NULL, NULL, 0},
    {NULL, NULL, NULL, NULL, NULL, 0}
};

/*
 * List of commands that are used to implement the [info class] subcommands.
 */

static const EnsembleImplMap infoClassCmds[] = {
    {"call",	     InfoClassCallCmd,		TclCompileBasic2ArgCmd, NULL, NULL, 0},
    {"constructor",  InfoClassConstrCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 0},
    {"definition",   InfoClassDefnCmd,		TclCompileBasic2ArgCmd, NULL, NULL, 0},
    {"definitionnamespace", InfoClassDefnNsCmd,	TclCompileBasic1Or2ArgCmd, NULL, NULL, 0},
    {"destructor",   InfoClassDestrCmd,		TclCompileBasic1ArgCmd, NULL, NULL, 0},
    {"filters",	     InfoClassFiltersCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 0},
    {"forward",	     InfoClassForwardCmd,	TclCompileBasic2ArgCmd, NULL, NULL, 0},
    {"instances",    InfoClassInstancesCmd,	TclCompileBasic1Or2ArgCmd, NULL, NULL, 0},
    {"methods",	     InfoClassMethodsCmd,	TclCompileBasicMin1ArgCmd, NULL, NULL, 0},
    {"methodtype",   InfoClassMethodTypeCmd,	TclCompileBasic2ArgCmd, NULL, NULL, 0},
    {"mixins",	     InfoClassMixinsCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 0},
    {"properties",   TclOOInfoClassPropCmd,	TclCompileBasicMin1ArgCmd, NULL, NULL, 0},
    {"subclasses",   InfoClassSubsCmd,		TclCompileBasic1Or2ArgCmd, NULL, NULL, 0},
    {"superclasses", InfoClassSupersCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 0},
    {"variables",    InfoClassVariablesCmd,	TclCompileBasic1Or2ArgCmd, NULL, NULL, 0},
    {NULL, NULL, NULL, NULL, NULL, 0}
};

/*
 * ----------------------------------------------------------------------
 *
 * LocalVarName --
 *
 *	Get the name of a local variable (especially a method argument) as a
 *	Tcl value.
 *
 * ----------------------------------------------------------------------
 */
static inline Tcl_Obj *
LocalVarName(
    CompiledLocal *localPtr)
{
    return Tcl_NewStringObj(localPtr->name, TCL_AUTO_LENGTH);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOInitInfo --
 *
 *	Adjusts the Tcl core [info] command to contain subcommands ("object"
 *	and "class") for introspection of objects and classes.
 *
 * ----------------------------------------------------------------------
 */

void
TclOOInitInfo(
    Tcl_Interp *interp)
{
    Tcl_Command infoCmd;
    Tcl_Obj *mapDict;

    /*
     * Build the ensembles used to implement [info object] and [info class].
     */

    TclMakeEnsemble(interp, "::oo::InfoObject", infoObjectCmds);
    TclMakeEnsemble(interp, "::oo::InfoClass", infoClassCmds);

    /*
     * Install into the [info] ensemble.
     */

    infoCmd = Tcl_FindCommand(interp, "info", NULL, TCL_GLOBAL_ONLY);
    if (infoCmd) {
	Tcl_GetEnsembleMappingDict(NULL, infoCmd, &mapDict);
	TclDictPutString(NULL, mapDict, "object", "::oo::InfoObject");
	TclDictPutString(NULL, mapDict, "class", "::oo::InfoClass");
	Tcl_SetEnsembleMappingDict(interp, infoCmd, mapDict);
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOGetClassFromObj --
 *
 *	How to correctly get a class from a Tcl_Obj. Just a wrapper round
 *	Tcl_GetObjectFromObj, but this is an idiom that was used heavily.
 *
 * ----------------------------------------------------------------------
 */

Class *
TclOOGetClassFromObj(
    Tcl_Interp *interp,
    Tcl_Obj *objPtr)
{
    Object *oPtr = (Object *) Tcl_GetObjectFromObj(interp, objPtr);

    if (oPtr == NULL) {
	return NULL;
    }
    if (oPtr->classPtr == NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"\"%s\" is not a class", TclGetString(objPtr)));
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "CLASS",
		TclGetString(objPtr), (char *)NULL);
	return NULL;
    }
    return oPtr->classPtr;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoObjectClassCmd --
 *
 *	Implements [info object class $objName ?$className?]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoObjectClassCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Object *oPtr;

    if (objc != 2 && objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "objName ?className?");
	return TCL_ERROR;
    }

    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[1]);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }

    if (objc == 2) {
	Tcl_SetObjResult(interp,
		TclOOObjectName(interp, oPtr->selfCls->thisPtr));
	return TCL_OK;
    } else {
	Class *mixinPtr, *o2clsPtr;
	Tcl_Size i;

	o2clsPtr = TclOOGetClassFromObj(interp, objv[2]);
	if (o2clsPtr == NULL) {
	    return TCL_ERROR;
	}

	FOREACH(mixinPtr, oPtr->mixins) {
	    if (!mixinPtr) {
		continue;
	    }
	    if (TclOOIsReachable(o2clsPtr, mixinPtr)) {
		Tcl_SetObjResult(interp, Tcl_NewBooleanObj(1));
		return TCL_OK;
	    }
	}
	Tcl_SetObjResult(interp, Tcl_NewBooleanObj(
		TclOOIsReachable(o2clsPtr, oPtr->selfCls)));
	return TCL_OK;
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoObjectDefnCmd --
 *
 *	Implements [info object definition $objName $methodName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoObjectDefnCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Object *oPtr;
    Tcl_HashEntry *hPtr;
    Proc *procPtr;
    CompiledLocal *localPtr;
    Tcl_Obj *resultObjs[2];

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "objName methodName");
	return TCL_ERROR;
    }

    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[1]);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }

    if (!oPtr->methodsPtr) {
	goto unknownMethod;
    }
    hPtr = Tcl_FindHashEntry(oPtr->methodsPtr, objv[2]);
    if (hPtr == NULL) {
	goto unknownMethod;
    }
    procPtr = TclOOGetProcFromMethod((Method *) Tcl_GetHashValue(hPtr));
    if (procPtr == NULL) {
	goto wrongType;
    }

    /*
     * We now have the method to describe the definition of.
     */

    TclNewObj(resultObjs[0]);
    for (localPtr=procPtr->firstLocalPtr; localPtr!=NULL;
	    localPtr=localPtr->nextPtr) {
	if (TclIsVarArgument(localPtr)) {
	    Tcl_Obj *argObj;

	    TclNewObj(argObj);
	    Tcl_ListObjAppendElement(NULL, argObj, LocalVarName(localPtr));
	    if (localPtr->defValuePtr != NULL) {
		Tcl_ListObjAppendElement(NULL, argObj, localPtr->defValuePtr);
	    }
	    Tcl_ListObjAppendElement(NULL, resultObjs[0], argObj);
	}
    }
    resultObjs[1] = TclOOGetMethodBody((Method *) Tcl_GetHashValue(hPtr));
    Tcl_SetObjResult(interp, Tcl_NewListObj(2, resultObjs));
    return TCL_OK;

    /*
     * Errors...
     */

  unknownMethod:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "unknown method \"%s\"", TclGetString(objv[2])));
    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "METHOD",
	    TclGetString(objv[2]), (char *)NULL);
    return TCL_ERROR;

  wrongType:
    Tcl_SetObjResult(interp, Tcl_NewStringObj(
	    "definition not available for this kind of method",
	    TCL_AUTO_LENGTH));
    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "METHOD",
	    TclGetString(objv[2]), (char *)NULL);
    return TCL_ERROR;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoObjectFiltersCmd --
 *
 *	Implements [info object filters $objName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoObjectFiltersCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_Size i;
    Tcl_Obj *filterObj, *resultObj;
    Object *oPtr;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "objName");
	return TCL_ERROR;
    }

    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[1]);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }
    TclNewObj(resultObj);

    FOREACH(filterObj, oPtr->filters) {
	Tcl_ListObjAppendElement(NULL, resultObj, filterObj);
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoObjectForwardCmd --
 *
 *	Implements [info object forward $objName $methodName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoObjectForwardCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Object *oPtr;
    Tcl_HashEntry *hPtr;
    Tcl_Obj *prefixObj;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "objName methodName");
	return TCL_ERROR;
    }

    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[1]);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }

    if (!oPtr->methodsPtr) {
	goto unknownMethod;
    }
    hPtr = Tcl_FindHashEntry(oPtr->methodsPtr, objv[2]);
    if (hPtr == NULL) {
	goto unknownMethod;
    }
    prefixObj = TclOOGetFwdFromMethod((Method *) Tcl_GetHashValue(hPtr));
    if (prefixObj == NULL) {
	goto wrongType;
    }

    /*
     * Describe the valid forward method.
     */

    Tcl_SetObjResult(interp, prefixObj);
    return TCL_OK;

    /*
     * Errors...
     */

  unknownMethod:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "unknown method \"%s\"", TclGetString(objv[2])));
    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "METHOD",
	    TclGetString(objv[2]), (char *)NULL);
    return TCL_ERROR;

  wrongType:
    Tcl_SetObjResult(interp, Tcl_NewStringObj(
	    "prefix argument list not available for this kind of method",
	    TCL_AUTO_LENGTH));
    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "METHOD",
	    TclGetString(objv[2]), (char *)NULL);
    return TCL_ERROR;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoObjectIsACmd --
 *
 *	Implements [info object isa $category $objName ...]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoObjectIsACmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    static const char *const categories[] = {
	"class", "metaclass", "mixin", "object", "typeof", NULL
    };
    enum IsACats {
	IsClass, IsMetaclass, IsMixin, IsObject, IsType
    } idx;
    Object *oPtr, *o2Ptr;
    int result = 0;
    Tcl_Size i;

    if (objc < 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "category objName ?arg ...?");
	return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObj(interp, objv[1], categories, "category", 0,
	    &idx) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Now we know what test we are doing, we can check we've got the right
     * number of arguments.
     */

    switch (idx) {
    case IsObject:
    case IsClass:
    case IsMetaclass:
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "objName");
	    return TCL_ERROR;
	}
	break;
    case IsMixin:
    case IsType:
	if (objc != 4) {
	    Tcl_WrongNumArgs(interp, 2, objv, "objName className");
	    return TCL_ERROR;
	}
	break;
    default:
	TCL_UNREACHABLE();
    }

    /*
     * Perform the check. Note that we can guarantee that we will not fail
     * from here on; "failures" result in a false-TCL_OK result.
     */

    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[2]);
    if (oPtr == NULL) {
	goto failPrecondition;
    }

    switch (idx) {
    case IsObject:
	result = 1;
	break;
    case IsClass:
	result = (oPtr->classPtr != NULL);
	break;
    case IsMetaclass:
	if (oPtr->classPtr != NULL) {
	    result = TclOOIsReachable(TclOOGetFoundation(interp)->classCls,
		    oPtr->classPtr);
	}
	break;
    case IsMixin:
	o2Ptr = (Object *) Tcl_GetObjectFromObj(interp, objv[3]);
	if (o2Ptr == NULL) {
	    goto failPrecondition;
	}
	if (o2Ptr->classPtr != NULL) {
	    Class *mixinPtr;

	    FOREACH(mixinPtr, oPtr->mixins) {
		if (!mixinPtr) {
		    continue;
		}
		if (TclOOIsReachable(o2Ptr->classPtr, mixinPtr)) {
		    result = 1;
		    break;
		}
	    }
	}
	break;
    case IsType:
	o2Ptr = (Object *) Tcl_GetObjectFromObj(interp, objv[3]);
	if (o2Ptr == NULL) {
	    goto failPrecondition;
	}
	if (o2Ptr->classPtr != NULL) {
	    result = TclOOIsReachable(o2Ptr->classPtr, oPtr->selfCls);
	}
	break;
    default:
	TCL_UNREACHABLE();
    }
    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(result));
    return TCL_OK;

  failPrecondition:
    Tcl_ResetResult(interp);
    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(0));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoObjectMethodsCmd --
 *
 *	Implements [info object methods $objName ?$option ...?]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoObjectMethodsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    static const char *const options[] = {
	"-all", "-localprivate", "-private", "-scope", NULL
    };
    enum Options {
	OPT_ALL, OPT_LOCALPRIVATE, OPT_PRIVATE, OPT_SCOPE
    } idx;
    static const char *const scopes[] = {
	"private", "public", "unexported"
    };
    enum Scopes {
	SCOPE_PRIVATE, SCOPE_PUBLIC, SCOPE_UNEXPORTED,
	SCOPE_LOCALPRIVATE,
	SCOPE_DEFAULT = -1
    };
    Object *oPtr;
    int flag = PUBLIC_METHOD, recurse = 0, scope = SCOPE_DEFAULT;
    FOREACH_HASH_DECLS;
    Tcl_Obj *namePtr, *resultObj;
    Method *mPtr;

    /*
     * Parse arguments.
     */

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "objName ?-option value ...?");
	return TCL_ERROR;
    }
    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[1]);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }
    if (objc != 2) {
	int i;

	for (i=2 ; i<objc ; i++) {
	    if (Tcl_GetIndexFromObj(interp, objv[i], options, "option", 0,
		    &idx) != TCL_OK) {
		return TCL_ERROR;
	    }
	    switch (idx) {
	    case OPT_ALL:
		recurse = 1;
		break;
	    case OPT_LOCALPRIVATE:
		flag = PRIVATE_METHOD;
		break;
	    case OPT_PRIVATE:
		flag = 0;
		break;
	    case OPT_SCOPE:
		if (++i >= objc) {
		    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			    "missing option for -scope"));
		    Tcl_SetErrorCode(interp, "TCL", "ARGUMENT", "MISSING",
			    (char *)NULL);
		    return TCL_ERROR;
		}
		if (Tcl_GetIndexFromObj(interp, objv[i], scopes, "scope", 0,
			&scope) != TCL_OK) {
		    return TCL_ERROR;
		}
		break;
	    default:
		TCL_UNREACHABLE();
	    }
	}
    }
    if (scope != SCOPE_DEFAULT) {
	recurse = 0;
	switch (scope) {
	case SCOPE_PRIVATE:
	    flag = TRUE_PRIVATE_METHOD;
	    break;
	case SCOPE_PUBLIC:
	    flag = PUBLIC_METHOD;
	    break;
	case SCOPE_LOCALPRIVATE:
	    flag = PRIVATE_METHOD;
	    break;
	case SCOPE_UNEXPORTED:
	    flag = 0;
	    break;
	}
    }

    /*
     * List matching methods.
     */

    TclNewObj(resultObj);
    if (recurse) {
	const char **names;
	int i, numNames = TclOOGetSortedMethodList(oPtr, NULL, NULL, flag,
		&names);

	for (i=0 ; i<numNames ; i++) {
	    Tcl_ListObjAppendElement(NULL, resultObj,
		    Tcl_NewStringObj(names[i], TCL_AUTO_LENGTH));
	}
	if (numNames > 0) {
	    Tcl_Free((void *)names);
	}
    } else if (oPtr->methodsPtr) {
	if (scope == SCOPE_DEFAULT) {
	    /*
	     * Handle legacy-mode matching. [Bug 36e5517a6850]
	     */
	    int scopeFilter = flag | TRUE_PRIVATE_METHOD;

	    FOREACH_HASH(namePtr, mPtr, oPtr->methodsPtr) {
		if (mPtr->typePtr && (mPtr->flags & scopeFilter) == flag) {
		    Tcl_ListObjAppendElement(NULL, resultObj, namePtr);
		}
	    }
	} else {
	    FOREACH_HASH(namePtr, mPtr, oPtr->methodsPtr) {
		if (mPtr->typePtr && (mPtr->flags & SCOPE_FLAGS) == flag) {
		    Tcl_ListObjAppendElement(NULL, resultObj, namePtr);
		}
	    }
	}
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoObjectMethodTypeCmd --
 *
 *	Implements [info object methodtype $objName $methodName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoObjectMethodTypeCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Object *oPtr;
    Tcl_HashEntry *hPtr;
    Method *mPtr;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "objName methodName");
	return TCL_ERROR;
    }

    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[1]);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }

    if (!oPtr->methodsPtr) {
	goto unknownMethod;
    }
    hPtr = Tcl_FindHashEntry(oPtr->methodsPtr, objv[2]);
    if (hPtr == NULL) {
	goto unknownMethod;
    }
    mPtr = (Method *) Tcl_GetHashValue(hPtr);
    if (mPtr->typePtr == NULL) {
	/*
	 * Special entry for visibility control: pretend the method doesnt
	 * exist.
	 */

	goto unknownMethod;
    }

    Tcl_SetObjResult(interp,
	    Tcl_NewStringObj(mPtr->typePtr->name, TCL_AUTO_LENGTH));
    return TCL_OK;

  unknownMethod:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "unknown method \"%s\"", TclGetString(objv[2])));
    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "METHOD",
	    TclGetString(objv[2]), (char *)NULL);
    return TCL_ERROR;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoObjectMixinsCmd --
 *
 *	Implements [info object mixins $objName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoObjectMixinsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Class *mixinPtr;
    Object *oPtr;
    Tcl_Obj *resultObj;
    Tcl_Size i;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "objName");
	return TCL_ERROR;
    }
    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[1]);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }

    TclNewObj(resultObj);
    FOREACH(mixinPtr, oPtr->mixins) {
	if (!mixinPtr) {
	    continue;
	}
	Tcl_ListObjAppendElement(NULL, resultObj,
		TclOOObjectName(interp, mixinPtr->thisPtr));
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoObjectIdCmd --
 *
 *	Implements [info object creationid $objName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoObjectIdCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Object *oPtr;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "objName");
	return TCL_ERROR;
    }
    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[1]);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(oPtr->creationEpoch));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoObjectNsCmd --
 *
 *	Implements [info object namespace $objName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoObjectNsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Object *oPtr;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "objName");
	return TCL_ERROR;
    }
    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[1]);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, TclNewNamespaceObj(oPtr->namespacePtr));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoObjectVariablesCmd --
 *
 *	Implements [info object variables $objName ?-private?]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoObjectVariablesCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Object *oPtr;
    Tcl_Obj *resultObj;
    Tcl_Size i;
    int isPrivate = 0;

    if (objc != 2 && objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "objName ?-private?");
	return TCL_ERROR;
    }
    if (objc == 3) {
	if (strcmp("-private", TclGetString(objv[2])) != 0) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "option \"%s\" is not exactly \"-private\"",
		    TclGetString(objv[2])));
	    OO_ERROR(interp, BAD_ARG);
	    return TCL_ERROR;
	}
	isPrivate = 1;
    }
    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[1]);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }

    TclNewObj(resultObj);
    if (isPrivate) {
	PrivateVariableMapping *privatePtr;

	FOREACH_STRUCT(privatePtr, oPtr->privateVariables) {
	    Tcl_ListObjAppendElement(NULL, resultObj, privatePtr->variableObj);
	}
    } else {
	Tcl_Obj *variableObj;

	FOREACH(variableObj, oPtr->variables) {
	    Tcl_ListObjAppendElement(NULL, resultObj, variableObj);
	}
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoObjectVarsCmd --
 *
 *	Implements [info object vars $objName ?$pattern?]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoObjectVarsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Object *oPtr;
    const char *pattern = NULL;
    FOREACH_HASH_DECLS;
    VarInHash *vihPtr;
    Tcl_Obj *nameObj, *resultObj;

    if (objc != 2 && objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "objName ?pattern?");
	return TCL_ERROR;
    }
    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[1]);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }
    if (objc == 3) {
	pattern = TclGetString(objv[2]);
    }
    TclNewObj(resultObj);

    /*
     * Extract the information we need from the object's namespace's table of
     * variables. Note that this involves horrific knowledge of the guts of
     * tclVar.c, so we can't leverage our hash-iteration macros properly.
     */

    FOREACH_HASH_VALUE(vihPtr,
	    &((Namespace *) oPtr->namespacePtr)->varTable.table) {
	nameObj = vihPtr->entry.key.objPtr;

	if (TclIsVarUndefined(&vihPtr->var)
		|| !TclIsVarNamespaceVar(&vihPtr->var)) {
	    continue;
	}
	if (pattern != NULL
		&& !Tcl_StringMatch(TclGetString(nameObj), pattern)) {
	    continue;
	}
	Tcl_ListObjAppendElement(NULL, resultObj, nameObj);
    }

    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassConstrCmd --
 *
 *	Implements [info class constructor $clsName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassConstrCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Proc *procPtr;
    CompiledLocal *localPtr;
    Tcl_Obj *resultObjs[2];
    Class *clsPtr;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "className");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }
    if (clsPtr->constructorPtr == NULL) {
	return TCL_OK;
    }
    procPtr = TclOOGetProcFromMethod(clsPtr->constructorPtr);
    if (procPtr == NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"definition not available for this kind of method",
		TCL_AUTO_LENGTH));
	OO_ERROR(interp, METHOD_TYPE);
	return TCL_ERROR;
    }

    TclNewObj(resultObjs[0]);
    for (localPtr=procPtr->firstLocalPtr; localPtr!=NULL;
	    localPtr=localPtr->nextPtr) {
	if (TclIsVarArgument(localPtr)) {
	    Tcl_Obj *argObj;

	    TclNewObj(argObj);
	    Tcl_ListObjAppendElement(NULL, argObj, LocalVarName(localPtr));
	    if (localPtr->defValuePtr != NULL) {
		Tcl_ListObjAppendElement(NULL, argObj, localPtr->defValuePtr);
	    }
	    Tcl_ListObjAppendElement(NULL, resultObjs[0], argObj);
	}
    }
    resultObjs[1] = TclOOGetMethodBody(clsPtr->constructorPtr);
    Tcl_SetObjResult(interp, Tcl_NewListObj(2, resultObjs));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassDefnCmd --
 *
 *	Implements [info class definition $clsName $methodName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassDefnCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_HashEntry *hPtr;
    Proc *procPtr;
    CompiledLocal *localPtr;
    Tcl_Obj *resultObjs[2];
    Class *clsPtr;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "className methodName");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }
    hPtr = Tcl_FindHashEntry(&clsPtr->classMethods, objv[2]);
    if (hPtr == NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"unknown method \"%s\"", TclGetString(objv[2])));
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "METHOD",
		TclGetString(objv[2]), (char *)NULL);
	return TCL_ERROR;
    }
    procPtr = TclOOGetProcFromMethod((Method *) Tcl_GetHashValue(hPtr));
    if (procPtr == NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"definition not available for this kind of method",
		TCL_AUTO_LENGTH));
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "METHOD",
		TclGetString(objv[2]), (char *)NULL);
	return TCL_ERROR;
    }

    TclNewObj(resultObjs[0]);
    for (localPtr=procPtr->firstLocalPtr; localPtr!=NULL;
	    localPtr=localPtr->nextPtr) {
	if (TclIsVarArgument(localPtr)) {
	    Tcl_Obj *argObj;

	    TclNewObj(argObj);
	    Tcl_ListObjAppendElement(NULL, argObj, LocalVarName(localPtr));
	    if (localPtr->defValuePtr != NULL) {
		Tcl_ListObjAppendElement(NULL, argObj, localPtr->defValuePtr);
	    }
	    Tcl_ListObjAppendElement(NULL, resultObjs[0], argObj);
	}
    }
    resultObjs[1] = TclOOGetMethodBody((Method *) Tcl_GetHashValue(hPtr));
    Tcl_SetObjResult(interp, Tcl_NewListObj(2, resultObjs));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassDefnNsCmd --
 *
 *	Implements [info class definitionnamespace $clsName ?$kind?]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassDefnNsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    static const char *kindList[] = {
	"-class",
	"-instance",
	NULL
    };
    int kind = 0;
    Tcl_Obj *nsNamePtr;
    Class *clsPtr;

    if (objc != 2 && objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "className ?kind?");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }
    if (objc == 3 && Tcl_GetIndexFromObj(interp, objv[2], kindList, "kind", 0,
	    &kind) != TCL_OK) {
	return TCL_ERROR;
    }

    if (kind) {			// -instance
	nsNamePtr = clsPtr->objDefinitionNs;
    } else {			// -class
	nsNamePtr = clsPtr->clsDefinitionNs;
    }
    if (nsNamePtr) {
	Tcl_SetObjResult(interp, nsNamePtr);
    }
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassDestrCmd --
 *
 *	Implements [info class destructor $clsName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassDestrCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Proc *procPtr;
    Class *clsPtr;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "className");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }

    if (clsPtr->destructorPtr == NULL) {
	return TCL_OK;
    }
    procPtr = TclOOGetProcFromMethod(clsPtr->destructorPtr);
    if (procPtr == NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"definition not available for this kind of method",
		TCL_AUTO_LENGTH));
	OO_ERROR(interp, METHOD_TYPE);
	return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, TclOOGetMethodBody(clsPtr->destructorPtr));
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassFiltersCmd --
 *
 *	Implements [info class filters $clsName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassFiltersCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_Size i;
    Tcl_Obj *filterObj, *resultObj;
    Class *clsPtr;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "className");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }

    TclNewObj(resultObj);
    FOREACH(filterObj, clsPtr->filters) {
	Tcl_ListObjAppendElement(NULL, resultObj, filterObj);
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassForwardCmd --
 *
 *	Implements [info class forward $clsName $methodName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassForwardCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_HashEntry *hPtr;
    Tcl_Obj *prefixObj;
    Class *clsPtr;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "className methodName");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }
    hPtr = Tcl_FindHashEntry(&clsPtr->classMethods, objv[2]);
    if (hPtr == NULL) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"unknown method \"%s\"", TclGetString(objv[2])));
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "METHOD",
		TclGetString(objv[2]), (char *)NULL);
	return TCL_ERROR;
    }
    prefixObj = TclOOGetFwdFromMethod((Method *) Tcl_GetHashValue(hPtr));
    if (prefixObj == NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"prefix argument list not available for this kind of method",
		TCL_AUTO_LENGTH));
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "METHOD",
		TclGetString(objv[2]), (char *)NULL);
	return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, prefixObj);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassInstancesCmd --
 *
 *	Implements [info class instances $clsName ?$pattern?]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassInstancesCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Object *oPtr;
    Class *clsPtr;
    Tcl_Size i;
    const char *pattern = NULL;
    Tcl_Obj *resultObj;

    if (objc != 2 && objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "className ?pattern?");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }
    if (objc == 3) {
	pattern = TclGetString(objv[2]);
    }

    TclNewObj(resultObj);
    FOREACH(oPtr, clsPtr->instances) {
	Tcl_Obj *tmpObj = TclOOObjectName(interp, oPtr);

	if (pattern && !Tcl_StringMatch(TclGetString(tmpObj), pattern)) {
	    continue;
	}
	Tcl_ListObjAppendElement(NULL, resultObj, tmpObj);
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassMethodsCmd --
 *
 *	Implements [info class methods $clsName ?options...?]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassMethodsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    static const char *const options[] = {
	"-all", "-localprivate", "-private", "-scope", NULL
    };
    enum Options {
	OPT_ALL, OPT_LOCALPRIVATE, OPT_PRIVATE, OPT_SCOPE
    } idx;
    static const char *const scopes[] = {
	"private", "public", "unexported"
    };
    enum Scopes {
	SCOPE_PRIVATE, SCOPE_PUBLIC, SCOPE_UNEXPORTED,
	SCOPE_DEFAULT = -1
    };
    int flag = PUBLIC_METHOD, recurse = 0, scope = SCOPE_DEFAULT;
    Tcl_Obj *namePtr, *resultObj;
    Method *mPtr;
    Class *clsPtr;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "className ?-option value ...?");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }
    if (objc != 2) {
	int i;

	for (i=2 ; i<objc ; i++) {
	    if (Tcl_GetIndexFromObj(interp, objv[i], options, "option", 0,
		    &idx) != TCL_OK) {
		return TCL_ERROR;
	    }
	    switch (idx) {
	    case OPT_ALL:
		recurse = 1;
		break;
	    case OPT_LOCALPRIVATE:
		flag = PRIVATE_METHOD;
		break;
	    case OPT_PRIVATE:
		flag = 0;
		break;
	    case OPT_SCOPE:
		if (++i >= objc) {
		    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			    "missing option for -scope"));
		    Tcl_SetErrorCode(interp, "TCL", "ARGUMENT", "MISSING",
			    (char *)NULL);
		    return TCL_ERROR;
		}
		if (Tcl_GetIndexFromObj(interp, objv[i], scopes, "scope", 0,
			&scope) != TCL_OK) {
		    return TCL_ERROR;
		}
		break;
	    default:
		TCL_UNREACHABLE();
	    }
	}
    }
    if (scope != SCOPE_DEFAULT) {
	recurse = 0;
	switch (scope) {
	case SCOPE_PRIVATE:
	    flag = TRUE_PRIVATE_METHOD;
	    break;
	case SCOPE_PUBLIC:
	    flag = PUBLIC_METHOD;
	    break;
	case SCOPE_UNEXPORTED:
	    flag = 0;
	    break;
	default:
	    TCL_UNREACHABLE();
	}
    }

    TclNewObj(resultObj);
    if (recurse) {
	const char **names;
	Tcl_Size i, numNames = TclOOGetSortedClassMethodList(clsPtr, flag, &names);

	for (i=0 ; i<numNames ; i++) {
	    Tcl_ListObjAppendElement(NULL, resultObj,
		    Tcl_NewStringObj(names[i], TCL_AUTO_LENGTH));
	}
	if (numNames > 0) {
	    Tcl_Free((void *)names);
	}
    } else {
	FOREACH_HASH_DECLS;

	if (scope == SCOPE_DEFAULT) {
	    /*
	     * Handle legacy-mode matching. [Bug 36e5517a6850]
	     */
	    int scopeFilter = flag | TRUE_PRIVATE_METHOD;

	    FOREACH_HASH(namePtr, mPtr, &clsPtr->classMethods) {
		if (mPtr->typePtr && (mPtr->flags & scopeFilter) == flag) {
		    Tcl_ListObjAppendElement(NULL, resultObj, namePtr);
		}
	    }
	} else {
	    FOREACH_HASH(namePtr, mPtr, &clsPtr->classMethods) {
		if (mPtr->typePtr && (mPtr->flags & SCOPE_FLAGS) == flag) {
		    Tcl_ListObjAppendElement(NULL, resultObj, namePtr);
		}
	    }
	}
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassMethodTypeCmd --
 *
 *	Implements [info class methodtype $clsName $methodName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassMethodTypeCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Tcl_HashEntry *hPtr;
    Method *mPtr;
    Class *clsPtr;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "className methodName");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }

    hPtr = Tcl_FindHashEntry(&clsPtr->classMethods, objv[2]);
    if (hPtr == NULL) {
	goto unknownMethod;
    }
    mPtr = (Method *) Tcl_GetHashValue(hPtr);
    if (mPtr->typePtr == NULL) {
	/*
	 * Special entry for visibility control: pretend the method doesnt
	 * exist.
	 */

	goto unknownMethod;
    }
    Tcl_SetObjResult(interp,
	    Tcl_NewStringObj(mPtr->typePtr->name, TCL_AUTO_LENGTH));
    return TCL_OK;

  unknownMethod:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "unknown method \"%s\"", TclGetString(objv[2])));
    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "METHOD",
	    TclGetString(objv[2]), (char *)NULL);
    return TCL_ERROR;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassMixinsCmd --
 *
 *	Implements [info class mixins $clsName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassMixinsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Class *clsPtr, *mixinPtr;
    Tcl_Obj *resultObj;
    Tcl_Size i;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "className");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }

    TclNewObj(resultObj);
    FOREACH(mixinPtr, clsPtr->mixins) {
	if (!mixinPtr) {
	    continue;
	}
	Tcl_ListObjAppendElement(NULL, resultObj,
		TclOOObjectName(interp, mixinPtr->thisPtr));
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassSubsCmd --
 *
 *	Implements [info class subclasses $clsName ?$pattern?]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassSubsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Class *clsPtr, *subclassPtr;
    Tcl_Obj *resultObj;
    Tcl_Size i;
    const char *pattern = NULL;

    if (objc != 2 && objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "className ?pattern?");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }
    if (objc == 3) {
	pattern = TclGetString(objv[2]);
    }

    TclNewObj(resultObj);
    FOREACH(subclassPtr, clsPtr->subclasses) {
	Tcl_Obj *tmpObj = TclOOObjectName(interp, subclassPtr->thisPtr);

	if (pattern && !Tcl_StringMatch(TclGetString(tmpObj), pattern)) {
	    continue;
	}
	Tcl_ListObjAppendElement(NULL, resultObj, tmpObj);
    }
    FOREACH(subclassPtr, clsPtr->mixinSubs) {
	Tcl_Obj *tmpObj = TclOOObjectName(interp, subclassPtr->thisPtr);

	if (pattern && !Tcl_StringMatch(TclGetString(tmpObj), pattern)) {
	    continue;
	}
	Tcl_ListObjAppendElement(NULL, resultObj, tmpObj);
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassSupersCmd --
 *
 *	Implements [info class superclasses $clsName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassSupersCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Class *clsPtr, *superPtr;
    Tcl_Obj *resultObj;
    Tcl_Size i;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "className");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }

    TclNewObj(resultObj);
    FOREACH(superPtr, clsPtr->superclasses) {
	Tcl_ListObjAppendElement(NULL, resultObj,
		TclOOObjectName(interp, superPtr->thisPtr));
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassVariablesCmd --
 *
 *	Implements [info class variables $clsName ?-private?]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassVariablesCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Class *clsPtr;
    Tcl_Obj *resultObj;
    Tcl_Size i;
    int isPrivate = 0;

    if (objc != 2 && objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "className ?-private?");
	return TCL_ERROR;
    }
    if (objc == 3) {
	if (strcmp("-private", TclGetString(objv[2])) != 0) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "option \"%s\" is not exactly \"-private\"",
		    TclGetString(objv[2])));
	    OO_ERROR(interp, BAD_ARG);
	    return TCL_ERROR;
	}
	isPrivate = 1;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }

    TclNewObj(resultObj);
    if (isPrivate) {
	PrivateVariableMapping *privatePtr;

	FOREACH_STRUCT(privatePtr, clsPtr->privateVariables) {
	    Tcl_ListObjAppendElement(NULL, resultObj, privatePtr->variableObj);
	}
    } else {
	Tcl_Obj *variableObj;

	FOREACH(variableObj, clsPtr->variables) {
	    Tcl_ListObjAppendElement(NULL, resultObj, variableObj);
	}
    }
    Tcl_SetObjResult(interp, resultObj);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoObjectCallCmd --
 *
 *	Implements [info object call $objName $methodName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoObjectCallCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Object *oPtr;
    CallContext *contextPtr;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "objName methodName");
	return TCL_ERROR;
    }
    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[1]);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }

    /*
     * Get the call context and render its call chain.
     */

    contextPtr = TclOOGetCallContext(oPtr, objv[2], PUBLIC_METHOD, NULL, NULL,
	    NULL);
    if (contextPtr == NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"cannot construct any call chain", TCL_AUTO_LENGTH));
	OO_ERROR(interp, BAD_CALL_CHAIN);
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp,
	    TclOORenderCallChain(interp, contextPtr->callPtr));
    TclOODeleteContext(contextPtr);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InfoClassCallCmd --
 *
 *	Implements [info class call $clsName $methodName]
 *
 * ----------------------------------------------------------------------
 */

static int
InfoClassCallCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Class *clsPtr;
    CallChain *callPtr;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "className methodName");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }

    /*
     * Get an render the stereotypical call chain.
     */

    callPtr = TclOOGetStereotypeCallChain(clsPtr, objv[2], PUBLIC_METHOD);
    if (callPtr == NULL) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"cannot construct any call chain", TCL_AUTO_LENGTH));
	OO_ERROR(interp, BAD_CALL_CHAIN);
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, TclOORenderCallChain(interp, callPtr));
    TclOODeleteChain(callPtr);
    return TCL_OK;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
