/*
 * tclOOProp.c --
 *
 *	This file contains implementations of the configurable property
 *	mecnanisms.
 *
 * Copyright © 2023-2024 Donal K. Fellows
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclOOInt.h"

/* Short-term cache for GetPropertyName(). */
typedef struct GPNCache {
    Tcl_Obj *listPtr;		/* Holds references to names. */
    char *names[TCLFLEXARRAY];	/* NULL-terminated table of names. */
} GPNCache;

enum GPNFlags {
    GPN_WRITABLE = 1,		/* Are we looking for a writable property? */
    GPN_FALLING_BACK = 2	/* Are we doing a recursive call to determine
				 * if the property is of the other type? */
};

/*
 * Shared bits for [property] declarations.
 */
enum PropOpt {
    PROP_ALL, PROP_READABLE, PROP_WRITABLE
};
static const char *const propOptNames[] = {
    "-all", "-readable", "-writable",
    NULL
};

/*
 * Forward declarations.
 */

static int		Configurable_Getter(void *clientData,
			    Tcl_Interp *interp, Tcl_ObjectContext context,
			    int objc, Tcl_Obj *const *objv);
static int		Configurable_Setter(void *clientData,
			    Tcl_Interp *interp, Tcl_ObjectContext context,
			    int objc, Tcl_Obj *const *objv);
static void		DetailsDeleter(void *clientData);
static int		DetailsCloner(Tcl_Interp *, void *oldClientData,
			    void **newClientData);
static void		ImplementObjectProperty(Tcl_Object targetObject,
			    Tcl_Obj *propNamePtr, int installGetter,
			    int installSetter);
static void		ImplementClassProperty(Tcl_Class targetObject,
			    Tcl_Obj *propNamePtr, int installGetter,
			    int installSetter);

/*
 * Method descriptors
 */

static const Tcl_MethodType GetterType = {
    TCL_OO_METHOD_VERSION_1,
    "PropertyGetter",
    Configurable_Getter,
    DetailsDeleter,
    DetailsCloner
};

static const Tcl_MethodType SetterType = {
    TCL_OO_METHOD_VERSION_1,
    "PropertySetter",
    Configurable_Setter,
    DetailsDeleter,
    DetailsCloner
};

/*
 * ----------------------------------------------------------------------
 *
 * TclOO_Configurable_Configure --
 *
 *	Implementation of the oo::configurable->configure method.
 *
 * ----------------------------------------------------------------------
 */

/*
 * Ugly thunks to read and write a property by calling the right method in
 * the right way. Note that we MUST be correct in holding references to Tcl_Obj
 * values, as this is potentially a call into user code.
 */
static inline int
ReadProperty(
    Tcl_Interp *interp,
    Object *oPtr,
    const char *propName)
{
    Tcl_Obj *args[] = {
	oPtr->fPtr->myName,
	Tcl_ObjPrintf("<ReadProp%s>", propName)
    };
    int code;

    Tcl_IncrRefCount(args[0]);
    Tcl_IncrRefCount(args[1]);
    code = TclOOPrivateObjectCmd(oPtr, interp, 2, args);
    Tcl_DecrRefCount(args[0]);
    Tcl_DecrRefCount(args[1]);
    switch (code) {
    case TCL_BREAK:
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"property getter for %s did a break", propName));
	return TCL_ERROR;
    case TCL_CONTINUE:
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"property getter for %s did a continue", propName));
	return TCL_ERROR;
    default:
	return code;
    }
}

static inline int
WriteProperty(
    Tcl_Interp *interp,
    Object *oPtr,
    const char *propName,
    Tcl_Obj *valueObj)
{
    Tcl_Obj *args[] = {
	oPtr->fPtr->myName,
	Tcl_ObjPrintf("<WriteProp%s>", propName),
	valueObj
    };
    int code;

    Tcl_IncrRefCount(args[0]);
    Tcl_IncrRefCount(args[1]);
    Tcl_IncrRefCount(args[2]);
    code = TclOOPrivateObjectCmd(oPtr, interp, 3, args);
    Tcl_DecrRefCount(args[0]);
    Tcl_DecrRefCount(args[1]);
    Tcl_DecrRefCount(args[2]);
    switch (code) {
    case TCL_BREAK:
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"property setter for %s did a break", propName));
	return TCL_ERROR;
    case TCL_CONTINUE:
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"property setter for %s did a continue", propName));
	return TCL_ERROR;
    default:
	return code;
    }
}

/* Look up a property full name. */
static Tcl_Obj *
GetPropertyName(
    Tcl_Interp *interp,		/* Context and error reporting. */
    Object *oPtr,		/* Object to get property name from. */
    int flags,			/* Are we looking for a writable property?
				 * Can we do a fallback message?
				 * See GPNFlags for possible values */
    Tcl_Obj *namePtr,		/* The name supplied by the user. */
    GPNCache **cachePtr)	/* Where to cache the table, if the caller
				 * wants that. The contents are to be freed
				 * with Tcl_Free if the cache is used. */
{
    Tcl_Size objc, index, i;
    Tcl_Obj *listPtr = TclOOGetAllObjectProperties(
	    oPtr, flags & GPN_WRITABLE);
    Tcl_Obj **objv;
    GPNCache *tablePtr;

    (void) Tcl_ListObjGetElements(NULL, listPtr, &objc, &objv);
    if (cachePtr && *cachePtr) {
	tablePtr = *cachePtr;
    } else {
	tablePtr = (GPNCache *) TclStackAlloc(interp,
		offsetof(GPNCache, names) + sizeof(char *) * (objc + 1));

	for (i = 0; i < objc; i++) {
	    tablePtr->names[i] = TclGetString(objv[i]);
	}
	tablePtr->names[objc] = NULL;
	if (cachePtr) {
	    /*
	     * Have a cache, but nothing in it so far.
	     *
	     * We cache the list here so it doesn't vanish from under our
	     * feet if a property implementation does something crazy like
	     * changing the set of properties. The type of copy this does
	     * means that the copy holds the references to the names in the
	     * table.
	     */
	    tablePtr->listPtr = TclListObjCopy(NULL, listPtr);
	    Tcl_IncrRefCount(tablePtr->listPtr);
	    *cachePtr = tablePtr;
	} else {
	    tablePtr->listPtr = NULL;
	}
    }
    int result = Tcl_GetIndexFromObjStruct(interp, namePtr, tablePtr->names,
	    sizeof(char *), "property", TCL_INDEX_TEMP_TABLE, &index);
    if (result == TCL_ERROR && !(flags & GPN_FALLING_BACK)) {
	/*
	 * If property can be accessed the other way, use a special message.
	 * We use a recursive call to look this up.
	 */

	Tcl_InterpState foo = Tcl_SaveInterpState(interp, result);
	Tcl_Obj *otherName = GetPropertyName(interp, oPtr,
		flags ^ (GPN_WRITABLE | GPN_FALLING_BACK), namePtr, NULL);
	result = Tcl_RestoreInterpState(interp, foo);
	if (otherName != NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "property \"%s\" is %s only",
		    TclGetString(otherName),
		    (flags & GPN_WRITABLE) ? "read" : "write"));
	}
    }
    if (!cachePtr) {
	TclStackFree(interp, tablePtr);
    }
    if (result != TCL_OK) {
	return NULL;
    }
    return objv[index];
}

/* Release the cache made by GetPropertyName(). */
static inline void
ReleasePropertyNameCache(
    Tcl_Interp *interp,
    GPNCache **cachePtr)
{
    if (*cachePtr) {
	GPNCache *tablePtr = *cachePtr;
	if (tablePtr->listPtr) {
	    Tcl_DecrRefCount(tablePtr->listPtr);
	}
	TclStackFree(interp, tablePtr);
	*cachePtr = NULL;
    }
}

int
TclOO_Configurable_Configure(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Interpreter used for the result, error
				 * reporting, etc. */
    Tcl_ObjectContext context,	/* The object/call context. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const *objv)	/* The actual arguments. */
{
    Object *oPtr = (Object *) Tcl_ObjectContextObject(context);
    Tcl_Size skip = Tcl_ObjectContextSkippedArgs(context);
    Tcl_Obj *namePtr;
    Tcl_Size i, namec;
    int code = TCL_OK;

    objc -= skip;
    if ((objc & 1) && (objc != 1)) {
	/*
	 * Bad (odd > 1) number of arguments.
	 */

	Tcl_WrongNumArgs(interp, skip, objv, "?-option value ...?");
	return TCL_ERROR;
    }

    objv += skip;
    if (objc == 0) {
	/*
	 * Read all properties.
	 */

	Tcl_Obj *listPtr = TclOOGetAllObjectProperties(oPtr, 0);
	Tcl_Obj *resultPtr = Tcl_NewObj(), **namev;

	Tcl_IncrRefCount(listPtr);
	ListObjGetElements(listPtr, namec, namev);

	for (i = 0; i < namec; ) {
	    code = ReadProperty(interp, oPtr, TclGetString(namev[i]));
	    if (code != TCL_OK) {
		Tcl_DecrRefCount(resultPtr);
		break;
	    }
	    Tcl_DictObjPut(NULL, resultPtr, namev[i],
		    Tcl_GetObjResult(interp));
	    if (++i >= namec) {
		Tcl_SetObjResult(interp, resultPtr);
		break;
	    }
	    Tcl_SetObjResult(interp, Tcl_NewObj());
	}
	Tcl_DecrRefCount(listPtr);
	return code;
    } else if (objc == 1) {
	/*
	 * Read a single named property.
	 */

	namePtr = GetPropertyName(interp, oPtr, 0, objv[0], NULL);
	if (namePtr == NULL) {
	    return TCL_ERROR;
	}
	return ReadProperty(interp, oPtr, TclGetString(namePtr));
    } else if (objc == 2) {
	/*
	 * Special case for writing to one property. Saves fiddling with the
	 * cache in this common case.
	 */

	namePtr = GetPropertyName(interp, oPtr, GPN_WRITABLE, objv[0], NULL);
	if (namePtr == NULL) {
	    return TCL_ERROR;
	}
	code = WriteProperty(interp, oPtr, TclGetString(namePtr), objv[1]);
	if (code == TCL_OK) {
	    Tcl_ResetResult(interp);
	}
	return code;
    } else {
	/*
	 * Write properties. Slightly tricky because we want to cache the
	 * table of property names.
	 */
	GPNCache *cache = NULL;

	code = TCL_OK;
	for (i = 0; i < objc; i += 2) {
	    namePtr = GetPropertyName(interp, oPtr, GPN_WRITABLE, objv[i],
		    &cache);
	    if (namePtr == NULL) {
		code = TCL_ERROR;
		break;
	    }
	    code = WriteProperty(interp, oPtr, TclGetString(namePtr),
		    objv[i + 1]);
	    if (code != TCL_OK) {
		break;
	    }
	}
	if (code == TCL_OK) {
	    Tcl_ResetResult(interp);
	}
	ReleasePropertyNameCache(interp, &cache);
	return code;
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * Configurable_Getter, Configurable_Setter --
 *
 *	Standard property implementation. The clientData is a simple Tcl_Obj*
 *	that contains the name of the property.
 *
 * ----------------------------------------------------------------------
 */

static int
Configurable_Getter(
    void *clientData,		/* Which property to read. Actually a Tcl_Obj*
				 * reference that is the name of the variable
				 * in the cpntext object. */
    Tcl_Interp *interp,		/* Interpreter used for the result, error
				 * reporting, etc. */
    Tcl_ObjectContext context,	/* The object/call context. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const *objv)	/* The actual arguments. */
{
    Tcl_Obj *propNamePtr = (Tcl_Obj *) clientData;
    Tcl_Var varPtr, aryVar;
    Tcl_Obj *valuePtr;

    if ((int) Tcl_ObjectContextSkippedArgs(context) != objc) {
	Tcl_WrongNumArgs(interp, Tcl_ObjectContextSkippedArgs(context),
		objv, NULL);
	return TCL_ERROR;
    }

    varPtr = TclOOLookupObjectVar(interp, Tcl_ObjectContextObject(context),
	    propNamePtr, &aryVar);
    if (varPtr == NULL) {
	return TCL_ERROR;
    }

    valuePtr = TclPtrGetVar(interp, varPtr, aryVar, propNamePtr, NULL,
	    TCL_NAMESPACE_ONLY | TCL_LEAVE_ERR_MSG);
    if (valuePtr == NULL) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, valuePtr);
    return TCL_OK;
}

static int
Configurable_Setter(
    void *clientData,		/* Which property to write. Actually a Tcl_Obj*
				 * reference that is the name of the variable
				 * in the cpntext object. */
    Tcl_Interp *interp,		/* Interpreter used for the result, error
				 * reporting, etc. */
    Tcl_ObjectContext context,	/* The object/call context. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const *objv)	/* The actual arguments. */
{
    Tcl_Obj *propNamePtr = (Tcl_Obj *) clientData;
    Tcl_Var varPtr, aryVar;

    if ((int) Tcl_ObjectContextSkippedArgs(context) + 1 != objc) {
	Tcl_WrongNumArgs(interp, Tcl_ObjectContextSkippedArgs(context),
		objv, "value");
	return TCL_ERROR;
    }

    varPtr = TclOOLookupObjectVar(interp, Tcl_ObjectContextObject(context),
	    propNamePtr, &aryVar);
    if (varPtr == NULL) {
	return TCL_ERROR;
    }

    if (TclPtrSetVar(interp, varPtr, aryVar, propNamePtr, NULL,
	    objv[objc - 1], TCL_NAMESPACE_ONLY | TCL_LEAVE_ERR_MSG) == NULL) {
	return TCL_ERROR;
    }
    return TCL_OK;
}

// Simple support functions
static void
DetailsDeleter(
    void *clientData)
{
    // Just drop the reference count
    Tcl_Obj *propNamePtr = (Tcl_Obj *) clientData;
    Tcl_DecrRefCount(propNamePtr);
}

static int
DetailsCloner(
    TCL_UNUSED(Tcl_Interp *),
    void *oldClientData,
    void **newClientData)
{
    // Just add another reference to this name; easy!
    Tcl_Obj *propNamePtr = (Tcl_Obj *) oldClientData;
    Tcl_IncrRefCount(propNamePtr);
    *newClientData = propNamePtr;
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * ImplementObjectProperty, ImplementClassProperty --
 *
 *	Installs a basic property implementation for a property, either on
 *	an instance or on a class. It's up to the code that calls these
 *	to ensure that the property name is syntactically valid.
 *
 * ----------------------------------------------------------------------
 */

void
ImplementObjectProperty(
    Tcl_Object targetObject,	/* What to install into. */
    Tcl_Obj *propNamePtr,	/* Property name. */
    int installGetter,		/* Whether to install a standard getter. */
    int installSetter)		/* Whether to install a standard setter. */
{
    const char *propName = TclGetString(propNamePtr);

    while (propName[0] == '-') {
	propName++;
    }
    if (installGetter) {
	Tcl_Obj *methodName = Tcl_ObjPrintf("<ReadProp-%s>", propName);
	Tcl_IncrRefCount(propNamePtr); // Paired with DetailsDeleter
	TclNewInstanceMethod(
		NULL, targetObject, methodName, 0, &GetterType, propNamePtr);
	Tcl_BounceRefCount(methodName);
    }
    if (installSetter) {
	Tcl_Obj *methodName = Tcl_ObjPrintf("<WriteProp-%s>", propName);
	Tcl_IncrRefCount(propNamePtr); // Paired with DetailsDeleter
	TclNewInstanceMethod(
		NULL, targetObject, methodName, 0, &SetterType, propNamePtr);
	Tcl_BounceRefCount(methodName);
    }
}

void
ImplementClassProperty(
    Tcl_Class targetClass,	/* What to install into. */
    Tcl_Obj *propNamePtr,	/* Property name. */
    int installGetter,		/* Whether to install a standard getter. */
    int installSetter)		/* Whether to install a standard setter. */
{
    const char *propName = TclGetString(propNamePtr);

    while (propName[0] == '-') {
	propName++;
    }
    if (installGetter) {
	Tcl_Obj *methodName = Tcl_ObjPrintf("<ReadProp-%s>", propName);
	Tcl_IncrRefCount(propNamePtr); // Paired with DetailsDeleter
	TclNewMethod(targetClass, methodName, 0, &GetterType, propNamePtr);
	Tcl_BounceRefCount(methodName);
    }
    if (installSetter) {
	Tcl_Obj *methodName = Tcl_ObjPrintf("<WriteProp-%s>", propName);
	Tcl_IncrRefCount(propNamePtr); // Paired with DetailsDeleter
	TclNewMethod(targetClass, methodName, 0, &SetterType, propNamePtr);
	Tcl_BounceRefCount(methodName);
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * FindClassProps --
 *
 *	Discover the properties known to a class and its superclasses.
 *	The property names become the keys in the accumulator hash table
 *	(which is used as a set).
 *
 * ----------------------------------------------------------------------
 */

static void
FindClassProps(
    Class *clsPtr,		/* The object to inspect. Must exist. */
    int writable,		/* Whether we're after the readable or writable
				 * property set. */
    Tcl_HashTable *accumulator)	/* Where to gather the names. */
{
    int i, dummy;
    Tcl_Obj *propName;
    Class *mixin, *sup;

  tailRecurse:
    if (writable) {
	FOREACH(propName, clsPtr->properties.writable) {
	    Tcl_CreateHashEntry(accumulator, (void *) propName, &dummy);
	}
    } else {
	FOREACH(propName, clsPtr->properties.readable) {
	    Tcl_CreateHashEntry(accumulator, (void *) propName, &dummy);
	}
    }
    if (clsPtr->thisPtr->flags & ROOT_OBJECT) {
	/*
	 * We do *not* traverse upwards from the root!
	 */
	return;
    }
    FOREACH(mixin, clsPtr->mixins) {
	FindClassProps(mixin, writable, accumulator);
    }
    if (clsPtr->superclasses.num == 1) {
	clsPtr = clsPtr->superclasses.list[0];
	goto tailRecurse;
    }
    FOREACH(sup, clsPtr->superclasses) {
	FindClassProps(sup, writable, accumulator);
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * FindObjectProps --
 *
 *	Discover the properties known to an object and all its classes.
 *	The property names become the keys in the accumulator hash table
 *	(which is used as a set).
 *
 * ----------------------------------------------------------------------
 */

static void
FindObjectProps(
    Object *oPtr,		/* The object to inspect. Must exist. */
    int writable,		/* Whether we're after the readable or writable
				 * property set. */
    Tcl_HashTable *accumulator)	/* Where to gather the names. */
{
    int i, dummy;
    Tcl_Obj *propName;
    Class *mixin;

    if (writable) {
	FOREACH(propName, oPtr->properties.writable) {
	    Tcl_CreateHashEntry(accumulator, (void *) propName, &dummy);
	}
    } else {
	FOREACH(propName, oPtr->properties.readable) {
	    Tcl_CreateHashEntry(accumulator, (void *) propName, &dummy);
	}
    }
    FOREACH(mixin, oPtr->mixins) {
	FindClassProps(mixin, writable, accumulator);
    }
    FindClassProps(oPtr->selfCls, writable, accumulator);
}

/*
 * ----------------------------------------------------------------------
 *
 * GetAllClassProperties --
 *
 *	Get the list of all properties known to a class, including to its
 *	superclasses. Manages a cache so this operation is usually cheap.
 *	The order of properties in the resulting list is undefined.
 *
 * ----------------------------------------------------------------------
 */

static Tcl_Obj *
GetAllClassProperties(
    Class *clsPtr,		/* The class to inspect. Must exist. */
    int writable,		/* Whether to get writable properties. If
				 * false, readable properties will be returned
				 * instead. */
    int *allocated)		/* Address of variable to set to true if a
				 * Tcl_Obj was allocated and may be safely
				 * modified by the caller. */
{
    Tcl_HashTable hashTable;
    FOREACH_HASH_DECLS;
    Tcl_Obj *propName, *result;

    /*
     * Look in the cache.
     */

    if (clsPtr->properties.epoch == clsPtr->thisPtr->fPtr->epoch) {
	if (writable) {
	    if (clsPtr->properties.allWritableCache) {
		*allocated = 0;
		return clsPtr->properties.allWritableCache;
	    }
	} else {
	    if (clsPtr->properties.allReadableCache) {
		*allocated = 0;
		return clsPtr->properties.allReadableCache;
	    }
	}
    }

    /*
     * Gather the information. Unsorted! (Caller will sort.)
     */

    *allocated = 1;
    Tcl_InitObjHashTable(&hashTable);
    FindClassProps(clsPtr, writable, &hashTable);
    TclNewObj(result);
    FOREACH_HASH_KEY(propName, &hashTable) {
	Tcl_ListObjAppendElement(NULL, result, propName);
    }
    Tcl_DeleteHashTable(&hashTable);

    /*
     * Cache the information. Also purges the cache.
     */

    if (clsPtr->properties.epoch != clsPtr->thisPtr->fPtr->epoch) {
	if (clsPtr->properties.allWritableCache) {
	    Tcl_DecrRefCount(clsPtr->properties.allWritableCache);
	    clsPtr->properties.allWritableCache = NULL;
	}
	if (clsPtr->properties.allReadableCache) {
	    Tcl_DecrRefCount(clsPtr->properties.allReadableCache);
	    clsPtr->properties.allReadableCache = NULL;
	}
    }
    clsPtr->properties.epoch = clsPtr->thisPtr->fPtr->epoch;
    if (writable) {
	clsPtr->properties.allWritableCache = result;
    } else {
	clsPtr->properties.allReadableCache = result;
    }
    Tcl_IncrRefCount(result);
    return result;
}

/*
 * ----------------------------------------------------------------------
 *
 * SortPropList --
 *	Sort a list of names of properties. Simple support function. Assumes
 *	that the list Tcl_Obj is unshared and doesn't have a string
 *	representation.
 *
 * ----------------------------------------------------------------------
 */

static int
PropNameCompare(
    const void *a,
    const void *b)
{
    Tcl_Obj *first = *(Tcl_Obj **) a;
    Tcl_Obj *second = *(Tcl_Obj **) b;

    return TclStringCmp(first, second, 0, 0, TCL_INDEX_NONE);
}

static inline void
SortPropList(
    Tcl_Obj *list)
{
    Tcl_Size ec;
    Tcl_Obj **ev;

    if (Tcl_IsShared(list)) {
	Tcl_Panic("shared property list cannot be sorted");
    }
    Tcl_ListObjGetElements(NULL, list, &ec, &ev);
    TclInvalidateStringRep(list);
    qsort(ev, ec, sizeof(Tcl_Obj *), PropNameCompare);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOGetAllObjectProperties --
 *
 *	Get the sorted list of all properties known to an object, including to
 *	its classes. Manages a cache so this operation is usually cheap.
 *
 * ----------------------------------------------------------------------
 */

Tcl_Obj *
TclOOGetAllObjectProperties(
    Object *oPtr,		/* The object to inspect. Must exist. */
    int writable)		/* Whether to get writable properties. If
				 * false, readable properties will be returned
				 * instead. */
{
    Tcl_HashTable hashTable;
    FOREACH_HASH_DECLS;
    Tcl_Obj *propName, *result;

    /*
     * Look in the cache.
     */

    if (oPtr->properties.epoch == oPtr->fPtr->epoch) {
	if (writable) {
	    if (oPtr->properties.allWritableCache) {
		return oPtr->properties.allWritableCache;
	    }
	} else {
	    if (oPtr->properties.allReadableCache) {
		return oPtr->properties.allReadableCache;
	    }
	}
    }

    /*
     * Gather the information. Unsorted! (Caller will sort.)
     */

    Tcl_InitObjHashTable(&hashTable);
    FindObjectProps(oPtr, writable, &hashTable);
    TclNewObj(result);
    FOREACH_HASH_KEY(propName, &hashTable) {
	Tcl_ListObjAppendElement(NULL, result, propName);
    }
    Tcl_DeleteHashTable(&hashTable);
    SortPropList(result);

    /*
     * Cache the information.
     */

    if (oPtr->properties.epoch != oPtr->fPtr->epoch) {
	if (oPtr->properties.allWritableCache) {
	    Tcl_DecrRefCount(oPtr->properties.allWritableCache);
	    oPtr->properties.allWritableCache = NULL;
	}
	if (oPtr->properties.allReadableCache) {
	    Tcl_DecrRefCount(oPtr->properties.allReadableCache);
	    oPtr->properties.allReadableCache = NULL;
	}
    }
    oPtr->properties.epoch = oPtr->fPtr->epoch;
    if (writable) {
	oPtr->properties.allWritableCache = result;
    } else {
	oPtr->properties.allReadableCache = result;
    }
    Tcl_IncrRefCount(result);
    return result;
}

/*
 * ----------------------------------------------------------------------
 *
 * SetPropertyList --
 *
 *	Helper for writing a property list (which is actually a set).
 *
 * ----------------------------------------------------------------------
 */
static inline void
SetPropertyList(
    PropertyList *propList,	/* The property list to write. Replaces the
				 * property list's contents. */
    Tcl_Size objc,		/* Number of property names. */
    Tcl_Obj *const objv[])	/* Property names. */
{
    Tcl_Size i, n;
    Tcl_Obj *propObj;
    int created;
    Tcl_HashTable uniqueTable;

    for (i=0 ; i<objc ; i++) {
	Tcl_IncrRefCount(objv[i]);
    }
    FOREACH(propObj, *propList) {
	Tcl_DecrRefCount(propObj);
    }
    if (i != objc) {
	if (objc == 0) {
	    Tcl_Free(propList->list);
	} else if (i) {
	    propList->list = (Tcl_Obj **)
		    Tcl_Realloc(propList->list, sizeof(Tcl_Obj *) * objc);
	} else {
	    propList->list = (Tcl_Obj **)
		    Tcl_Alloc(sizeof(Tcl_Obj *) * objc);
	}
    }
    propList->num = 0;
    if (objc > 0) {
	Tcl_InitObjHashTable(&uniqueTable);
	for (i=n=0 ; i<objc ; i++) {
	    Tcl_CreateHashEntry(&uniqueTable, objv[i], &created);
	    if (created) {
		propList->list[n++] = objv[i];
	    } else {
		Tcl_DecrRefCount(objv[i]);
	    }
	}
	propList->num = n;

	/*
	 * Shouldn't be necessary, but maintain num/list invariant.
	 */

	if (n != objc) {
	    propList->list = (Tcl_Obj **)
		    Tcl_Realloc(propList->list, sizeof(Tcl_Obj *) * n);
	}
	Tcl_DeleteHashTable(&uniqueTable);
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOInstallReadableProperties --
 *
 *	Helper for writing the readable property list (which is actually a set)
 *	that includes flushing the name cache.
 *
 * ----------------------------------------------------------------------
 */
void
TclOOInstallReadableProperties(
    PropertyStorage *props,	/* Which property list to install into. */
    Tcl_Size objc,		/* Number of property names. */
    Tcl_Obj *const objv[])	/* Property names. */
{
    if (props->allReadableCache) {
	Tcl_DecrRefCount(props->allReadableCache);
	props->allReadableCache = NULL;
    }

    SetPropertyList(&props->readable, objc, objv);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOInstallWritableProperties --
 *
 *	Helper for writing the writable property list (which is actually a set)
 *	that includes flushing the name cache.
 *
 * ----------------------------------------------------------------------
 */
void
TclOOInstallWritableProperties(
    PropertyStorage *props,	/* Which property list to install into. */
    Tcl_Size objc,		/* Number of property names. */
    Tcl_Obj *const objv[])	/* Property names. */
{
    if (props->allWritableCache) {
	Tcl_DecrRefCount(props->allWritableCache);
	props->allWritableCache = NULL;
    }

    SetPropertyList(&props->writable, objc, objv);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOGetPropertyList --
 *
 *	Helper for reading a property list.
 *
 * ----------------------------------------------------------------------
 */
Tcl_Obj *
TclOOGetPropertyList(
    PropertyList *propList)	/* The property list to read. */
{
    Tcl_Obj *resultObj, *propNameObj;
    Tcl_Size i;

    TclNewObj(resultObj);
    FOREACH(propNameObj, *propList) {
	Tcl_ListObjAppendElement(NULL, resultObj, propNameObj);
    }
    return resultObj;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOInstallStdPropertyImpls --
 *
 *	Validates a (dashless) property name, and installs implementation
 *	methods if asked to do so (readable and writable flags).
 *
 * ----------------------------------------------------------------------
 */
int
TclOOInstallStdPropertyImpls(
    void *useInstance,
    Tcl_Interp *interp,
    Tcl_Obj *propName,
    int readable,
    int writable)
{
    const char *name, *reason;
    Tcl_Size len;
    char flag = TCL_DONT_QUOTE_HASH;

    /*
     * Validate the property name. Note that just calling TclScanElement() is
     * cheaper than actually formatting a list and comparing the string
     * version of that with the original, as TclScanElement() is one of the
     * core parts of doing that; this skips a whole load of irrelevant memory
     * allocations!
     */

    name = Tcl_GetStringFromObj(propName, &len);
    if (Tcl_StringMatch(name, "-*")) {
	reason = "must not begin with -";
	goto badProp;
    }
    if (TclScanElement(name, len, &flag) != len) {
	reason = "must be a simple word";
	goto badProp;
    }
    if (Tcl_StringMatch(name, "*::*")) {
	reason = "must not contain namespace separators";
	goto badProp;
    }
    if (Tcl_StringMatch(name, "*[()]*")) {
	reason = "must not contain parentheses";
	goto badProp;
    }

    /*
     * Install the implementations... if asked to do so.
     */

    if (useInstance) {
	Tcl_Object object = TclOOGetDefineCmdContext(interp);
	if (!object) {
	    return TCL_ERROR;
	}
	ImplementObjectProperty(object, propName, readable, writable);
    } else {
	Tcl_Class cls = (Tcl_Class) TclOOGetClassDefineCmdContext(interp);
	if (!cls) {
	    return TCL_ERROR;
	}
	ImplementClassProperty(cls, propName, readable, writable);
    }
    return TCL_OK;

  badProp:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "bad property name \"%s\": %s", name, reason));
    OO_ERROR(interp, PROPERTY_FORMAT);
    return TCL_ERROR;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOODefinePropertyCmd --
 *
 *	Implementation of the "property" definition for classes and instances
 *	governed by the [oo::configurable] metaclass.
 *
 * ----------------------------------------------------------------------
 */

int
TclOODefinePropertyCmd(
    void *useInstance,		/* NULL for class, non-NULL for object. */
    Tcl_Interp *interp,		/* For error reporting and lookup. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const *objv)	/* Arguments. */
{
    int i;
    const char *const options[] = {
	"-get", "-kind", "-set", NULL
    };
    enum Options {
	OPT_GET, OPT_KIND, OPT_SET
    };
    const char *const kinds[] = {
	"readable", "readwrite", "writable", NULL
    };
    enum Kinds {
	KIND_RO, KIND_RW, KIND_WO
    };
    Object *oPtr = (Object *) TclOOGetDefineCmdContext(interp);

    if (oPtr == NULL) {
	return TCL_ERROR;
    }
    if (!useInstance && !oPtr->classPtr) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"attempt to misuse API", TCL_AUTO_LENGTH));
	OO_ERROR(interp, MONKEY_BUSINESS);
	return TCL_ERROR;
    }

    for (i = 1; i < objc; i++) {
	Tcl_Obj *propObj = objv[i], *nextObj, *argObj, *hyphenated;
	Tcl_Obj *getterScript = NULL, *setterScript = NULL;

	/*
	 * Parse the extra options for the property.
	 */

	int kind = KIND_RW;
	while (i + 1 < objc) {
	    int option;

	    nextObj = objv[i + 1];
	    if (TclGetString(nextObj)[0] != '-') {
		break;
	    }
	    if (Tcl_GetIndexFromObj(interp, nextObj, options, "option", 0,
		    &option) != TCL_OK) {
		return TCL_ERROR;
	    }
	    if (i + 2 >= objc) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"missing %s to go with %s option",
			(option == OPT_KIND ? "kind value" : "body"),
			options[option]));
		Tcl_SetErrorCode(interp, "TCL", "WRONGARGS", NULL);
		return TCL_ERROR;
	    }
	    argObj = objv[i + 2];
	    i += 2;
	    switch (option) {
	    case OPT_GET:
		getterScript = argObj;
		break;
	    case OPT_SET:
		setterScript = argObj;
		break;
	    case OPT_KIND:
		if (Tcl_GetIndexFromObj(interp, argObj, kinds, "kind", 0,
			&kind) != TCL_OK) {
		    return TCL_ERROR;
		}
		break;
	    default:
		TCL_UNREACHABLE();
	    }
	}

	/*
	 * Install the property. Note that TclOOInstallStdPropertyImpls
	 * validates the property name as well.
	 */

	if (TclOOInstallStdPropertyImpls(useInstance, interp, propObj,
		kind != KIND_WO && getterScript == NULL,
		kind != KIND_RO && setterScript == NULL) != TCL_OK) {
	    return TCL_ERROR;
	}

	hyphenated = Tcl_ObjPrintf("-%s", TclGetString(propObj));
	if (useInstance) {
	    TclOORegisterInstanceProperty(oPtr, hyphenated,
		    kind != KIND_WO, kind != KIND_RO);
	} else {
	    TclOORegisterProperty(oPtr->classPtr, hyphenated,
		    kind != KIND_WO, kind != KIND_RO);
	}
	Tcl_BounceRefCount(hyphenated);

	/*
	 * Create property implementation methods by using the right
	 * back-end API, but only if the user has given us the bodies of the
	 * methods we'll make.
	 */

	if (getterScript != NULL) {
	    Tcl_Obj *getterName = Tcl_ObjPrintf("<ReadProp-%s>",
		    TclGetString(propObj));
	    Tcl_Obj *argsPtr = Tcl_NewObj();
	    Method *mPtr;

	    Tcl_IncrRefCount(getterScript);
	    if (useInstance) {
		mPtr = TclOONewProcInstanceMethod(interp, oPtr, 0,
			getterName, argsPtr, getterScript, NULL);
	    } else {
		mPtr = TclOONewProcMethod(interp, oPtr->classPtr, 0,
			getterName, argsPtr, getterScript, NULL);
	    }
	    Tcl_BounceRefCount(getterName);
	    Tcl_BounceRefCount(argsPtr);
	    Tcl_DecrRefCount(getterScript);
	    if (mPtr == NULL) {
		return TCL_ERROR;
	    }
	}
	if (setterScript != NULL) {
	    Tcl_Obj *setterName = Tcl_ObjPrintf("<WriteProp-%s>",
		    TclGetString(propObj));
	    Tcl_Obj *argsPtr;
	    Method *mPtr;

	    TclNewLiteralStringObj(argsPtr, "value");
	    Tcl_IncrRefCount(setterScript);
	    if (useInstance) {
		mPtr = TclOONewProcInstanceMethod(interp, oPtr, 0,
			setterName, argsPtr, setterScript, NULL);
	    } else {
		mPtr = TclOONewProcMethod(interp, oPtr->classPtr, 0,
			setterName, argsPtr, setterScript, NULL);
	    }
	    Tcl_BounceRefCount(setterName);
	    Tcl_BounceRefCount(argsPtr);
	    Tcl_DecrRefCount(setterScript);
	    if (mPtr == NULL) {
		return TCL_ERROR;
	    }
	}
    }
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOInfoClassPropCmd, TclOOInfoObjectPropCmd --
 *
 *	Implements [info class properties $clsName ?$option...?] and
 *	[info object properties $objName ?$option...?]
 *
 * ----------------------------------------------------------------------
 */

int
TclOOInfoClassPropCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Class *clsPtr;
    int i, idx, all = 0, writable = 0, allocated = 0;
    Tcl_Obj *result;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "className ?options...?");
	return TCL_ERROR;
    }
    clsPtr = TclOOGetClassFromObj(interp, objv[1]);
    if (clsPtr == NULL) {
	return TCL_ERROR;
    }
    for (i = 2; i < objc; i++) {
	if (Tcl_GetIndexFromObj(interp, objv[i], propOptNames, "option", 0,
		&idx) != TCL_OK) {
	    return TCL_ERROR;
	}
	switch (idx) {
	case PROP_ALL:
	    all = 1;
	    break;
	case PROP_READABLE:
	    writable = 0;
	    break;
	case PROP_WRITABLE:
	    writable = 1;
	    break;
	default:
	    TCL_UNREACHABLE();
	}
    }

    /*
     * Get the properties.
     */

    if (all) {
	result = GetAllClassProperties(clsPtr, writable, &allocated);
	if (allocated) {
	    SortPropList(result);
	}
    } else {
	if (writable) {
	    result = TclOOGetPropertyList(&clsPtr->properties.writable);
	} else {
	    result = TclOOGetPropertyList(&clsPtr->properties.readable);
	}
	SortPropList(result);
    }
    Tcl_SetObjResult(interp, result);
    return TCL_OK;
}

int
TclOOInfoObjectPropCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const objv[])
{
    Object *oPtr;
    int i, idx, all = 0, writable = 0;
    Tcl_Obj *result;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "objName ?options...?");
	return TCL_ERROR;
    }
    oPtr = (Object *) Tcl_GetObjectFromObj(interp, objv[1]);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }
    for (i = 2; i < objc; i++) {
	if (Tcl_GetIndexFromObj(interp, objv[i], propOptNames, "option", 0,
		&idx) != TCL_OK) {
	    return TCL_ERROR;
	}
	switch (idx) {
	case PROP_ALL:
	    all = 1;
	    break;
	case PROP_READABLE:
	    writable = 0;
	    break;
	case PROP_WRITABLE:
	    writable = 1;
	    break;
	default:
	    TCL_UNREACHABLE();
	}
    }

    /*
     * Get the properties.
     */

    if (all) {
	result = TclOOGetAllObjectProperties(oPtr, writable);
    } else {
	if (writable) {
	    result = TclOOGetPropertyList(&oPtr->properties.writable);
	} else {
	    result = TclOOGetPropertyList(&oPtr->properties.readable);
	}
	SortPropList(result);
    }
    Tcl_SetObjResult(interp, result);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOReleasePropertyStorage --
 *
 *	Delete the memory associated with a class or object's properties.
 *
 * ----------------------------------------------------------------------
 */

static inline void
ReleasePropertyList(
    PropertyList *propList)
{
    Tcl_Obj *propertyObj;
    Tcl_Size i;

    FOREACH(propertyObj, *propList) {
	Tcl_DecrRefCount(propertyObj);
    }
    Tcl_Free(propList->list);
    propList->list = NULL;
    propList->num = 0;
}

void
TclOOReleasePropertyStorage(
    PropertyStorage *propsPtr)
{
    if (propsPtr->allReadableCache) {
	Tcl_DecrRefCount(propsPtr->allReadableCache);
    }
    if (propsPtr->allWritableCache) {
	Tcl_DecrRefCount(propsPtr->allWritableCache);
    }
    if (propsPtr->readable.num) {
	ReleasePropertyList(&propsPtr->readable);
    }
    if (propsPtr->writable.num) {
	ReleasePropertyList(&propsPtr->writable);
    }
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
