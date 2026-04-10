/*
 * tclOO.c --
 *
 *	This file contains the object-system core (NB: not Tcl_Obj, but ::oo)
 *
 * Copyright © 2005-2019 Donal K. Fellows
 * Copyright © 2017 Nathan Coulter
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif
#include "tclInt.h"
#include "tclOOInt.h"

/*
 * Commands in oo and oo::Helpers.
 */

static const struct StdCommands {
    const char *name;
    Tcl_ObjCmdProc *objProc;
    Tcl_ObjCmdProc *nreProc;
    CompileProc *compileProc;
} ooCmds[] = {
    {"define",		TclOODefineObjCmd, NULL, NULL},
    {"objdefine",	TclOOObjDefObjCmd, NULL, NULL},
    {"copy",		TclOOCopyObjectCmd, NULL, NULL},
    {"DelegateName",	TclOODelegateNameObjCmd, NULL, NULL},
    {NULL, NULL, NULL, NULL}
}, helpCmds[] = {
    {"callback",	TclOOCallbackObjCmd, NULL, NULL},
    {"mymethod",	TclOOCallbackObjCmd, NULL, NULL},
    {"classvariable",	TclOOClassVariableObjCmd, NULL, NULL},
    {"link",		TclOOLinkObjCmd, NULL, NULL},
    {"next",		NULL, TclOONextObjCmd, TclCompileObjectNextCmd},
    {"nextto",		NULL, TclOONextToObjCmd, TclCompileObjectNextToCmd},
    {"self",		TclOOSelfObjCmd, NULL, TclCompileObjectSelfCmd},
    {NULL, NULL, NULL, NULL}
};

/*
 * Commands in oo::define and oo::objdefine.
 */

static const struct DefineCommands {
    const char *name;
    Tcl_ObjCmdProc *objProc;
    int flag;
} defineCmds[] = {
    {"classmethod",	TclOODefineClassMethodObjCmd, 0},
    {"constructor",	TclOODefineConstructorObjCmd, 0},
    {"definitionnamespace", TclOODefineDefnNsObjCmd, 0},
    {"deletemethod",	TclOODefineDeleteMethodObjCmd, 0},
    {"destructor",	TclOODefineDestructorObjCmd, 0},
    {"export",		TclOODefineExportObjCmd, 0},
    {"forward",		TclOODefineForwardObjCmd, 0},
    {"initialise",	TclOODefineInitialiseObjCmd, 0},
    {"initialize",	TclOODefineInitialiseObjCmd, 0},
    {"method",		TclOODefineMethodObjCmd, 0},
    {"private",		TclOODefinePrivateObjCmd, 0},
    {"renamemethod",	TclOODefineRenameMethodObjCmd, 0},
    {"self",		TclOODefineSelfObjCmd, 0},
    {"unexport",	TclOODefineUnexportObjCmd, 0},
    {NULL, NULL, 0}
}, objdefCmds[] = {
    {"class",		TclOODefineClassObjCmd, 1},
    {"deletemethod",	TclOODefineDeleteMethodObjCmd, 1},
    {"export",		TclOODefineExportObjCmd, 1},
    {"forward",		TclOODefineForwardObjCmd, 1},
    {"method",		TclOODefineMethodObjCmd, 1},
    {"private",		TclOODefinePrivateObjCmd, 1},
    {"renamemethod",	TclOODefineRenameMethodObjCmd, 1},
    {"self",		TclOODefineObjSelfObjCmd, 0},
    {"unexport",	TclOODefineUnexportObjCmd, 1},
    {NULL, NULL, 0}
};

/*
 * What sort of size of things we like to allocate.
 */

#define ALLOC_CHUNK 8

/*
 * Function declarations for things defined in this file.
 */

static Object *		AllocObject(Tcl_Interp *interp, const char *nameStr,
			    Namespace *nsPtr, const char *nsNameStr);
static int		CloneClassMethod(Tcl_Interp *interp, Class *clsPtr,
			    Method *mPtr, Tcl_Obj *namePtr,
			    Method **newMPtrPtr);
static int		CloneObjectMethod(Tcl_Interp *interp, Object *oPtr,
			    Method *mPtr, Tcl_Obj *namePtr);
static Tcl_NamespaceDeleteProc	DeletedHelpersNamespace;
static Tcl_NRPostProc	FinalizeAlloc;
static Tcl_NRPostProc	FinalizeNext;
static Tcl_NRPostProc	FinalizeObjectCall;
static inline void	InitClassPath(Tcl_Interp * interp, Class *clsPtr);
static void		InitClassSystemRoots(Tcl_Interp *interp,
			    Foundation *fPtr);
static int		InitFoundation(Tcl_Interp *interp);
static Tcl_InterpDeleteProc	KillFoundation;
static void		MakeAdditionalClasses(Foundation *fPtr,
			    Tcl_Namespace *defineNs,
			    Tcl_Namespace *objDefineNs);
static Tcl_CmdDeleteProc	MyDeleted;
static Tcl_NamespaceDeleteProc	ObjectNamespaceDeleted;
static Tcl_CommandTraceProc	ObjectRenamedTrace;
static inline void	RemoveClass(Class **list, size_t num, size_t idx);
static inline void	RemoveObject(Object **list, size_t num, size_t idx);
static inline void	SquelchCachedName(Object *oPtr);

static Tcl_ObjCmdProc	PublicNRObjectCmd;
static Tcl_ObjCmdProc	PrivateNRObjectCmd;
static Tcl_ObjCmdProc	MyClassNRObjCmd;
static Tcl_CmdDeleteProc	MyClassDeleted;

/*
 * Methods in the oo::object and oo::class classes. First, we define a helper
 * macro that makes building the method type declaration structure a lot
 * easier. No point in making life harder than it has to be!
 *
 * Note that the core methods don't need clone or free proc callbacks.
 */

#define DCM(name,visibility,proc) \
    {name,visibility,\
	{TCL_OO_METHOD_VERSION_CURRENT,"core method: "#name,proc,NULL,NULL}}

static const DeclaredClassMethod objMethods[] = {
    DCM("<cloned>", 0,	TclOO_Object_Cloned),
    DCM("destroy", 1,	TclOO_Object_Destroy),
    DCM("eval", 0,	TclOO_Object_Eval),
    DCM("unknown", 0,	TclOO_Object_Unknown),
    DCM("variable", 0,	TclOO_Object_LinkVar),
    DCM("varname", 0,	TclOO_Object_VarName),
    {NULL, 0, {0, NULL, NULL, NULL, NULL}}
}, clsMethods[] = {
    DCM("<cloned>", 0,	TclOO_Class_Cloned),
    DCM("create", 1,	TclOO_Class_Create),
    DCM("new", 1,	TclOO_Class_New),
    DCM("createWithNamespace", 0, TclOO_Class_CreateNs),
    {NULL, 0, {0, NULL, NULL, NULL, NULL}}
}, cfgMethods[] = {
    DCM("configure", 1, TclOO_Configurable_Configure),
    {NULL, 0, {0, NULL, NULL, NULL, NULL}}
}, singletonMethods[] = {
    DCM("new", 1,	TclOO_Singleton_New),
    {NULL, 0, {0, NULL, NULL, NULL, NULL}}
}, singletonInstanceMethods[] = {
    DCM("<cloned>", 0,	TclOO_SingletonInstance_Cloned),
    DCM("destroy", 1,	TclOO_SingletonInstance_Destroy),
    {NULL, 0, {0, NULL, NULL, NULL, NULL}}
};

/*
 * And for the oo::class constructor...
 */

static const Tcl_MethodType classConstructor = {
    TCL_OO_METHOD_VERSION_CURRENT,
    "oo::class constructor",
    TclOO_Class_Constructor, NULL, NULL
};

/*
 * And the oo::configurable constructor...
 */

static const Tcl_MethodType configurableConstructor = {
    TCL_OO_METHOD_VERSION_CURRENT,
    "oo::configurable constructor",
    TclOO_Configurable_Constructor, NULL, NULL
};

/*
 * The scripted part of TclOO: (legacy) package registration. There's no C API
 * at all for doing this, not even internally to Tcl.
 */

static const char initScript[] =
#ifndef TCL_NO_DEPRECATED
"package ifneeded TclOO " TCLOO_PATCHLEVEL " {# Already present, OK?};"
#endif
"package ifneeded tcl::oo " TCLOO_PATCHLEVEL " {# Already present, OK?};";

/*
 * The actual definition of the variable holding the TclOO stub table.
 */

MODULE_SCOPE const TclOOStubs tclOOStubs;

/*
 * Convenience macro for getting the foundation from an interpreter.
 */

#define GetFoundation(interp) \
	((Foundation *)((Interp *)(interp))->objectFoundation)

/*
 * Macros to make inspecting into the guts of an object cleaner.
 *
 * The ocPtr parameter (only in these macros) is assumed to work fine with
 * either an oPtr or a classPtr. Note that the roots oo::object and oo::class
 * have _both_ their object and class flags tagged with ROOT_OBJECT and
 * ROOT_CLASS respectively.
 */

#define Destructing(oPtr)	((oPtr)->flags & OBJECT_DESTRUCTING)
#define IsRootObject(ocPtr)	((ocPtr)->flags & ROOT_OBJECT)
#define IsRootClass(ocPtr)	((ocPtr)->flags & ROOT_CLASS)
#define IsRoot(ocPtr)		((ocPtr)->flags & (ROOT_OBJECT|ROOT_CLASS))

/* Wrapper for removing an item from a "flexible" item list. */
#define RemoveItem(type, lst, i) \
    do {						\
	Remove ## type ((lst).list, (lst).num, i);	\
	(lst).num--;					\
    } while (0)

/*
 * ----------------------------------------------------------------------
 *
 * RemoveClass, RemoveObject --
 *
 *	Helpers for the RemoveItem macro for deleting a class or object from a
 *	list. Setting the "empty" location to NULL makes debugging a little
 *	easier.
 *
 * ----------------------------------------------------------------------
 */

static inline void
RemoveClass(
    Class **list,
    size_t num,
    size_t idx)
{
    for (; idx + 1 < num; idx++) {
	list[idx] = list[idx + 1];
    }
    list[idx] = NULL;
}

static inline void
RemoveObject(
    Object **list,
    size_t num,
    size_t idx)
{
    for (; idx + 1 < num; idx++) {
	list[idx] = list[idx + 1];
    }
    list[idx] = NULL;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOInit --
 *
 *	Called to initialise the OO system within an interpreter.
 *
 * Result:
 *	TCL_OK if the setup succeeded. Currently assumed to always work.
 *
 * Side effects:
 *	Creates namespaces, commands, several classes and a number of
 *	callbacks. Upon return, the OO system is ready for use.
 *
 * ----------------------------------------------------------------------
 */

int
TclOOInit(
    Tcl_Interp *interp)		/* The interpreter to install into. */
{
    /*
     * Build the core of the OO system.
     */

    if (InitFoundation(interp) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Run our initialization script and, if that works, declare the package
     * to be fully provided.
     */

    if (Tcl_EvalEx(interp, initScript, TCL_INDEX_NONE, 0) != TCL_OK) {
	return TCL_ERROR;
    }

#ifndef TCL_NO_DEPRECATED
    Tcl_PkgProvideEx(interp, "TclOO", TCLOO_PATCHLEVEL,
	    &tclOOStubs);
#endif
    return Tcl_PkgProvideEx(interp, "tcl::oo", TCLOO_PATCHLEVEL,
	    &tclOOStubs);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOGetFoundation --
 *
 *	Get a reference to the OO core class system.
 *
 * ----------------------------------------------------------------------
 */

Foundation *
TclOOGetFoundation(
    Tcl_Interp *interp)
{
    return GetFoundation(interp);
}

/*
 * ----------------------------------------------------------------------
 *
 * CreateCmdInNS --
 *
 *	Create a command in a namespace. Supports setting various
 *	implementation functions, but not a deletion callback or a clientData;
 *	it's suitable for use-cases in this file, no more.
 *
 * ----------------------------------------------------------------------
 */
static inline void
CreateCmdInNS(
    Tcl_Interp *interp,
    Tcl_Namespace *namespacePtr,
    const char *name,
    Tcl_ObjCmdProc *cmdProc,
    Tcl_ObjCmdProc *nreProc,
    CompileProc *compileProc)
{
    Command *cmdPtr;

    if (cmdProc == NULL && nreProc == NULL) {
	Tcl_Panic("must supply at least one implementation function");
    }
    cmdPtr = (Command *) TclCreateObjCommandInNs(interp, name,
	    namespacePtr, cmdProc, NULL, NULL);
    cmdPtr->nreProc = nreProc;
    cmdPtr->compileProc = compileProc;
}

/*
 * ----------------------------------------------------------------------
 *
 * CreateConstantInNSStr --
 *
 *	Wrapper around TclCreateConstantInNS to make using it with string
 *	constants easier.
 *
 * ----------------------------------------------------------------------
 */
static inline void
CreateConstantInNSStr(
    Tcl_Interp *interp,
    Tcl_Namespace *namespacePtr,/* The namespace to contain the constant. */
    const char *nameStr,	/* The unqualified name of the constant. */
    const char *valueStr)	/* The value to put in the constant. */
{
    Tcl_Obj *nameObj = Tcl_NewStringObj(nameStr, TCL_AUTO_LENGTH);
    Tcl_IncrRefCount(nameObj);
    Tcl_Obj *valueObj = Tcl_NewStringObj(valueStr, TCL_AUTO_LENGTH);
    Tcl_IncrRefCount(valueObj);
    TclCreateConstantInNS(interp, (Namespace *) namespacePtr, nameObj, valueObj);
    Tcl_DecrRefCount(nameObj);
    Tcl_DecrRefCount(valueObj);
}

/*
 * ----------------------------------------------------------------------
 *
 * InitFoundation --
 *
 *	Set up the core of the OO core class system. This is a structure
 *	holding references to the magical bits that need to be known about in
 *	other places, plus the oo::object and oo::class classes.
 *
 * ----------------------------------------------------------------------
 */

static int
InitFoundation(
    Tcl_Interp *interp)
{
    static Tcl_ThreadDataKey tsdKey;
    ThreadLocalData *tsdPtr = (ThreadLocalData *)
	    Tcl_GetThreadData(&tsdKey, sizeof(ThreadLocalData));
    Foundation *fPtr = (Foundation *) Tcl_Alloc(sizeof(Foundation));
    Tcl_Namespace *define, *objdef;
    Tcl_Obj *namePtr;
    size_t i;

    /*
     * Initialize the structure that holds the OO system core. This is
     * attached to the interpreter via an assocData entry; not very efficient,
     * but the best we can do without hacking the core more.
     */

    memset(fPtr, 0, sizeof(Foundation));
    ((Interp *) interp)->objectFoundation = fPtr;
    fPtr->interp = interp;
    fPtr->ooNs = Tcl_CreateNamespace(interp, "::oo", fPtr, NULL);
    Tcl_Export(interp, fPtr->ooNs, "[a-z]*", 1);
    define = Tcl_CreateNamespace(interp, "::oo::define", fPtr, NULL);
    objdef = Tcl_CreateNamespace(interp, "::oo::objdefine", fPtr, NULL);
    fPtr->helpersNs = Tcl_CreateNamespace(interp, "::oo::Helpers", fPtr,
	    DeletedHelpersNamespace);
    Tcl_CreateNamespace(interp, "::oo::configuresupport", NULL, NULL);
    fPtr->epoch = 1;
    fPtr->tsdPtr = tsdPtr;

    TclNewLiteralStringObj(fPtr->unknownMethodNameObj, "unknown");
    TclNewLiteralStringObj(fPtr->constructorName, "<constructor>");
    TclNewLiteralStringObj(fPtr->destructorName, "<destructor>");
    TclNewLiteralStringObj(fPtr->clonedName, "<cloned>");
    TclNewLiteralStringObj(fPtr->defineName, "::oo::define");
    TclNewLiteralStringObj(fPtr->myName, "my");
    TclNewLiteralStringObj(fPtr->slotGetName, "Get");
    TclNewLiteralStringObj(fPtr->slotSetName, "Set");
    TclNewLiteralStringObj(fPtr->slotResolveName, "Resolve");
    TclNewLiteralStringObj(fPtr->slotDefOpName, "--default-operation");
    Tcl_IncrRefCount(fPtr->unknownMethodNameObj);
    Tcl_IncrRefCount(fPtr->constructorName);
    Tcl_IncrRefCount(fPtr->destructorName);
    Tcl_IncrRefCount(fPtr->clonedName);
    Tcl_IncrRefCount(fPtr->defineName);
    Tcl_IncrRefCount(fPtr->myName);
    Tcl_IncrRefCount(fPtr->slotGetName);
    Tcl_IncrRefCount(fPtr->slotSetName);
    Tcl_IncrRefCount(fPtr->slotResolveName);
    Tcl_IncrRefCount(fPtr->slotDefOpName);

    TclCreateObjCommandInNs(interp, "UnknownDefinition", fPtr->ooNs,
	    TclOOUnknownDefinition, NULL, NULL);
    TclNewLiteralStringObj(namePtr, "::oo::UnknownDefinition");
    Tcl_SetNamespaceUnknownHandler(interp, define, namePtr);
    Tcl_SetNamespaceUnknownHandler(interp, objdef, namePtr);
    Tcl_BounceRefCount(namePtr);

    /*
     * Create the subcommands in the oo::define and oo::objdefine spaces.
     */

    for (i = 0 ; defineCmds[i].name ; i++) {
	TclCreateObjCommandInNs(interp, defineCmds[i].name, define,
		defineCmds[i].objProc, INT2PTR(defineCmds[i].flag), NULL);
    }
    for (i = 0 ; objdefCmds[i].name ; i++) {
	TclCreateObjCommandInNs(interp, objdefCmds[i].name, objdef,
		objdefCmds[i].objProc, INT2PTR(objdefCmds[i].flag), NULL);
    }

    Tcl_CallWhenDeleted(interp, KillFoundation, NULL);

    /*
     * Create the special objects at the core of the object system.
     */

    InitClassSystemRoots(interp, fPtr);

    /*
     * Basic method declarations for the core classes.
     */

    TclOODefineBasicMethods(fPtr->objectCls, objMethods);
    TclOODefineBasicMethods(fPtr->classCls, clsMethods);

    /*
     * Finish setting up the class of classes by marking the 'new' method as
     * private; classes, unlike general objects, must have explicit names. We
     * also need to create the constructor for classes.
     */

    TclNewLiteralStringObj(namePtr, "new");
    TclNewInstanceMethod(interp, (Tcl_Object) fPtr->classCls->thisPtr,
	    namePtr /* keeps ref */, 0 /* private */, NULL, NULL);
    Tcl_BounceRefCount(namePtr);
    fPtr->classCls->constructorPtr = (Method *) TclNewMethod(
	    (Tcl_Class) fPtr->classCls, NULL, 0, &classConstructor, NULL);

    /*
     * Create non-object commands and plug ourselves into the Tcl [info]
     * ensemble.
     */

    for (i = 0 ; helpCmds[i].name ; i++) {
	CreateCmdInNS(interp, fPtr->helpersNs, helpCmds[i].name,
		helpCmds[i].objProc, helpCmds[i].nreProc,
		helpCmds[i].compileProc);
    }
    for (i = 0 ; ooCmds[i].name ; i++) {
	CreateCmdInNS(interp, fPtr->ooNs, ooCmds[i].name,
		ooCmds[i].objProc, ooCmds[i].nreProc,
		ooCmds[i].compileProc);
    }

    TclOOInitInfo(interp);

    /*
     * Now make the class of slots.
     */

    if (TclOODefineSlots(fPtr) != TCL_OK) {
	return TCL_ERROR;
    }

    MakeAdditionalClasses(fPtr, define, objdef);

    CreateConstantInNSStr(interp, fPtr->ooNs, "version", TCLOO_VERSION);
    CreateConstantInNSStr(interp, fPtr->ooNs, "patchlevel", TCLOO_PATCHLEVEL);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * InitClassSystemRoots --
 *
 *	Creates the objects at the core of the object system. These need to be
 *	spliced manually.
 *
 * ----------------------------------------------------------------------
 */

static void
InitClassSystemRoots(
    Tcl_Interp *interp,
    Foundation *fPtr)
{
    Class fakeCls;
    Object fakeObject;
    Tcl_Obj *defNsName;

    /* Stand up a phony class for bootstrapping. */
    fPtr->objectCls = &fakeCls;
    /* referenced in TclOOAllocClass to increment the refCount. */
    fakeCls.thisPtr = &fakeObject;
    fakeObject.refCount = 0;	// Do not increment an uninitialized value.

    fPtr->objectCls = TclOOAllocClass(interp,
	    AllocObject(interp, "object", (Namespace *) fPtr->ooNs, NULL));
    // Corresponding TclOODecrRefCount in KillFoundation
    AddRef(fPtr->objectCls->thisPtr);

    /*
     * This is why it is unnecessary in this routine to replace the
     * incremented reference count of fPtr->objectCls that was swallowed by
     * fakeObject.
     */

    fPtr->objectCls->superclasses.num = 0;
    Tcl_Free(fPtr->objectCls->superclasses.list);
    fPtr->objectCls->superclasses.list = NULL;

    /*
     * Special initialization for the primordial objects.
     */

    fPtr->objectCls->thisPtr->flags |= ROOT_OBJECT;
    fPtr->objectCls->flags |= ROOT_OBJECT;
    TclNewLiteralStringObj(defNsName, "::oo::objdefine");
    fPtr->objectCls->objDefinitionNs = defNsName;
    Tcl_IncrRefCount(defNsName);

    fPtr->classCls = TclOOAllocClass(interp,
	    AllocObject(interp, "class", (Namespace *) fPtr->ooNs, NULL));
    // Corresponding TclOODecrRefCount in KillFoundation
    AddRef(fPtr->classCls->thisPtr);

    /*
     * Increment reference counts for each reference because these
     * relationships can be dynamically changed.
     *
     * Corresponding TclOODecrRefCount for all incremented refcounts is in
     * KillFoundation.
     */

    /*
     * Rewire bootstrapped objects.
     */

    fPtr->objectCls->thisPtr->selfCls = fPtr->classCls;
    AddRef(fPtr->classCls->thisPtr);
    TclOOAddToInstances(fPtr->objectCls->thisPtr, fPtr->classCls);

    fPtr->classCls->thisPtr->selfCls = fPtr->classCls;
    AddRef(fPtr->classCls->thisPtr);
    TclOOAddToInstances(fPtr->classCls->thisPtr, fPtr->classCls);

    fPtr->classCls->thisPtr->flags |= ROOT_CLASS;
    fPtr->classCls->flags |= ROOT_CLASS;
    TclNewLiteralStringObj(defNsName, "::oo::define");
    fPtr->classCls->clsDefinitionNs = defNsName;
    Tcl_IncrRefCount(defNsName);

    /* Standard initialization for new Objects */
    TclOOAddToSubclasses(fPtr->classCls, fPtr->objectCls);

    /*
     * THIS IS THE ONLY FUNCTION THAT DOES NON-STANDARD CLASS SPLICING.
     * Everything else is careful to prohibit looping.
     */
}

/*
 * ----------------------------------------------------------------------
 *
 * MarkAsMetaclass --
 *
 *	Make a simple class into a metaclass by making it into a subclass of
 *	oo::class. Assumes that the previous class it had can be ignored.
 *
 * ----------------------------------------------------------------------
 */
static inline void
MarkAsMetaclass(
    Foundation *fPtr,
    Class *classPtr)
{
    Class **supers = (Class **) Tcl_Alloc(sizeof(Class *));
    supers[0] = fPtr->classCls;
    AddRef(supers[0]->thisPtr);
    TclOOSetSuperclasses(classPtr, 1, supers);
}

/*
 * ----------------------------------------------------------------------
 *
 * MakeAdditionalClasses --
 *
 *	Make the extra classes in TclOO that aren't core to how it functions.
 *
 * ----------------------------------------------------------------------
 */
static void
MakeAdditionalClasses(
    Foundation *fPtr,
    Tcl_Namespace *defineNs,
    Tcl_Namespace *objDefineNs)
{
    Tcl_Interp *interp = fPtr->interp;
    Object *singletonObj;	/* A metaclass that is used to make classes
				 * that only permit one instance of them to
				 * exist. See singleton(n). */
    Object *singletonInst;	/* A mixin used to make an object so it won't
				 * be destroyed or cloned (or at least not
				 * easily). */
    Object *abstractCls;	/* A metaclass that is used to make classes
				 * that can't be directly instantiated. See
				 * abstract(n). */
    Object *cfgSupObj;		/* The class that contains the implementation
				 * of the actual 'configure' method (mixed into
				 * actually configurable classes). The
				 * 'configure' method is in tclOOBasic.c. */
    Object *configurableObj;	/* A metaclass that is used to make classes
				 * that can be configured in their creation
				 * phase (and later too). All the metaclass
				 * itself does is arrange for the class created
				 * to have a 'configure' method and for
				 * oo::define and oo::objdefine (on the class
				 * and its instances) to have a property
				 * definition for setting things up for
				 * 'configure'. */
    Class *singletonCls, *cfgSupCls, *configurableCls;
    Tcl_Namespace *cfgObjNs, *cfgClsNs;
    Tcl_Obj *nsName;

    /*
     * Make the oo::singleton class, the SingletonInstance class, and install
     * their standard defined methods.
     */

    singletonObj = (Object *) Tcl_NewObjectInstance(interp,
	    (Tcl_Class) fPtr->classCls, "::oo::singleton",
	    NULL, TCL_INDEX_NONE, NULL, 0);
    singletonCls = singletonObj->classPtr;
    TclOODefineBasicMethods(singletonCls, singletonMethods);
    /* Set the superclass to oo::class */
    MarkAsMetaclass(fPtr, singletonCls);
    /* Unexport methods */
    TclOOUnexportMethods(singletonCls, "create", "createWithNamespace", NULL);

    singletonInst = (Object *) Tcl_NewObjectInstance(interp,
	    (Tcl_Class) fPtr->classCls, "::oo::SingletonInstance",
	    NULL, TCL_INDEX_NONE, NULL, 0);
    TclOODefineBasicMethods(singletonInst->classPtr, singletonInstanceMethods);

    /*
     * Make the oo::abstract class.
     */

    abstractCls = (Object *) Tcl_NewObjectInstance(interp,
	    (Tcl_Class) fPtr->classCls, "::oo::abstract",
	    NULL, TCL_INDEX_NONE, NULL, 0);
    /* Set the superclass to oo::class */
    MarkAsMetaclass(fPtr, abstractCls->classPtr);
    /* Unexport methods */
    TclOOUnexportMethods(abstractCls->classPtr,
	    "create", "createWithNamespace", "new", NULL);

    /*
     * Make the configurable class and install its standard defined method.
     */

    cfgSupObj = (Object *) Tcl_NewObjectInstance(interp,
	    (Tcl_Class) fPtr->classCls, "::oo::configuresupport::configurable",
	    NULL, TCL_INDEX_NONE, NULL, 0);
    cfgSupCls = cfgSupObj->classPtr;
    TclOODefineBasicMethods(cfgSupCls, cfgMethods);

    /* Namespaces used as implementation vectors for oo::define and
     * oo::objdefine when the class/instance is configurable.
     * Note that these also contain commands implemented in C,
     * especially the [property] definition command. */

    cfgObjNs = Tcl_CreateNamespace(interp,
	    "::oo::configuresupport::configurableobject", NULL, NULL);
    TclCreateObjCommandInNs(interp, "property", cfgObjNs,
	    TclOODefinePropertyCmd, INT2PTR(1) /*useInstance*/, NULL);
    TclCreateObjCommandInNs(interp, "properties", cfgObjNs,
	    TclOODefinePropertyCmd, INT2PTR(1) /*useInstance*/, NULL);
    Tcl_Export(interp, cfgObjNs, "property", /*reset*/1);
    TclSetNsPath((Namespace *) cfgObjNs, 1, &objDefineNs);

    cfgClsNs = Tcl_CreateNamespace(interp,
	    "::oo::configuresupport::configurableclass", NULL, NULL);
    TclCreateObjCommandInNs(interp, "property", cfgClsNs,
	    TclOODefinePropertyCmd, INT2PTR(0) /*useInstance*/, NULL);
    TclCreateObjCommandInNs(interp, "properties", cfgClsNs,
	    TclOODefinePropertyCmd, INT2PTR(0) /*useInstance*/, NULL);
    Tcl_Export(interp, cfgClsNs, "property", /*reset*/1);
    TclSetNsPath((Namespace *) cfgClsNs, 1, &defineNs);

    /* The oo::configurable class itself, a metaclass to apply
     * oo::configuresupport::configurable correctly. */

    configurableObj = (Object *) Tcl_NewObjectInstance(interp,
	    (Tcl_Class) fPtr->classCls, "::oo::configurable",
	    NULL, TCL_INDEX_NONE, NULL, 0);
    configurableCls = configurableObj->classPtr;
    MarkAsMetaclass(fPtr, configurableCls);
    Tcl_ClassSetConstructor(interp, (Tcl_Class) configurableCls, TclNewMethod(
	    (Tcl_Class) configurableCls, NULL, 0, &configurableConstructor, NULL));

    /* Set the definition namespaces of oo::configurable and
     * oo::configuresupport::configurable. */

    nsName = TclNewNamespaceObj(cfgClsNs);
    Tcl_IncrRefCount(nsName);
    if (cfgSupCls->clsDefinitionNs != NULL) {
	Tcl_DecrRefCount(cfgSupCls->clsDefinitionNs);
    }
    cfgSupCls->clsDefinitionNs = nsName;
    Tcl_IncrRefCount(nsName);
    if (configurableCls->clsDefinitionNs != NULL) {
	Tcl_DecrRefCount(configurableCls->clsDefinitionNs);
    }
    configurableCls->clsDefinitionNs = nsName;

    nsName = TclNewNamespaceObj(cfgObjNs);
    Tcl_IncrRefCount(nsName);
    if (cfgSupCls->objDefinitionNs != NULL) {
	Tcl_DecrRefCount(cfgSupCls->objDefinitionNs);
    }
    cfgSupCls->objDefinitionNs = nsName;
}

/*
 * ----------------------------------------------------------------------
 *
 * DeletedHelpersNamespace --
 *
 *	Simple helper used to clear fields of the foundation when they no
 *	longer hold useful information.
 *
 * ----------------------------------------------------------------------
 */

static void
DeletedHelpersNamespace(
    void *clientData)
{
    Foundation *fPtr = (Foundation *) clientData;

    fPtr->helpersNs = NULL;
}

/*
 * ----------------------------------------------------------------------
 *
 * KillFoundation --
 *
 *	Delete those parts of the OO core that are not deleted automatically
 *	when the objects and classes themselves are destroyed.
 *
 * ----------------------------------------------------------------------
 */

static void
KillFoundation(
    TCL_UNUSED(void *),
    Tcl_Interp *interp)		/* The interpreter containing the OO system
				 * foundation. */
{
    Foundation *fPtr = GetFoundation(interp);

    TclDecrRefCount(fPtr->unknownMethodNameObj);
    TclDecrRefCount(fPtr->constructorName);
    TclDecrRefCount(fPtr->destructorName);
    TclDecrRefCount(fPtr->clonedName);
    TclDecrRefCount(fPtr->defineName);
    TclDecrRefCount(fPtr->myName);
    TclDecrRefCount(fPtr->slotGetName);
    TclDecrRefCount(fPtr->slotSetName);
    TclDecrRefCount(fPtr->slotResolveName);
    TclDecrRefCount(fPtr->slotDefOpName);
    TclOODecrRefCount(fPtr->objectCls->thisPtr);
    TclOODecrRefCount(fPtr->classCls->thisPtr);

    Tcl_Free(fPtr);

    /*
     * Don't leave the interpreter field pointing to freed data.
     */

    ((Interp *) interp)->objectFoundation = NULL;
}

/*
 * ----------------------------------------------------------------------
 *
 * AllocObject --
 *
 *	Allocate an object of basic type. Does not splice the object into its
 *	class's instance list.  The caller must set the classPtr on the object
 *	to either a class or NULL, call TclOOAddToInstances to add the object
 *	to the class's instance list, and if the object itself is a class, use
 *	call TclOOAddToSubclasses() to add it to the right class's list of
 *	subclasses.
 *
 * Returns:
 *	Pointer to the object structure created, or NULL if a specific
 *	namespace was asked for but couldn't be created.
 *
 * ----------------------------------------------------------------------
 */

static Object *
AllocObject(
    Tcl_Interp *interp,		/* Interpreter within which to create the
				 * object. */
    const char *nameStr,	/* The name of the object to create, or NULL
				 * if the OO system should pick the object
				 * name itself (equal to the namespace
				 * name). */
    Namespace *nsPtr,		/* The namespace to create the object in, or
				 * NULL if *nameStr is NULL */
    const char *nsNameStr)	/* The name of the namespace to create, or
				 * NULL if the OO system should pick a unique
				 * name itself. If this is non-NULL but names
				 * a namespace that already exists, the effect
				 * will be the same as if this was NULL. */
{
    Foundation *fPtr = GetFoundation(interp);
    Object *oPtr;
    Command *cmdPtr;
    CommandTrace *tracePtr;
    size_t creationEpoch;

    oPtr = (Object *) Tcl_Alloc(sizeof(Object));
    memset(oPtr, 0, sizeof(Object));

    /*
     * Every object has a namespace; make one. Note that this also normally
     * computes the creation epoch value for the object, a sequence number
     * that is unique to the object (and which allows us to manage method
     * caching without comparing pointers).
     *
     * When creating a namespace, we first check to see if the caller
     * specified the name for the namespace. If not, we generate namespace
     * names using the epoch until such time as a new namespace is actually
     * created.
     */

    if (nsNameStr != NULL) {
	oPtr->namespacePtr = Tcl_CreateNamespace(interp, nsNameStr, oPtr, NULL);
	if (oPtr->namespacePtr == NULL) {
	    /*
	     * Couldn't make the specific namespace. Report as an error.
	     * [Bug 154f0982f2]
	     */
	    Tcl_Free(oPtr);
	    return NULL;
	}
	creationEpoch = ++fPtr->tsdPtr->nsCount;
	goto configNamespace;
    }

    while (1) {
	char objName[10 + TCL_INTEGER_SPACE];

	snprintf(objName, sizeof(objName), "::oo::Obj%" TCL_Z_MODIFIER "u",
		++fPtr->tsdPtr->nsCount);
	oPtr->namespacePtr = Tcl_CreateNamespace(interp, objName, oPtr, NULL);
	if (oPtr->namespacePtr != NULL) {
	    creationEpoch = fPtr->tsdPtr->nsCount;
	    break;
	}

	/*
	 * Could not make that namespace, so we make another. But first we
	 * have to get rid of the error message from Tcl_CreateNamespace,
	 * since that's something that should not be exposed to the user.
	 */

	Tcl_ResetResult(interp);
    }

  configNamespace:
    ((Namespace *) oPtr->namespacePtr)->refCount++;

    /*
     * Make the namespace know about the helper commands. This grants access
     * to the [self] and [next] commands.
     */

    if (fPtr->helpersNs != NULL) {
	TclSetNsPath((Namespace *) oPtr->namespacePtr, 1, &fPtr->helpersNs);
    }
    TclOOSetupVariableResolver(oPtr->namespacePtr);

    /*
     * Suppress use of compiled versions of the commands in this object's
     * namespace and its children; causes wrong behaviour without expensive
     * recompilation. [Bug 2037727]
     */

    ((Namespace *) oPtr->namespacePtr)->flags |= NS_SUPPRESS_COMPILATION;

    /*
     * Set up a callback to get notification of the deletion of a namespace
     * when enough of the namespace still remains to execute commands and
     * access variables in it. [Bug 2950259]
     */

    ((Namespace *) oPtr->namespacePtr)->earlyDeleteProc = ObjectNamespaceDeleted;

    /*
     * Fill in the rest of the non-zero/NULL parts of the structure.
     */

    oPtr->fPtr = fPtr;
    oPtr->creationEpoch = creationEpoch;

    /*
     * An object starts life with a refCount of 2 to mark the two stages of
     * destruction it occur:  A call to ObjectRenamedTrace(), and a call to
     * ObjectNamespaceDeleted().
     */

    oPtr->refCount = 2;
    oPtr->flags = USE_CLASS_CACHE;

    /*
     * Finally, create the object commands and initialize the trace on the
     * public command (so that the object structures are deleted when the
     * command is deleted).
     */

    if (!nameStr) {
	nameStr = oPtr->namespacePtr->name;
	nsPtr = (Namespace *) oPtr->namespacePtr;
	if (nsPtr->parentPtr != NULL) {
	    nsPtr = nsPtr->parentPtr;
	}
    }
    oPtr->command = TclCreateObjCommandInNs(interp, nameStr,
	(Tcl_Namespace *) nsPtr, TclOOPublicObjectCmd, oPtr, NULL);

    /*
     * Add the NRE command and trace directly. While this breaks a number of
     * abstractions, it is faster and we're inside Tcl here so we're allowed.
     */

    cmdPtr = (Command *) oPtr->command;
    cmdPtr->nreProc = PublicNRObjectCmd;
    cmdPtr->tracePtr = tracePtr = (CommandTrace *)
	    Tcl_Alloc(sizeof(CommandTrace));
    tracePtr->traceProc = ObjectRenamedTrace;
    tracePtr->clientData = oPtr;
    tracePtr->flags = TCL_TRACE_RENAME|TCL_TRACE_DELETE;
    tracePtr->nextPtr = NULL;
    tracePtr->refCount = 1;

    oPtr->myCommand = TclNRCreateCommandInNs(interp, "my", oPtr->namespacePtr,
	    TclOOPrivateObjectCmd, PrivateNRObjectCmd, oPtr, MyDeleted);
    oPtr->myclassCommand = TclNRCreateCommandInNs(interp, "myclass",
	    oPtr->namespacePtr, TclOOMyClassObjCmd, MyClassNRObjCmd, oPtr,
	    MyClassDeleted);
    oPtr->linkedCmdsList = NULL;
    return oPtr;
}

/*
 * ----------------------------------------------------------------------
 *
 * SquelchCachedName --
 *
 *	Encapsulates how to throw away a cached object name. Called from
 *	object rename traces and at object destruction.
 *
 * ----------------------------------------------------------------------
 */

static inline void
SquelchCachedName(
    Object *oPtr)
{
    if (oPtr->cachedNameObj) {
	Tcl_DecrRefCount(oPtr->cachedNameObj);
	oPtr->cachedNameObj = NULL;
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * MyDeleted, MyClassDeleted --
 *
 *	These callbacks are triggered when the object's [my] or [myclass]
 *	commands are deleted by any mechanism. They just mark the object as
 *	not having a [my] command or [myclass] command, and so prevent cleanup
 *	of those commands when the object itself is deleted.
 *
 * ----------------------------------------------------------------------
 */

static void
MyDeleted(
    void *clientData)		/* Reference to the object whose [my] has been
				 * squelched. */
{
    Object *oPtr = (Object *) clientData;
    Tcl_Size linkc, i;
    Tcl_Obj **linkv, *link;

    if (oPtr->linkedCmdsList) {
	TclListObjGetElements(NULL, oPtr->linkedCmdsList, &linkc, &linkv);
	for (i=0 ; i<linkc ; i++) {
	    link = linkv[i];
	    (void) Tcl_DeleteCommand(oPtr->fPtr->interp, TclGetString(link));
	}
	Tcl_DecrRefCount(oPtr->linkedCmdsList);
	oPtr->linkedCmdsList = NULL;
    }
    oPtr->myCommand = NULL;
}

static void
MyClassDeleted(
    void *clientData)
{
    Object *oPtr = (Object *) clientData;
    oPtr->myclassCommand = NULL;
}

/*
 * ----------------------------------------------------------------------
 *
 * ObjectRenamedTrace --
 *
 *	This callback is triggered when the object is deleted by any
 *	mechanism. It runs the destructors and arranges for the actual cleanup
 *	of the object's namespace, which in turn triggers cleansing of the
 *	object data structures.
 *
 * ----------------------------------------------------------------------
 */

static void
ObjectRenamedTrace(
    void *clientData,		/* The object being deleted. */
    TCL_UNUSED(Tcl_Interp *),
    TCL_UNUSED(const char *) /*oldName*/,
    TCL_UNUSED(const char *) /*newName*/,
    int flags)			/* Why was the object deleted? */
{
    Object *oPtr = (Object *) clientData;

    /*
     * If this is a rename and not a delete of the object, we just flush the
     * cache of the object name.
     */

    if (flags & TCL_TRACE_RENAME) {
	SquelchCachedName(oPtr);
	return;
    }

    /*
     * The namespace is only deleted if it hasn't already been deleted. [Bug
     * 2950259].
     */

    if (!Destructing(oPtr)) {
	Tcl_DeleteNamespace(oPtr->namespacePtr);
    }
    oPtr->command = NULL;
    TclOODecrRefCount(oPtr);
    return;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOODeleteDescendants --
 *
 *	Delete all descendants of a particular class.
 *
 * ----------------------------------------------------------------------
 */

void
TclOODeleteDescendants(
    Tcl_Interp *interp,		/* The interpreter containing the class. */
    Object *oPtr)		/* The object representing the class. */
{
    Class *clsPtr = oPtr->classPtr, *subclassPtr, *mixinSubclassPtr;
    Object *instancePtr;

    /*
     * Squelch classes that this class has been mixed into.
     */

    if (clsPtr->mixinSubs.num > 0) {
	while (clsPtr->mixinSubs.num > 0) {
	    mixinSubclassPtr =
		    clsPtr->mixinSubs.list[clsPtr->mixinSubs.num - 1];

	    /*
	     * This condition also covers the case where mixinSubclassPtr ==
	     * clsPtr
	     */

	    if (!Destructing(mixinSubclassPtr->thisPtr)
		    && !(mixinSubclassPtr->thisPtr->flags & DONT_DELETE)) {
		Tcl_DeleteCommandFromToken(interp,
			mixinSubclassPtr->thisPtr->command);
	    }
	    TclOORemoveFromMixinSubs(mixinSubclassPtr, clsPtr);
	}
    }
    if (clsPtr->mixinSubs.size > 0) {
	Tcl_Free(clsPtr->mixinSubs.list);
	clsPtr->mixinSubs.size = 0;
    }

    /*
     * Squelch subclasses of this class.
     */

    if (clsPtr->subclasses.num > 0) {
	while (clsPtr->subclasses.num > 0) {
	    subclassPtr = clsPtr->subclasses.list[clsPtr->subclasses.num - 1];
	    if (!Destructing(subclassPtr->thisPtr) && !IsRoot(subclassPtr)
		    && !(subclassPtr->thisPtr->flags & DONT_DELETE)) {
		Tcl_DeleteCommandFromToken(interp,
			subclassPtr->thisPtr->command);
	    }
	    TclOORemoveFromSubclasses(subclassPtr, clsPtr);
	}
    }
    if (clsPtr->subclasses.size > 0) {
	Tcl_Free(clsPtr->subclasses.list);
	clsPtr->subclasses.list = NULL;
	clsPtr->subclasses.size = 0;
    }

    /*
     * Squelch instances of this class (includes objects we're mixed into).
     */

    if (clsPtr->instances.num > 0) {
	while (clsPtr->instances.num > 0) {
	    instancePtr = clsPtr->instances.list[clsPtr->instances.num - 1];

	    /*
	     * This condition also covers the case where instancePtr == oPtr
	     */

	    if (!Destructing(instancePtr) && !IsRoot(instancePtr) &&
		    !(instancePtr->flags & DONT_DELETE)) {
		Tcl_DeleteCommandFromToken(interp, instancePtr->command);
	    }
	    TclOORemoveFromInstances(instancePtr, clsPtr);
	}
    }
    if (clsPtr->instances.size > 0) {
	Tcl_Free(clsPtr->instances.list);
	clsPtr->instances.list = NULL;
	clsPtr->instances.size = 0;
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOReleaseClassContents --
 *
 *	Tear down the special class data structure, including deleting all
 *	dependent classes and objects.
 *
 * ----------------------------------------------------------------------
 */

void
TclOOReleaseClassContents(
    Tcl_Interp *interp,		/* The interpreter containing the class. */
    Object *oPtr)		/* The object representing the class. */
{
    FOREACH_HASH_DECLS;
    Tcl_Size i;
    Class *clsPtr = oPtr->classPtr, *tmpClsPtr;
    Method *mPtr;
    Foundation *fPtr = oPtr->fPtr;
    Tcl_Obj *variableObj;
    PrivateVariableMapping *privateVariable;

    /*
     * Sanity check!
     */

    if (!Destructing(oPtr)) {
	if (IsRootClass(oPtr)) {
	    Tcl_Panic("deleting class structure for non-deleted %s",
		    "::oo::class");
	} else if (IsRootObject(oPtr)) {
	    Tcl_Panic("deleting class structure for non-deleted %s",
		    "::oo::object");
	}
    }

    /*
     * Stop using the class for definition information.
     */

    if (clsPtr->clsDefinitionNs) {
	Tcl_DecrRefCount(clsPtr->clsDefinitionNs);
	clsPtr->clsDefinitionNs = NULL;
    }
    if (clsPtr->objDefinitionNs) {
	Tcl_DecrRefCount(clsPtr->objDefinitionNs);
	clsPtr->objDefinitionNs = NULL;
    }

    /*
     * Squelch method implementation chain caches.
     */

    if (clsPtr->constructorChainPtr) {
	TclOODeleteChain(clsPtr->constructorChainPtr);
	clsPtr->constructorChainPtr = NULL;
    }
    if (clsPtr->destructorChainPtr) {
	TclOODeleteChain(clsPtr->destructorChainPtr);
	clsPtr->destructorChainPtr = NULL;
    }
    if (clsPtr->classChainCache) {
	CallChain *callPtr;

	FOREACH_HASH_VALUE(callPtr, clsPtr->classChainCache) {
	    TclOODeleteChain(callPtr);
	}
	Tcl_DeleteHashTable(clsPtr->classChainCache);
	Tcl_Free(clsPtr->classChainCache);
	clsPtr->classChainCache = NULL;
    }

    /*
     * Squelch the property lists.
     */

    TclOOReleasePropertyStorage(&clsPtr->properties);

    /*
     * Squelch our filter list.
     */

    if (clsPtr->filters.num) {
	Tcl_Obj *filterObj;

	FOREACH(filterObj, clsPtr->filters) {
	    TclDecrRefCount(filterObj);
	}
	Tcl_Free(clsPtr->filters.list);
	clsPtr->filters.list = NULL;
	clsPtr->filters.num = 0;
    }

    /*
     * Squelch our metadata.
     */

    if (clsPtr->metadataPtr != NULL) {
	Tcl_ObjectMetadataType *metadataTypePtr;
	void *value;

	FOREACH_HASH(metadataTypePtr, value, clsPtr->metadataPtr) {
	    metadataTypePtr->deleteProc(value);
	}
	Tcl_DeleteHashTable(clsPtr->metadataPtr);
	Tcl_Free(clsPtr->metadataPtr);
	clsPtr->metadataPtr = NULL;
    }

    if (clsPtr->mixins.num) {
	FOREACH(tmpClsPtr, clsPtr->mixins) {
	    TclOORemoveFromMixinSubs(clsPtr, tmpClsPtr);
	    TclOODecrRefCount(tmpClsPtr->thisPtr);
	}
	Tcl_Free(clsPtr->mixins.list);
	clsPtr->mixins.list = NULL;
	clsPtr->mixins.num = 0;
    }

    if (clsPtr->superclasses.num > 0) {
	FOREACH(tmpClsPtr, clsPtr->superclasses) {
	    TclOORemoveFromSubclasses(clsPtr, tmpClsPtr);
	    TclOODecrRefCount(tmpClsPtr->thisPtr);
	}
	Tcl_Free(clsPtr->superclasses.list);
	clsPtr->superclasses.num = 0;
	clsPtr->superclasses.list = NULL;
    }

    FOREACH_HASH_VALUE(mPtr, &clsPtr->classMethods) {
	/* instance gets deleted, so if method remains, reset it there */
	if (mPtr->refCount > 1 && mPtr->declaringClassPtr == clsPtr) {
	    mPtr->declaringClassPtr = NULL;
	}
	TclOODelMethodRef(mPtr);
    }
    Tcl_DeleteHashTable(&clsPtr->classMethods);
    TclOODelMethodRef(clsPtr->constructorPtr);
    TclOODelMethodRef(clsPtr->destructorPtr);

    FOREACH(variableObj, clsPtr->variables) {
	TclDecrRefCount(variableObj);
    }
    if (i) {
	Tcl_Free(clsPtr->variables.list);
    }

    FOREACH_STRUCT(privateVariable, clsPtr->privateVariables) {
	TclDecrRefCount(privateVariable->variableObj);
	TclDecrRefCount(privateVariable->fullNameObj);
    }
    if (i) {
	Tcl_Free(clsPtr->privateVariables.list);
    }

    if (IsRootClass(oPtr) && !Destructing(fPtr->objectCls->thisPtr)) {
	Tcl_DeleteCommandFromToken(interp, fPtr->objectCls->thisPtr->command);
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * ObjectNamespaceDeleted --
 *
 *	Callback when the object's namespace is deleted. Used to clean up the
 *	data structures associated with the object. The complicated bit is
 *	that this can sometimes happen before the object's command is deleted
 *	(interpreter teardown is complex!)
 *
 * ----------------------------------------------------------------------
 */

static void
ObjectNamespaceDeleted(
    void *clientData)		/* Pointer to the class whose namespace is
				 * being deleted. */
{
    Object *oPtr = (Object *) clientData;
    Foundation *fPtr = oPtr->fPtr;
    FOREACH_HASH_DECLS;
    Class *mixinPtr;
    Method *mPtr;
    Tcl_Obj *filterObj, *variableObj;
    PrivateVariableMapping *privateVariable;
    Tcl_Interp *interp = fPtr->interp;
    Tcl_Size i;

    if (Destructing(oPtr)) {
	/*
	 * TODO:  Can ObjectNamespaceDeleted ever be called twice?  If not,
	 * this guard could be removed.
	 */

	return;
    }

    /*
     * One rule for the teardown routines is that if an object is in the
     * process of being deleted, nothing else may modify its bookkeeping
     * records.  This is the flag that
     */

    oPtr->flags |= OBJECT_DESTRUCTING;

    /*
     * Let the dominoes fall!
     */

    if (oPtr->classPtr) {
	TclOODeleteDescendants(interp, oPtr);
    }

    /*
     * We do not run destructors on the core class objects when the
     * interpreter is being deleted; their incestuous nature causes problems
     * in that case when the destructor is partially deleted before the uses
     * of it have gone. [Bug 2949397]
     */

    if (!Tcl_InterpDeleted(interp) && !(oPtr->flags & DESTRUCTOR_CALLED)) {
	CallContext *contextPtr =
		TclOOGetCallContext(oPtr, NULL, DESTRUCTOR, NULL, NULL, NULL);

	oPtr->flags |= DESTRUCTOR_CALLED;
	if (contextPtr != NULL) {
	    int result;
	    Tcl_InterpState state;

	    contextPtr->callPtr->flags |= DESTRUCTOR;
	    contextPtr->skip = 0;
	    state = Tcl_SaveInterpState(interp, TCL_OK);
	    result = Tcl_NRCallObjProc(interp, TclOOInvokeContext,
		    contextPtr, 0, NULL);
	    if (result != TCL_OK) {
		Tcl_BackgroundException(interp, result);
	    }
	    Tcl_RestoreInterpState(interp, state);
	    TclOODeleteContext(contextPtr);
	}
    }

    /*
     * Instruct everyone to no longer use any allocated fields of the object.
     * Also delete the command that refers to the object at this point (if it
     * still exists) because otherwise its pointer to the object points into
     * freed memory.
     */

    if (((Command *) oPtr->command)->flags & CMD_DYING) {
	/*
	 * Something has already started the command deletion process. We can
	 * go ahead and clean up the namespace,
	 */
    } else {
	/*
	 * The namespace must have been deleted directly.  Delete the command
	 * as well.
	 */

	Tcl_DeleteCommandFromToken(interp, oPtr->command);
    }

    if (oPtr->myclassCommand) {
	Tcl_DeleteCommandFromToken(interp, oPtr->myclassCommand);
    }
    if (oPtr->myCommand) {
	Tcl_DeleteCommandFromToken(interp, oPtr->myCommand);
    }

    /*
     * Splice the object out of its context. After this, we must *not* call
     * methods on the object.
     */

    // TODO: Should this be protected with a !IsRoot() condition?
    TclOORemoveFromInstances(oPtr, oPtr->selfCls);

    if (oPtr->mixins.num > 0) {
	FOREACH(mixinPtr, oPtr->mixins) {
	    TclOORemoveFromInstances(oPtr, mixinPtr);
	    TclOODecrRefCount(mixinPtr->thisPtr);
	}
	if (oPtr->mixins.list != NULL) {
	    Tcl_Free(oPtr->mixins.list);
	}
    }

    FOREACH(filterObj, oPtr->filters) {
	TclDecrRefCount(filterObj);
    }
    if (i) {
	Tcl_Free(oPtr->filters.list);
    }

    if (oPtr->methodsPtr) {
	FOREACH_HASH_VALUE(mPtr, oPtr->methodsPtr) {
	    /* instance gets deleted, so if method remains, reset it there */
	    if (mPtr->refCount > 1 && mPtr->declaringObjectPtr == oPtr) {
		mPtr->declaringObjectPtr = NULL;
	    }
	    TclOODelMethodRef(mPtr);
	}
	Tcl_DeleteHashTable(oPtr->methodsPtr);
	Tcl_Free(oPtr->methodsPtr);
    }

    FOREACH(variableObj, oPtr->variables) {
	TclDecrRefCount(variableObj);
    }
    if (i) {
	Tcl_Free(oPtr->variables.list);
    }

    FOREACH_STRUCT(privateVariable, oPtr->privateVariables) {
	TclDecrRefCount(privateVariable->variableObj);
	TclDecrRefCount(privateVariable->fullNameObj);
    }
    if (i) {
	Tcl_Free(oPtr->privateVariables.list);
    }

    if (oPtr->chainCache) {
	TclOODeleteChainCache(oPtr->chainCache);
    }

    SquelchCachedName(oPtr);

    if (oPtr->metadataPtr != NULL) {
	Tcl_ObjectMetadataType *metadataTypePtr;
	void *value;

	FOREACH_HASH(metadataTypePtr, value, oPtr->metadataPtr) {
	    metadataTypePtr->deleteProc(value);
	}
	Tcl_DeleteHashTable(oPtr->metadataPtr);
	Tcl_Free(oPtr->metadataPtr);
	oPtr->metadataPtr = NULL;
    }

    /*
     * Squelch the property lists.
     */

    TclOOReleasePropertyStorage(&oPtr->properties);

    /*
     * Because an object can be a class that is an instance of itself, the
     * class object's class structure should only be cleaned after most of
     * the cleanup on the object is done.
     *
     * The class of objects needs some special care; if it is deleted (and
     * we're not killing the whole interpreter) we force the delete of the
     * class of classes now as well. Due to the incestuous nature of those two
     * classes, if one goes the other must too and yet the tangle can
     * sometimes not go away automatically; we force it here. [Bug 2962664]
     */

    if (IsRootObject(oPtr) && !Destructing(fPtr->classCls->thisPtr)
	    && !Tcl_InterpDeleted(interp)) {
	Tcl_DeleteCommandFromToken(interp, fPtr->classCls->thisPtr->command);
    }

    if (oPtr->classPtr != NULL) {
	TclOOReleaseClassContents(interp, oPtr);
    }

    /*
     * Delete the object structure itself.
     */

    TclNsDecrRefCount((Namespace *) oPtr->namespacePtr);
    oPtr->namespacePtr = NULL;
    TclOODecrRefCount(oPtr->selfCls->thisPtr);
    oPtr->selfCls = NULL;
    TclOODecrRefCount(oPtr);
    return;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOODecrRefCount --
 *
 *	Decrement the refcount of an object and deallocate storage then object
 *	is no longer referenced.  Returns 1 if storage was deallocated, and 0
 *	otherwise.
 *
 * ----------------------------------------------------------------------
 */

int
TclOODecrRefCount(
    Object *oPtr)
{
    if (oPtr->refCount-- <= 1) {

	if (oPtr->classPtr != NULL) {
	    Tcl_Free(oPtr->classPtr);
	}
	Tcl_Free(oPtr);
	return 1;
    }
    return 0;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOObjectDestroyed --
 *
 *	Returns TCL_OK if an object is entirely deleted, i.e. the destruction
 *	sequence has completed.
 *
 * ----------------------------------------------------------------------
 */
int
TclOOObjectDestroyed(
    Object *oPtr)
{
    return (oPtr->namespacePtr == NULL);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOORemoveFromInstances --
 *
 *	Utility function to remove an object from the list of instances within
 *	a class.
 *
 * ----------------------------------------------------------------------
 */

int
TclOORemoveFromInstances(
    Object *oPtr,		/* The instance to remove. */
    Class *clsPtr)		/* The class (possibly) containing the
				 * reference to the instance. */
{
    Tcl_Size i;
    int res = 0;
    Object *instPtr;

    FOREACH(instPtr, clsPtr->instances) {
	if (oPtr == instPtr) {
	    RemoveItem(Object, clsPtr->instances, i);
	    TclOODecrRefCount(oPtr);
	    res++;
	    break;
	}
    }
    return res;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOAddToInstances --
 *
 *	Utility function to add an object to the list of instances within a
 *	class.
 *
 * ----------------------------------------------------------------------
 */

void
TclOOAddToInstances(
    Object *oPtr,		/* The instance to add. */
    Class *clsPtr)		/* The class to add the instance to. It is
				 * assumed that the class is not already
				 * present as an instance in the class. */
{
    if (clsPtr->instances.num >= clsPtr->instances.size) {
	clsPtr->instances.size += ALLOC_CHUNK;
	if (clsPtr->instances.size == ALLOC_CHUNK) {
	    clsPtr->instances.list = (Object **)
		    Tcl_Alloc(sizeof(Object *) * ALLOC_CHUNK);
	} else {
	    clsPtr->instances.list = (Object **)
		    Tcl_Realloc(clsPtr->instances.list,
			    sizeof(Object *) * clsPtr->instances.size);
	}
    }
    clsPtr->instances.list[clsPtr->instances.num++] = oPtr;
    AddRef(oPtr);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOORemoveFromMixins --
 *
 *	Utility function to remove a class from the list of mixins within an
 *	object.
 *
 * ----------------------------------------------------------------------
 */

int
TclOORemoveFromMixins(
    Class *mixinPtr,		/* The mixin to remove. */
    Object *oPtr)		/* The object (possibly) containing the
				 * reference to the mixin. */
{
    Tcl_Size i;
    int res = 0;
    Class *mixPtr;

    FOREACH(mixPtr, oPtr->mixins) {
	if (mixinPtr == mixPtr) {
	    RemoveItem(Class, oPtr->mixins, i);
	    TclOODecrRefCount(mixPtr->thisPtr);
	    res++;
	    break;
	}
    }
    if (oPtr->mixins.num == 0) {
	Tcl_Free(oPtr->mixins.list);
	oPtr->mixins.list = NULL;
    }
    return res;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOORemoveFromSubclasses --
 *
 *	Utility function to remove a class from the list of subclasses within
 *	another class. Returns the number of removals performed.
 *
 * ----------------------------------------------------------------------
 */

int
TclOORemoveFromSubclasses(
    Class *subPtr,		/* The subclass to remove. */
    Class *superPtr)		/* The superclass to possibly remove the
				 * subclass reference from. */
{
    Tcl_Size i;
    int res = 0;
    Class *subclsPtr;

    FOREACH(subclsPtr, superPtr->subclasses) {
	if (subPtr == subclsPtr) {
	    RemoveItem(Class, superPtr->subclasses, i);
	    TclOODecrRefCount(subPtr->thisPtr);
	    res++;
	}
    }
    return res;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOAddToSubclasses --
 *
 *	Utility function to add a class to the list of subclasses within
 *	another class.
 *
 * ----------------------------------------------------------------------
 */

void
TclOOAddToSubclasses(
    Class *subPtr,		/* The subclass to add. */
    Class *superPtr)		/* The superclass to add the subclass to. It
				 * is assumed that the class is not already
				 * present as a subclass in the superclass. */
{
    if (Destructing(superPtr->thisPtr)) {
	return;
    }
    if (superPtr->subclasses.num >= superPtr->subclasses.size) {
	superPtr->subclasses.size += ALLOC_CHUNK;
	if (superPtr->subclasses.size == ALLOC_CHUNK) {
	    superPtr->subclasses.list = (Class **)
		    Tcl_Alloc(sizeof(Class *) * ALLOC_CHUNK);
	} else {
	    superPtr->subclasses.list = (Class **)
		    Tcl_Realloc(superPtr->subclasses.list,
			    sizeof(Class *) * superPtr->subclasses.size);
	}
    }
    superPtr->subclasses.list[superPtr->subclasses.num++] = subPtr;
    AddRef(subPtr->thisPtr);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOORemoveFromMixinSubs --
 *
 *	Utility function to remove a class from the list of mixinSubs within
 *	another class.
 *
 * ----------------------------------------------------------------------
 */

int
TclOORemoveFromMixinSubs(
    Class *subPtr,		/* The subclass to remove. */
    Class *superPtr)		/* The superclass to possibly remove the
				 * subclass reference from. */
{
    Tcl_Size i;
    int res = 0;
    Class *subclsPtr;

    FOREACH(subclsPtr, superPtr->mixinSubs) {
	if (subPtr == subclsPtr) {
	    RemoveItem(Class, superPtr->mixinSubs, i);
	    TclOODecrRefCount(subPtr->thisPtr);
	    res++;
	    break;
	}
    }
    return res;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOAddToMixinSubs --
 *
 *	Utility function to add a class to the list of mixinSubs within
 *	another class.
 *
 * ----------------------------------------------------------------------
 */

void
TclOOAddToMixinSubs(
    Class *subPtr,		/* The subclass to add. */
    Class *superPtr)		/* The superclass to add the subclass to. It
				 * is assumed that the class is not already
				 * present as a subclass in the superclass. */
{
    if (Destructing(superPtr->thisPtr)) {
	return;
    }
    if (superPtr->mixinSubs.num >= superPtr->mixinSubs.size) {
	superPtr->mixinSubs.size += ALLOC_CHUNK;
	if (superPtr->mixinSubs.size == ALLOC_CHUNK) {
	    superPtr->mixinSubs.list = (Class **)
		    Tcl_Alloc(sizeof(Class *) * ALLOC_CHUNK);
	} else {
	    superPtr->mixinSubs.list = (Class **)
		    Tcl_Realloc(superPtr->mixinSubs.list,
			    sizeof(Class *) * superPtr->mixinSubs.size);
	}
    }
    superPtr->mixinSubs.list[superPtr->mixinSubs.num++] = subPtr;
    AddRef(subPtr->thisPtr);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOAllocClass --
 *
 *	Allocate a basic class. Does not add class to its class's instance
 *	list.
 *
 * ----------------------------------------------------------------------
 */

static inline void
InitClassPath(
    Tcl_Interp *interp,
    Class *clsPtr)
{
    Foundation *fPtr = GetFoundation(interp);

    if (fPtr->helpersNs != NULL) {
	Tcl_Namespace *path[2];

	path[0] = fPtr->helpersNs;
	path[1] = fPtr->ooNs;
	TclSetNsPath((Namespace *) clsPtr->thisPtr->namespacePtr, 2, path);
    } else {
	TclSetNsPath((Namespace *) clsPtr->thisPtr->namespacePtr, 1,
		&fPtr->ooNs);
    }
}

Class *
TclOOAllocClass(
    Tcl_Interp *interp,		/* Interpreter within which to allocate the
				 * class. */
    Object *useThisObj)		/* Object that is to act as the class
				 * representation. */
{
    Foundation *fPtr = GetFoundation(interp);
    Class *clsPtr = (Class *) Tcl_Alloc(sizeof(Class));

    memset(clsPtr, 0, sizeof(Class));
    clsPtr->thisPtr = useThisObj;

    /*
     * Configure the namespace path for the class's object.
     */

    InitClassPath(interp, clsPtr);

    /*
     * Classes are subclasses of oo::object, i.e. the objects they create are
     * objects.
     */

    clsPtr->superclasses.num = 1;
    clsPtr->superclasses.list = (Class **) Tcl_Alloc(sizeof(Class *));
    clsPtr->superclasses.list[0] = fPtr->objectCls;
    AddRef(fPtr->objectCls->thisPtr);

    /*
     * Finish connecting the class structure to the object structure.
     */

    clsPtr->thisPtr->classPtr = clsPtr;

    /*
     * That's the complicated bit. Now fill in the rest of the non-zero/NULL
     * fields.
     */

    Tcl_InitObjHashTable(&clsPtr->classMethods);
    return clsPtr;
}

/*
 * ----------------------------------------------------------------------
 *
 * Tcl_NewObjectInstance --
 *
 *	Allocate a new instance of an object.
 *
 * ----------------------------------------------------------------------
 */
Tcl_Object
Tcl_NewObjectInstance(
    Tcl_Interp *interp,		/* Interpreter context. */
    Tcl_Class cls,		/* Class to create an instance of. */
    const char *nameStr,	/* Name of object to create, or NULL to ask
				 * the code to pick its own unique name. */
    const char *nsNameStr,	/* Name of namespace to create inside object,
				 * or NULL to ask the code to pick its own
				 * unique name. */
    Tcl_Size objc,		/* Number of arguments. Negative value means
				 * do not call constructor. */
    Tcl_Obj *const *objv,	/* Argument list. */
    Tcl_Size skip)		/* Number of arguments to _not_ pass to the
				 * constructor. */
{
    Class *classPtr = (Class *) cls;
    Object *oPtr;
    void *clientData[4];

    oPtr = TclNewObjectInstanceCommon(interp, classPtr, nameStr, nsNameStr);
    if (oPtr == NULL) {
	return NULL;
    }

    /*
     * Run constructors, except when objc < 0, which is a special flag case
     * used for object cloning only.
     */

    if (objc != TCL_INDEX_NONE) {
	CallContext *contextPtr =
		TclOOGetCallContext(oPtr, NULL, CONSTRUCTOR, NULL, NULL, NULL);

	if (contextPtr != NULL) {
	    int isRoot, result;
	    Tcl_InterpState state;

	    state = Tcl_SaveInterpState(interp, TCL_OK);
	    contextPtr->callPtr->flags |= CONSTRUCTOR;
	    contextPtr->skip = skip;

	    /*
	     * Adjust the ensemble tracking record if necessary. [Bug 3514761]
	     */

	    isRoot = TclInitRewriteEnsemble(interp, skip, skip, objv);
	    result = Tcl_NRCallObjProc(interp, TclOOInvokeContext, contextPtr,
		    objc, objv);

	    if (isRoot) {
		TclResetRewriteEnsemble(interp, 1);
	    }

	    clientData[0] = contextPtr;
	    clientData[1] = oPtr;
	    clientData[2] = state;
	    clientData[3] = &oPtr;

	    result = FinalizeAlloc(clientData, interp, result);
	    if (result != TCL_OK) {
		return NULL;
	    }
	}
    }

    return (Tcl_Object) oPtr;
}

int
TclNRNewObjectInstance(
    Tcl_Interp *interp,		/* Interpreter context. */
    Tcl_Class cls,		/* Class to create an instance of. */
    const char *nameStr,	/* Name of object to create, or NULL to ask
				 * the code to pick its own unique name. */
    const char *nsNameStr,	/* Name of namespace to create inside object,
				 * or NULL to ask the code to pick its own
				 * unique name. */
    Tcl_Size objc,		/* Number of arguments. Negative value means
				 * do not call constructor. */
    Tcl_Obj *const *objv,	/* Argument list. */
    Tcl_Size skip,		/* Number of arguments to _not_ pass to the
				 * constructor. */
    Tcl_Object *objectPtr)	/* Place to write the object reference upon
				 * successful allocation. */
{
    Class *classPtr = (Class *) cls;
    CallContext *contextPtr;
    Tcl_InterpState state;
    Object *oPtr;

    oPtr = TclNewObjectInstanceCommon(interp, classPtr, nameStr, nsNameStr);
    if (oPtr == NULL) {
	return TCL_ERROR;
    }

    /*
     * Run constructors, except when objc == TCL_INDEX_NONE (a special flag case used for
     * object cloning only). If there aren't any constructors, we do nothing.
     */

    if (objc < 0) {
	*objectPtr = (Tcl_Object) oPtr;
	return TCL_OK;
    }
    contextPtr = TclOOGetCallContext(oPtr, NULL, CONSTRUCTOR, NULL, NULL, NULL);
    if (contextPtr == NULL) {
	*objectPtr = (Tcl_Object) oPtr;
	return TCL_OK;
    }

    state = Tcl_SaveInterpState(interp, TCL_OK);
    contextPtr->callPtr->flags |= CONSTRUCTOR;
    contextPtr->skip = skip;

    /*
     * Adjust the ensemble tracking record if necessary. [Bug 3514761]
     */

    if (TclInitRewriteEnsemble(interp, skip, skip, objv)) {
	TclNRAddCallback(interp, TclClearRootEnsemble, NULL, NULL, NULL, NULL);
    }

    /*
     * Fire off the constructors non-recursively.
     */

    TclNRAddCallback(interp, FinalizeAlloc, contextPtr, oPtr, state,
	    objectPtr);
    TclPushTailcallPoint(interp);
    return TclOOInvokeContext(contextPtr, interp, objc, objv);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclNewObjectInstanceCommon --
 *
 *	Common code for handling object allocation. Does the basic object
 *	structure and class structure allocation.
 *
 * ----------------------------------------------------------------------
 */
Object *
TclNewObjectInstanceCommon(
    Tcl_Interp *interp,
    Class *classPtr,
    const char *nameStr,
    const char *nsNameStr)
{
    Tcl_HashEntry *hPtr;
    Foundation *fPtr = GetFoundation(interp);
    Object *oPtr;
    const char *simpleName = NULL;
    Namespace *nsPtr = NULL, *dummy;
    Namespace *inNsPtr = (Namespace *) TclGetCurrentNamespace(interp);

    if (nameStr) {
	TclGetNamespaceForQualName(interp, nameStr, inNsPtr,
		TCL_CREATE_NS_IF_UNKNOWN, &nsPtr, &dummy, &dummy, &simpleName);

	/*
	 * Disallow creation of an object over an existing command.
	 */

	hPtr = Tcl_FindHashEntry(&nsPtr->cmdTable, simpleName);
	if (hPtr) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "can't create object \"%s\": command already exists with"
		    " that name", nameStr));
	    OO_ERROR(interp, OVERWRITE_OBJECT);
	    return NULL;
	}
    }

    /*
     * Create the object.
     */

    oPtr = AllocObject(interp, simpleName, nsPtr, nsNameStr);
    if (oPtr == NULL) {
	return NULL;
    }
    oPtr->selfCls = classPtr;
    AddRef(classPtr->thisPtr);
    TclOOAddToInstances(oPtr, classPtr);

    /*
     * Check to see if we're really creating a class. If so, allocate the
     * class structure as well.
     */

    if (TclOOIsReachable(fPtr->classCls, classPtr)) {
	/*
	 * Is a class, so attach a class structure. Note that the
	 * TclOOAllocClass function splices the structure into the object, so
	 * we don't have to. Once that's done, we need to repatch the object
	 * to have the right class since TclOOAllocClass interferes with that.
	 */

	TclOOAllocClass(interp, oPtr);
	TclOOAddToSubclasses(oPtr->classPtr, fPtr->objectCls);
    } else {
	oPtr->classPtr = NULL;
    }
    return oPtr;
}

/*
 * ----------------------------------------------------------------------
 *
 * FinalizeAlloc --
 *
 *	Final stage of NR-aware object allocation, running after the
 *	constructor has been called to decide whether the construction
 *	succeeded or failed.
 *
 * ----------------------------------------------------------------------
 */
static int
FinalizeAlloc(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    CallContext *contextPtr = (CallContext *) data[0];
    Object *oPtr = (Object *) data[1];
    Tcl_InterpState state = (Tcl_InterpState) data[2];
    Tcl_Object *objectPtr = (Tcl_Object *) data[3];

    /*
     * Ensure an error if the object was deleted in the constructor. Don't
     * want to lose errors by accident. [Bug 2903011]
     */

    if (result != TCL_ERROR && Destructing(oPtr)) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"object deleted in constructor", TCL_AUTO_LENGTH));
	OO_ERROR(interp, STILLBORN);
	result = TCL_ERROR;
    }
    if (result != TCL_OK) {
	Tcl_DiscardInterpState(state);

	/*
	 * Take care to not delete a deleted object; that would be bad. [Bug
	 * 2903011] Also take care to make sure that we have the name of the
	 * command before we delete it. [Bug 9dd1bd7a74]
	 */

	if (!Destructing(oPtr)) {
	    (void) TclOOObjectName(interp, oPtr);
	    Tcl_DeleteCommandFromToken(interp, oPtr->command);
	}

	/*
	 * This decrements the refcount of oPtr.
	 */

	TclOODeleteContext(contextPtr);
	return TCL_ERROR;
    }
    Tcl_RestoreInterpState(interp, state);
    *objectPtr = (Tcl_Object) oPtr;

    /*
     * This decrements the refcount of oPtr.
     */

    TclOODeleteContext(contextPtr);
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * Tcl_CopyObjectInstance --
 *
 *	Creates a copy of an object. Does not copy the backing namespace,
 *	since the correct way to do that (e.g., shallow/deep) depends on the
 *	object/class's own policies.
 *
 * ----------------------------------------------------------------------
 */

Tcl_Object
Tcl_CopyObjectInstance(
    Tcl_Interp *interp,
    Tcl_Object sourceObject,
    const char *targetName,
    const char *targetNamespaceName)
{
    Object *oPtr = (Object *) sourceObject, *o2Ptr;
    FOREACH_HASH_DECLS;
    Method *mPtr;
    Class *mixinPtr;
    CallContext *contextPtr;
    Tcl_Obj *keyPtr, *filterObj, *variableObj, *args[3];
    PrivateVariableMapping *privateVariable;
    Tcl_Size i;
    int result;

    /*
     * Sanity check.
     */

    if (IsRootClass(oPtr)) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"may not clone the class of classes", TCL_AUTO_LENGTH));
	OO_ERROR(interp, CLONING_CLASS);
	return NULL;
    }

    /*
     * Build the instance. Note that this does not run any constructors.
     */

    o2Ptr = (Object *) Tcl_NewObjectInstance(interp,
	    (Tcl_Class) oPtr->selfCls, targetName, targetNamespaceName,
	    TCL_INDEX_NONE, NULL, 0);
    if (o2Ptr == NULL) {
	return NULL;
    }

    /*
     * Copy the object-local methods to the new object.
     */

    if (oPtr->methodsPtr) {
	FOREACH_HASH(keyPtr, mPtr, oPtr->methodsPtr) {
	    if (CloneObjectMethod(interp, o2Ptr, mPtr, keyPtr) != TCL_OK) {
		Tcl_DeleteCommandFromToken(interp, o2Ptr->command);
		return NULL;
	    }
	}
    }

    /*
     * Copy the object's mixin references to the new object.
     */

    if (o2Ptr->mixins.num != 0) {
	FOREACH(mixinPtr, o2Ptr->mixins) {
	    if (mixinPtr && mixinPtr != o2Ptr->selfCls) {
		TclOORemoveFromInstances(o2Ptr, mixinPtr);
	    }
	    TclOODecrRefCount(mixinPtr->thisPtr);
	}
	Tcl_Free(o2Ptr->mixins.list);
    }
    DUPLICATE(o2Ptr->mixins, oPtr->mixins, Class *);
    FOREACH(mixinPtr, o2Ptr->mixins) {
	if (mixinPtr && mixinPtr != o2Ptr->selfCls) {
	    TclOOAddToInstances(o2Ptr, mixinPtr);
	}

	/*
	 * For the reference just created in DUPLICATE.
	 */

	AddRef(mixinPtr->thisPtr);
    }

    /*
     * Copy the object's filter list to the new object.
     */

    DUPLICATE(o2Ptr->filters, oPtr->filters, Tcl_Obj *);
    FOREACH(filterObj, o2Ptr->filters) {
	Tcl_IncrRefCount(filterObj);
    }

    /*
     * Copy the object's variable resolution lists to the new object.
     */

    DUPLICATE(o2Ptr->variables, oPtr->variables, Tcl_Obj *);
    FOREACH(variableObj, o2Ptr->variables) {
	Tcl_IncrRefCount(variableObj);
    }

    DUPLICATE(o2Ptr->privateVariables, oPtr->privateVariables,
	    PrivateVariableMapping);
    FOREACH_STRUCT(privateVariable, o2Ptr->privateVariables) {
	Tcl_IncrRefCount(privateVariable->variableObj);
	Tcl_IncrRefCount(privateVariable->fullNameObj);
    }

    /*
     * Copy the object's flags to the new object, clearing those that must be
     * kept object-local. The duplicate is never deleted at this point, nor is
     * it the root of the object system or in the midst of processing a filter
     * call.
     */

    o2Ptr->flags = oPtr->flags & ~(
	    OBJECT_DESTRUCTING | ROOT_OBJECT | ROOT_CLASS | FILTER_HANDLING);

    /*
     * Copy the object's metadata.
     */

    if (oPtr->metadataPtr != NULL) {
	Tcl_ObjectMetadataType *metadataTypePtr;
	void *value, *duplicate;

	FOREACH_HASH(metadataTypePtr, value, oPtr->metadataPtr) {
	    if (metadataTypePtr->cloneProc == NULL) {
		duplicate = value;
	    } else {
		if (metadataTypePtr->cloneProc(interp, value,
			&duplicate) != TCL_OK) {
		    Tcl_DeleteCommandFromToken(interp, o2Ptr->command);
		    return NULL;
		}
	    }
	    if (duplicate != NULL) {
		Tcl_ObjectSetMetadata((Tcl_Object) o2Ptr, metadataTypePtr,
			duplicate);
	    }
	}
    }

    /*
     * Copy the class, if present. Note that if there is a class present in
     * the source object, there must also be one in the copy.
     */

    if (oPtr->classPtr != NULL) {
	Class *clsPtr = oPtr->classPtr;
	Class *cls2Ptr = o2Ptr->classPtr;
	Class *superPtr;

	/*
	 * Copy the class flags across.
	 */

	cls2Ptr->flags = clsPtr->flags;

	/*
	 * Ensure that the new class's superclass structure is the same as the
	 * old class's.
	 */

	FOREACH(superPtr, cls2Ptr->superclasses) {
	    TclOORemoveFromSubclasses(cls2Ptr, superPtr);
	    TclOODecrRefCount(superPtr->thisPtr);
	}
	if (cls2Ptr->superclasses.num) {
	    cls2Ptr->superclasses.list = (Class **)
		    Tcl_Realloc(cls2Ptr->superclasses.list,
			    sizeof(Class *) * clsPtr->superclasses.num);
	} else {
	    cls2Ptr->superclasses.list = (Class **)
		    Tcl_Alloc(sizeof(Class *) * clsPtr->superclasses.num);
	}
	memcpy(cls2Ptr->superclasses.list, clsPtr->superclasses.list,
		sizeof(Class *) * clsPtr->superclasses.num);
	cls2Ptr->superclasses.num = clsPtr->superclasses.num;
	FOREACH(superPtr, cls2Ptr->superclasses) {
	    TclOOAddToSubclasses(cls2Ptr, superPtr);

	    /*
	     * For the new item in cls2Ptr->superclasses that memcpy just
	     * created.
	     */

	    AddRef(superPtr->thisPtr);
	}

	/*
	 * Duplicate the source class's filters.
	 */

	DUPLICATE(cls2Ptr->filters, clsPtr->filters, Tcl_Obj *);
	FOREACH(filterObj, cls2Ptr->filters) {
	    Tcl_IncrRefCount(filterObj);
	}

	/*
	 * Copy the source class's variable resolution lists.
	 */

	DUPLICATE(cls2Ptr->variables, clsPtr->variables, Tcl_Obj *);
	FOREACH(variableObj, cls2Ptr->variables) {
	    Tcl_IncrRefCount(variableObj);
	}

	DUPLICATE(cls2Ptr->privateVariables, clsPtr->privateVariables,
		PrivateVariableMapping);
	FOREACH_STRUCT(privateVariable, cls2Ptr->privateVariables) {
	    Tcl_IncrRefCount(privateVariable->variableObj);
	    Tcl_IncrRefCount(privateVariable->fullNameObj);
	}

	/*
	 * Duplicate the source class's mixins (which cannot be circular
	 * references to the duplicate).
	 */

	if (cls2Ptr->mixins.num != 0) {
	    FOREACH(mixinPtr, cls2Ptr->mixins) {
		TclOORemoveFromMixinSubs(cls2Ptr, mixinPtr);
		TclOODecrRefCount(mixinPtr->thisPtr);
	    }
	    Tcl_Free(clsPtr->mixins.list);
	}
	DUPLICATE(cls2Ptr->mixins, clsPtr->mixins, Class *);
	FOREACH(mixinPtr, cls2Ptr->mixins) {
	    TclOOAddToMixinSubs(cls2Ptr, mixinPtr);

	    /*
	     * For the copy just created in DUPLICATE.
	     */

	    AddRef(mixinPtr->thisPtr);
	}

	/*
	 * Duplicate the source class's methods, constructor and destructor.
	 */

	FOREACH_HASH(keyPtr, mPtr, &clsPtr->classMethods) {
	    if (CloneClassMethod(interp, cls2Ptr, mPtr, keyPtr,
		    NULL) != TCL_OK) {
		Tcl_DeleteCommandFromToken(interp, o2Ptr->command);
		return NULL;
	    }
	}
	if (clsPtr->constructorPtr) {
	    if (CloneClassMethod(interp, cls2Ptr, clsPtr->constructorPtr,
		    NULL, &cls2Ptr->constructorPtr) != TCL_OK) {
		Tcl_DeleteCommandFromToken(interp, o2Ptr->command);
		return NULL;
	    }
	}
	if (clsPtr->destructorPtr) {
	    if (CloneClassMethod(interp, cls2Ptr, clsPtr->destructorPtr, NULL,
		    &cls2Ptr->destructorPtr) != TCL_OK) {
		Tcl_DeleteCommandFromToken(interp, o2Ptr->command);
		return NULL;
	    }
	}

	/*
	 * Duplicate the class's metadata.
	 */

	if (clsPtr->metadataPtr != NULL) {
	    Tcl_ObjectMetadataType *metadataTypePtr;
	    void *value, *duplicate;

	    FOREACH_HASH(metadataTypePtr, value, clsPtr->metadataPtr) {
		if (metadataTypePtr->cloneProc == NULL) {
		    duplicate = value;
		} else {
		    if (metadataTypePtr->cloneProc(interp, value,
			    &duplicate) != TCL_OK) {
			Tcl_DeleteCommandFromToken(interp, o2Ptr->command);
			return NULL;
		    }
		}
		if (duplicate != NULL) {
		    Tcl_ClassSetMetadata((Tcl_Class) cls2Ptr, metadataTypePtr,
			    duplicate);
		}
	    }
	}
    }

    TclResetRewriteEnsemble(interp, 1);
    contextPtr = TclOOGetCallContext(o2Ptr, oPtr->fPtr->clonedName, 0, NULL,
	    NULL, NULL);
    if (contextPtr) {
	args[0] = TclOOObjectName(interp, o2Ptr);
	args[1] = oPtr->fPtr->clonedName;
	args[2] = TclOOObjectName(interp, oPtr);
	Tcl_IncrRefCount(args[0]);
	Tcl_IncrRefCount(args[1]);
	Tcl_IncrRefCount(args[2]);
	result = Tcl_NRCallObjProc(interp, TclOOInvokeContext, contextPtr, 3,
		args);
	TclDecrRefCount(args[0]);
	TclDecrRefCount(args[1]);
	TclDecrRefCount(args[2]);
	TclOODeleteContext(contextPtr);
	if (result == TCL_ERROR) {
	    Tcl_AddErrorInfo(interp,
		    "\n    (while performing post-copy callback)");
	}
	if (result != TCL_OK) {
	    Tcl_DeleteCommandFromToken(interp, o2Ptr->command);
	    return NULL;
	}
    }

    return (Tcl_Object) o2Ptr;
}

/*
 * ----------------------------------------------------------------------
 *
 * CloneObjectMethod, CloneClassMethod --
 *
 *	Helper functions used for cloning methods. They work identically to
 *	each other, except for the difference between them in how they
 *	register the cloned method on a successful clone.
 *
 * ----------------------------------------------------------------------
 */

static int
CloneObjectMethod(
    Tcl_Interp *interp,
    Object *oPtr,
    Method *mPtr,
    Tcl_Obj *namePtr)
{
    if (mPtr->typePtr == NULL) {
	TclNewInstanceMethod(interp, (Tcl_Object) oPtr, namePtr,
		mPtr->flags & PUBLIC_METHOD, NULL, NULL);
    } else if (mPtr->typePtr->cloneProc) {
	void *newClientData;

	if (mPtr->typePtr->cloneProc(interp, mPtr->clientData,
		&newClientData) != TCL_OK) {
	    return TCL_ERROR;
	}
	TclNewInstanceMethod(interp, (Tcl_Object) oPtr, namePtr,
		mPtr->flags & PUBLIC_METHOD, mPtr->typePtr, newClientData);
    } else {
	TclNewInstanceMethod(interp, (Tcl_Object) oPtr, namePtr,
		mPtr->flags & PUBLIC_METHOD, mPtr->typePtr, mPtr->clientData);
    }
    return TCL_OK;
}

static int
CloneClassMethod(
    Tcl_Interp *interp,
    Class *clsPtr,
    Method *mPtr,
    Tcl_Obj *namePtr,
    Method **m2PtrPtr)
{
    Method *m2Ptr;

    if (mPtr->typePtr == NULL) {
	m2Ptr = (Method *) TclNewMethod((Tcl_Class) clsPtr,
		namePtr, mPtr->flags & PUBLIC_METHOD, NULL, NULL);
    } else if (mPtr->typePtr->cloneProc) {
	void *newClientData;

	if (mPtr->typePtr->cloneProc(interp, mPtr->clientData,
		&newClientData) != TCL_OK) {
	    return TCL_ERROR;
	}
	m2Ptr = (Method *) TclNewMethod((Tcl_Class) clsPtr,
		namePtr, mPtr->flags & PUBLIC_METHOD, mPtr->typePtr,
		newClientData);
    } else {
	m2Ptr = (Method *) TclNewMethod((Tcl_Class) clsPtr,
		namePtr, mPtr->flags & PUBLIC_METHOD, mPtr->typePtr,
		mPtr->clientData);
    }
    if (m2PtrPtr != NULL) {
	*m2PtrPtr = m2Ptr;
    }
    return TCL_OK;
}

/*
 * ----------------------------------------------------------------------
 *
 * Tcl_ClassGetMetadata, Tcl_ClassSetMetadata, Tcl_ObjectGetMetadata,
 * Tcl_ObjectSetMetadata --
 *
 *	Metadata management API. The metadata system allows code in extensions
 *	to attach arbitrary non-NULL pointers to objects and classes without
 *	the different things that might be interested being able to interfere
 *	with each other. Apart from non-NULL-ness, these routines attach no
 *	interpretation to the meaning of the metadata pointers.
 *
 *	The Tcl_*GetMetadata routines get the metadata pointer attached that
 *	has been related with a particular type, or NULL if no metadata
 *	associated with the given type has been attached.
 *
 *	The Tcl_*SetMetadata routines set or delete the metadata pointer that
 *	is related to a particular type. The value associated with the type is
 *	deleted (if present; no-op otherwise) if the value is NULL, and
 *	attached (replacing the previous value, which is deleted if present)
 *	otherwise. This means it is impossible to attach a NULL value for any
 *	metadata type.
 *
 * ----------------------------------------------------------------------
 */

void *
Tcl_ClassGetMetadata(
    Tcl_Class clazz,
    const Tcl_ObjectMetadataType *typePtr)
{
    Class *clsPtr = (Class *) clazz;
    Tcl_HashEntry *hPtr;

    /*
     * If there's no metadata store attached, the type in question has
     * definitely not been attached either!
     */

    if (clsPtr->metadataPtr == NULL) {
	return NULL;
    }

    /*
     * There is a metadata store, so look in it for the given type.
     */

    hPtr = Tcl_FindHashEntry(clsPtr->metadataPtr, typePtr);

    /*
     * Return the metadata value if we found it, otherwise NULL.
     */

    if (hPtr == NULL) {
	return NULL;
    }
    return Tcl_GetHashValue(hPtr);
}

void
Tcl_ClassSetMetadata(
    Tcl_Class clazz,
    const Tcl_ObjectMetadataType *typePtr,
    void *metadata)
{
    Class *clsPtr = (Class *) clazz;
    Tcl_HashEntry *hPtr;
    int isNew;

    /*
     * Attach the metadata store if not done already.
     */

    if (clsPtr->metadataPtr == NULL) {
	if (metadata == NULL) {
	    return;
	}
	clsPtr->metadataPtr = (Tcl_HashTable *)
		Tcl_Alloc(sizeof(Tcl_HashTable));
	Tcl_InitHashTable(clsPtr->metadataPtr, TCL_ONE_WORD_KEYS);
    }

    /*
     * If the metadata is NULL, we're deleting the metadata for the type.
     */

    if (metadata == NULL) {
	hPtr = Tcl_FindHashEntry(clsPtr->metadataPtr, typePtr);
	if (hPtr != NULL) {
	    typePtr->deleteProc(Tcl_GetHashValue(hPtr));
	    Tcl_DeleteHashEntry(hPtr);
	}
	return;
    }

    /*
     * Otherwise we're attaching the metadata. Note that if there was already
     * some metadata attached of this type, we delete that first.
     */

    hPtr = Tcl_CreateHashEntry(clsPtr->metadataPtr, typePtr, &isNew);
    if (!isNew) {
	typePtr->deleteProc(Tcl_GetHashValue(hPtr));
    }
    Tcl_SetHashValue(hPtr, metadata);
}

void *
Tcl_ObjectGetMetadata(
    Tcl_Object object,
    const Tcl_ObjectMetadataType *typePtr)
{
    Object *oPtr = (Object *) object;
    Tcl_HashEntry *hPtr;

    /*
     * If there's no metadata store attached, the type in question has
     * definitely not been attached either!
     */

    if (oPtr->metadataPtr == NULL) {
	return NULL;
    }

    /*
     * There is a metadata store, so look in it for the given type.
     */

    hPtr = Tcl_FindHashEntry(oPtr->metadataPtr, typePtr);

    /*
     * Return the metadata value if we found it, otherwise NULL.
     */

    if (hPtr == NULL) {
	return NULL;
    }
    return Tcl_GetHashValue(hPtr);
}

void
Tcl_ObjectSetMetadata(
    Tcl_Object object,
    const Tcl_ObjectMetadataType *typePtr,
    void *metadata)
{
    Object *oPtr = (Object *) object;
    Tcl_HashEntry *hPtr;
    int isNew;

    /*
     * Attach the metadata store if not done already.
     */

    if (oPtr->metadataPtr == NULL) {
	if (metadata == NULL) {
	    return;
	}
	oPtr->metadataPtr = (Tcl_HashTable *) Tcl_Alloc(sizeof(Tcl_HashTable));
	Tcl_InitHashTable(oPtr->metadataPtr, TCL_ONE_WORD_KEYS);
    }

    /*
     * If the metadata is NULL, we're deleting the metadata for the type.
     */

    if (metadata == NULL) {
	hPtr = Tcl_FindHashEntry(oPtr->metadataPtr, typePtr);
	if (hPtr != NULL) {
	    typePtr->deleteProc(Tcl_GetHashValue(hPtr));
	    Tcl_DeleteHashEntry(hPtr);
	}
	return;
    }

    /*
     * Otherwise we're attaching the metadata. Note that if there was already
     * some metadata attached of this type, we delete that first.
     */

    hPtr = Tcl_CreateHashEntry(oPtr->metadataPtr, typePtr, &isNew);
    if (!isNew) {
	typePtr->deleteProc(Tcl_GetHashValue(hPtr));
    }
    Tcl_SetHashValue(hPtr, metadata);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOPublicObjectCmd, TclOOPrivateObjectCmd, TclOOInvokeObject --
 *
 *	Main entry point for object invocations. The Public* and Private*
 *	wrapper functions (implementations of both object instance commands
 *	and [my]) are just thin wrappers round the main TclOOObjectCmdCore
 *	function. Note that the core is function is NRE-aware.
 *
 * ----------------------------------------------------------------------
 */

int
TclOOPublicObjectCmd(
    void *clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const *objv)
{
    return Tcl_NRCallObjProc(interp, PublicNRObjectCmd, clientData, objc, objv);
}

static int
PublicNRObjectCmd(
    void *clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const *objv)
{
    return TclOOObjectCmdCore((Object *) clientData, interp, objc, objv,
	    PUBLIC_METHOD, NULL);
}

int
TclOOPrivateObjectCmd(
    void *clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const *objv)
{
    return Tcl_NRCallObjProc(interp, PrivateNRObjectCmd, clientData, objc, objv);
}

static int
PrivateNRObjectCmd(
    void *clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const *objv)
{
    return TclOOObjectCmdCore((Object *) clientData, interp, objc, objv, 0, NULL);
}

int
TclOOInvokeObject(
    Tcl_Interp *interp,		/* Interpreter for commands, variables,
				 * results, error reporting, etc. */
    Tcl_Object object,		/* The object to invoke. */
    Tcl_Class startCls,		/* Where in the class chain to start the
				 * invoke from, or NULL to traverse the whole
				 * chain including filters. */
    int publicPrivate,		/* Whether this is an invoke from a public
				 * context (PUBLIC_METHOD), a private context
				 * (PRIVATE_METHOD), or a *really* private
				 * context (any other value; conventionally
				 * 0). */
    Tcl_Size objc,		/* Number of arguments. */
    Tcl_Obj *const *objv)	/* Array of argument objects. It is assumed
				 * that the name of the method to invoke will
				 * be at index 1. */
{
    switch (publicPrivate) {
    case PUBLIC_METHOD:
	return TclOOObjectCmdCore((Object *) object, interp, objc, objv,
		PUBLIC_METHOD, (Class *) startCls);
    case PRIVATE_METHOD:
	return TclOOObjectCmdCore((Object *) object, interp, objc, objv,
		PRIVATE_METHOD, (Class *) startCls);
    default:
	return TclOOObjectCmdCore((Object *) object, interp, objc, objv, 0,
		(Class *) startCls);
    }
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOMyClassObjCmd, MyClassNRObjCmd --
 *
 *	Special trap door to allow an object to delegate simply to its class.
 *
 * ----------------------------------------------------------------------
 */

int
TclOOMyClassObjCmd(
    void *clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const *objv)
{
    return Tcl_NRCallObjProc(interp, MyClassNRObjCmd, clientData, objc, objv);
}

static int
MyClassNRObjCmd(
    void *clientData,
    Tcl_Interp *interp,
    int objc,
    Tcl_Obj *const *objv)
{
    Object *oPtr = (Object *) clientData;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "methodName ?arg ...?");
	return TCL_ERROR;
    }
    return TclOOObjectCmdCore(oPtr->selfCls->thisPtr, interp, objc, objv, 0,
	    NULL);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOObjectCmdCore, FinalizeObjectCall --
 *
 *	Main function for object invocations. Does call chain creation,
 *	management and invocation. The function FinalizeObjectCall exists to
 *	clean up after the non-recursive processing of TclOOObjectCmdCore.
 *
 * ----------------------------------------------------------------------
 */

int
TclOOObjectCmdCore(
    Object *oPtr,		/* The object being invoked. */
    Tcl_Interp *interp,		/* The interpreter containing the object. */
    Tcl_Size objc,		/* How many arguments are being passed in. */
    Tcl_Obj *const *objv,	/* The array of arguments. */
    int flags,			/* Whether this is an invocation through the
				 * public or the private command interface. */
    Class *startCls)		/* Where to start in the call chain, or NULL
				 * if we are to start at the front with
				 * filters and the object's methods (which is
				 * the normal case). */
{
    CallContext *contextPtr;
    Tcl_Obj *methodNamePtr;
    CallFrame *framePtr = ((Interp *) interp)->varFramePtr;
    Object *callerObjPtr = NULL;
    Class *callerClsPtr = NULL;
    int result;

    /*
     * If we've no method name, throw this directly into the unknown
     * processing.
     */

    if (objc < 2) {
	flags |= FORCE_UNKNOWN;
	methodNamePtr = NULL;
	goto noMapping;
    }

    /*
     * Determine if we're in a context that can see the extra, private methods
     * in this class.
     */

    if (framePtr->isProcCallFrame & FRAME_IS_METHOD) {
	CallContext *callerContextPtr = (CallContext *) framePtr->clientData;
	Method *callerMethodPtr =
		callerContextPtr->callPtr->chain[callerContextPtr->index].mPtr;

	if (callerMethodPtr->declaringObjectPtr) {
	    callerObjPtr = callerMethodPtr->declaringObjectPtr;
	}
	if (callerMethodPtr->declaringClassPtr) {
	    callerClsPtr = callerMethodPtr->declaringClassPtr;
	}
    }

    /*
     * Give plugged in code a chance to remap the method name.
     */

    methodNamePtr = objv[1];
    if (oPtr->mapMethodNameProc != NULL) {
	Class **startClsPtr = &startCls;
	Tcl_Obj *mappedMethodName = Tcl_DuplicateObj(methodNamePtr);

	result = oPtr->mapMethodNameProc(interp, (Tcl_Object) oPtr,
		(Tcl_Class *) startClsPtr, mappedMethodName);
	if (result != TCL_OK) {
	    TclDecrRefCount(mappedMethodName);
	    if (result == TCL_BREAK) {
		goto noMapping;
	    } else if (result == TCL_ERROR) {
		Tcl_AddErrorInfo(interp, "\n    (while mapping method name)");
	    }
	    return result;
	}

	/*
	 * Get the call chain for the remapped name.
	 */

	Tcl_IncrRefCount(mappedMethodName);
	contextPtr = TclOOGetCallContext(oPtr, mappedMethodName,
		flags | (oPtr->flags & FILTER_HANDLING), callerObjPtr,
		callerClsPtr, methodNamePtr);
	TclDecrRefCount(mappedMethodName);
	if (contextPtr == NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "impossible to invoke method \"%s\": no defined method or"
		    " unknown method", TclGetString(methodNamePtr)));
	    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "METHOD_MAPPED",
		    TclGetString(methodNamePtr), (char *)NULL);
	    return TCL_ERROR;
	}
    } else {
	/*
	 * Get the call chain.
	 */

    noMapping:
	contextPtr = TclOOGetCallContext(oPtr, methodNamePtr,
		flags | (oPtr->flags & FILTER_HANDLING), callerObjPtr,
		callerClsPtr, NULL);
	if (contextPtr == NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "impossible to invoke method \"%s\": no defined method or"
		    " unknown method", TclGetString(methodNamePtr)));
	    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "METHOD",
		    TclGetString(methodNamePtr), (char *)NULL);
	    return TCL_ERROR;
	}
    }

    /*
     * Check to see if we need to apply magical tricks to start part way
     * through the call chain.
     */

    if (startCls != NULL) {
	for (; contextPtr->index < contextPtr->callPtr->numChain;
		contextPtr->index++) {
	    MInvoke *miPtr = &contextPtr->callPtr->chain[contextPtr->index];

	    if (miPtr->isFilter) {
		continue;
	    }
	    if (miPtr->mPtr->declaringClassPtr == startCls) {
		break;
	    }
	}
	if (contextPtr->index >= contextPtr->callPtr->numChain) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "no valid method implementation", TCL_AUTO_LENGTH));
	    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "METHOD",
		    TclGetString(methodNamePtr), (char *)NULL);
	    TclOODeleteContext(contextPtr);
	    return TCL_ERROR;
	}
    }

    /*
     * Invoke the call chain, locking the object structure against deletion
     * for the duration.
     */

    TclNRAddCallback(interp, FinalizeObjectCall, contextPtr, NULL,NULL,NULL);
    return TclOOInvokeContext(contextPtr, interp, objc, objv);
}

static int
FinalizeObjectCall(
    void *data[],
    TCL_UNUSED(Tcl_Interp *),
    int result)
{
    /*
     * Dispose of the call chain, which drops the lock on the object's
     * structure.
     */

    TclOODeleteContext((CallContext *) data[0]);
    return result;
}

/*
 * ----------------------------------------------------------------------
 *
 * Tcl_ObjectContextInvokeNext, TclNRObjectContextInvokeNext, FinalizeNext --
 *
 *	Invokes the next stage of the call chain described in an object
 *	context. This is the core of the implementation of the [next] command.
 *	Does not do management of the call-frame stack. Available in public
 *	(standard API) and private (NRE-aware) forms. FinalizeNext is a
 *	private function used to clean up in the NRE case.
 *
 * ----------------------------------------------------------------------
 */

int
Tcl_ObjectContextInvokeNext(
    Tcl_Interp *interp,
    Tcl_ObjectContext context,
    Tcl_Size objc,
    Tcl_Obj *const *objv,
    Tcl_Size skip)
{
    CallContext *contextPtr = (CallContext *) context;
    size_t savedIndex = contextPtr->index;
    size_t savedSkip = contextPtr->skip;
    int result;

    if (contextPtr->index + 1 >= contextPtr->callPtr->numChain) {
	/*
	 * We're at the end of the chain; generate an error message unless the
	 * interpreter is being torn down, in which case we might be getting
	 * here because of methods/destructors doing a [next] (or equivalent)
	 * unexpectedly.
	 */

	const char *methodType;

	if (Tcl_InterpDeleted(interp)) {
	    return TCL_OK;
	}

	if (contextPtr->callPtr->flags & CONSTRUCTOR) {
	    methodType = "constructor";
	} else if (contextPtr->callPtr->flags & DESTRUCTOR) {
	    methodType = "destructor";
	} else {
	    methodType = "method";
	}

	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"no next %s implementation", methodType));
	OO_ERROR(interp, NOTHING_NEXT);
	return TCL_ERROR;
    }

    /*
     * Advance to the next method implementation in the chain in the method
     * call context while we process the body. However, need to adjust the
     * argument-skip control because we're guaranteed to have a single prefix
     * arg (i.e., 'next') and not the variable amount that can happen because
     * method invocations (i.e., '$obj meth' and 'my meth'), constructors
     * (i.e., '$cls new' and '$cls create obj') and destructors (no args at
     * all) come through the same code.
     */

    contextPtr->index++;
    contextPtr->skip = skip;

    /*
     * Invoke the (advanced) method call context in the caller context.
     */

    result = Tcl_NRCallObjProc(interp, TclOOInvokeContext, contextPtr, objc,
	    objv);

    /*
     * Restore the call chain context index as we've finished the inner invoke
     * and want to operate in the outer context again.
     */

    contextPtr->index = savedIndex;
    contextPtr->skip = savedSkip;

    return result;
}

int
TclNRObjectContextInvokeNext(
    Tcl_Interp *interp,
    Tcl_ObjectContext context,
    Tcl_Size objc,
    Tcl_Obj *const *objv,
    Tcl_Size skip)
{
    CallContext *contextPtr = (CallContext *) context;

    if (contextPtr->index + 1 >= contextPtr->callPtr->numChain) {
	/*
	 * We're at the end of the chain; generate an error message unless the
	 * interpreter is being torn down, in which case we might be getting
	 * here because of methods/destructors doing a [next] (or equivalent)
	 * unexpectedly.
	 */

	const char *methodType;

	if (Tcl_InterpDeleted(interp)) {
	    return TCL_OK;
	}

	if (contextPtr->callPtr->flags & CONSTRUCTOR) {
	    methodType = "constructor";
	} else if (contextPtr->callPtr->flags & DESTRUCTOR) {
	    methodType = "destructor";
	} else {
	    methodType = "method";
	}

	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"no next %s implementation", methodType));
	OO_ERROR(interp, NOTHING_NEXT);
	return TCL_ERROR;
    }

    /*
     * Advance to the next method implementation in the chain in the method
     * call context while we process the body. However, need to adjust the
     * argument-skip control because we're guaranteed to have a single prefix
     * arg (i.e., 'next') and not the variable amount that can happen because
     * method invocations (i.e., '$obj meth' and 'my meth'), constructors
     * (i.e., '$cls new' and '$cls create obj') and destructors (no args at
     * all) come through the same code.
     */

    TclNRAddCallback(interp, FinalizeNext, contextPtr,
	    INT2PTR(contextPtr->index), INT2PTR(contextPtr->skip), NULL);
    contextPtr->index++;
    contextPtr->skip = skip;

    /*
     * Invoke the (advanced) method call context in the caller context.
     */

    return TclOOInvokeContext(contextPtr, interp, objc, objv);
}

static int
FinalizeNext(
    void *data[],
    TCL_UNUSED(Tcl_Interp *),
    int result)
{
    CallContext *contextPtr = (CallContext *) data[0];

    /*
     * Restore the call chain context index as we've finished the inner invoke
     * and want to operate in the outer context again.
     */

    contextPtr->index = PTR2INT(data[1]);
    contextPtr->skip = PTR2INT(data[2]);
    return result;
}

/*
 * ----------------------------------------------------------------------
 *
 * Tcl_GetObjectFromObj --
 *
 *	Utility function to get an object from a Tcl_Obj containing its name.
 *
 * ----------------------------------------------------------------------
 */

Tcl_Object
Tcl_GetObjectFromObj(
    Tcl_Interp *interp,		/* Interpreter in which to locate the object.
				 * Will have an error message placed in it if
				 * the name does not refer to an object. */
    Tcl_Obj *objPtr)		/* The name of the object to look up, which is
				 * exactly the name of its public command. */
{
    Command *cmdPtr = (Command *) Tcl_GetCommandFromObj(interp, objPtr);

    if (cmdPtr == NULL) {
	goto notAnObject;
    }
    if (cmdPtr->objProc != TclOOPublicObjectCmd) {
	cmdPtr = (Command *) TclGetOriginalCommand((Tcl_Command) cmdPtr);
	if (cmdPtr == NULL || cmdPtr->objProc != TclOOPublicObjectCmd) {
	    goto notAnObject;
	}
    }
    return (Tcl_Object) cmdPtr->objClientData;

  notAnObject:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "%s does not refer to an object", TclGetString(objPtr)));
    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "OBJECT", TclGetString(objPtr),
	    (char *)NULL);
    return NULL;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOIsReachable --
 *
 *	Utility function that tests whether a class is a subclass (whether
 *	directly or indirectly) of another class.
 *
 * ----------------------------------------------------------------------
 */

int
TclOOIsReachable(
    Class *targetPtr,
    Class *startPtr)
{
    Tcl_Size i;
    Class *superPtr;

  tailRecurse:
    if (startPtr == targetPtr) {
	return 1;
    }
    if (startPtr->superclasses.num == 1 && startPtr->mixins.num == 0) {
	startPtr = startPtr->superclasses.list[0];
	goto tailRecurse;
    }
    FOREACH(superPtr, startPtr->superclasses) {
	if (TclOOIsReachable(targetPtr, superPtr)) {
	    return 1;
	}
    }
    FOREACH(superPtr, startPtr->mixins) {
	if (TclOOIsReachable(targetPtr, superPtr)) {
	    return 1;
	}
    }
    return 0;
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOObjectName, Tcl_GetObjectName --
 *
 *	Utility function that returns the name of the object. Note that this
 *	simplifies cache management by keeping the code to do it in one place
 *	and not sprayed all over. The value returned always has a reference
 *	count of at least one.
 *
 * ----------------------------------------------------------------------
 */

Tcl_Obj *
TclOOObjectName(
    Tcl_Interp *interp,
    Object *oPtr)
{
    Tcl_Obj *namePtr;

    if (oPtr->cachedNameObj) {
	return oPtr->cachedNameObj;
    }
    TclNewObj(namePtr);
    Tcl_GetCommandFullName(interp, oPtr->command, namePtr);
    Tcl_IncrRefCount(namePtr);
    oPtr->cachedNameObj = namePtr;
    return namePtr;
}

Tcl_Obj *
Tcl_GetObjectName(
    Tcl_Interp *interp,
    Tcl_Object object)
{
    return TclOOObjectName(interp, (Object *) object);
}

/*
 * ----------------------------------------------------------------------
 *
 * TclOOObjectMyName --
 *
 *	Utility function that returns the name of the object's [my], or NULL
 *	if it has been deleted (or otherwise doesn't exist).
 *
 * ----------------------------------------------------------------------
 */
Tcl_Obj *
TclOOObjectMyName(
    Tcl_Interp *interp,
    Object *oPtr)
{
    Tcl_Obj *namePtr;
    if (!oPtr->myCommand) {
	return NULL;
    }
    TclNewObj(namePtr);
    Tcl_GetCommandFullName(interp, oPtr->myCommand, namePtr);
    return namePtr;
}

/*
 * ----------------------------------------------------------------------
 *
 * assorted trivial 'getter' functions
 *
 * ----------------------------------------------------------------------
 */

Tcl_Method
Tcl_ObjectContextMethod(
    Tcl_ObjectContext context)
{
    CallContext *contextPtr = (CallContext *) context;
    return (Tcl_Method) contextPtr->callPtr->chain[contextPtr->index].mPtr;
}

int
Tcl_ObjectContextIsFiltering(
    Tcl_ObjectContext context)
{
    CallContext *contextPtr = (CallContext *) context;
    return contextPtr->callPtr->chain[contextPtr->index].isFilter;
}

Tcl_Object
Tcl_ObjectContextObject(
    Tcl_ObjectContext context)
{
    return (Tcl_Object) ((CallContext *) context)->oPtr;
}

Tcl_Size
Tcl_ObjectContextSkippedArgs(
    Tcl_ObjectContext context)
{
    return ((CallContext *) context)->skip;
}

Tcl_Namespace *
Tcl_GetObjectNamespace(
    Tcl_Object object)
{
    return ((Object *) object)->namespacePtr;
}

Tcl_Command
Tcl_GetObjectCommand(
    Tcl_Object object)
{
    return ((Object *) object)->command;
}

Tcl_Class
Tcl_GetObjectAsClass(
    Tcl_Object object)
{
    return (Tcl_Class) ((Object *) object)->classPtr;
}

int
Tcl_ObjectDeleted(
    Tcl_Object object)
{
    return ((Object *) object)->command == NULL;
}

Tcl_Object
Tcl_GetClassAsObject(
    Tcl_Class clazz)
{
    return (Tcl_Object) ((Class *) clazz)->thisPtr;
}

Tcl_ObjectMapMethodNameProc *
Tcl_ObjectGetMethodNameMapper(
    Tcl_Object object)
{
    return ((Object *) object)->mapMethodNameProc;
}

void
Tcl_ObjectSetMethodNameMapper(
    Tcl_Object object,
    Tcl_ObjectMapMethodNameProc *mapMethodNameProc)
{
    ((Object *) object)->mapMethodNameProc = mapMethodNameProc;
}

Tcl_Class
Tcl_GetClassOfObject(
    Tcl_Object object)
{
    return (Tcl_Class) ((Object *) object)->selfCls;
}

Tcl_Obj *
Tcl_GetObjectClassName(
    Tcl_Interp *interp,
    Tcl_Object object)
{
    Tcl_Object classObj = (Tcl_Object) (((Object *) object)->selfCls)->thisPtr;

    if (classObj == NULL) {
	return NULL;
    }
    return Tcl_GetObjectName(interp, classObj);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
