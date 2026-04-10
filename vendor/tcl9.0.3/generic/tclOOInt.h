/*
 * tclOOInt.h --
 *
 *	This file contains the structure definitions and some of the function
 *	declarations for the object-system (NB: not Tcl_Obj, but ::oo).
 *
 * Copyright (c) 2006-2012 by Donal K. Fellows
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#ifndef TCL_OO_INTERNAL_H
#define TCL_OO_INTERNAL_H 1

#include "tclInt.h"
#include "tclOO.h"

/*
 * Hack to make things work with Objective C. Note that ObjC isn't really
 * supported, but we don't want to to be actively hostile to it. [Bug 2163447]
 */

#ifdef __OBJC__
#define Class	TclOOClass
#define Object	TclOOObject
#endif /* __OBJC__ */

/*
 * Forward declarations.
 */

typedef struct CallChain CallChain;
typedef struct CallContext CallContext;
typedef struct Class Class;
typedef struct DeclaredClassMethod DeclaredClassMethod;
typedef struct ForwardMethod ForwardMethod;
typedef struct Foundation Foundation;
typedef struct Method Method;
typedef struct MInvoke MInvoke;
typedef struct Object Object;
typedef struct PrivateVariableMapping PrivateVariableMapping;
typedef struct ProcedureMethod ProcedureMethod;
typedef struct PropertyStorage PropertyStorage;

/*
 * The data that needs to be stored per method. This record is used to collect
 * information about all sorts of methods, including forwards, constructors
 * and destructors.
 */
struct Method {
    union {
	const Tcl_MethodType *typePtr;
#if TCL_MAJOR_VERSION > 8
	const Tcl_MethodType2 *type2Ptr;
#endif
    };				/* The type of method. If NULL, this is a
				 * special flag record which is just used for
				 * the setting of the flags field. Note that
				 * this is a union of two pointer types that
				 * have the same layout at least as far as the
				 * internal version field. */
    Tcl_Size refCount;
    void *clientData;		/* Type-specific data. */
    Tcl_Obj *namePtr;		/* Name of the method. */
    Object *declaringObjectPtr;	/* The object that declares this method, or
				 * NULL if it was declared by a class. */
    Class *declaringClassPtr;	/* The class that declares this method, or
				 * NULL if it was declared directly on an
				 * object. */
    int flags;			/* Assorted flags. Includes whether this
				 * method is public/exported or not. */
};

/*
 * Pre- and post-call callbacks, to allow procedure-like methods to be fine
 * tuned in their behaviour.
 */

typedef int (TclOO_PreCallProc)(void *clientData, Tcl_Interp *interp,
	Tcl_ObjectContext context, Tcl_CallFrame *framePtr, int *isFinished);
typedef int (TclOO_PostCallProc)(void *clientData, Tcl_Interp *interp,
	Tcl_ObjectContext context, Tcl_Namespace *namespacePtr, int result);
typedef void (TclOO_PmCDDeleteProc)(void *clientData);
typedef void *(TclOO_PmCDCloneProc)(void *clientData);

/*
 * Procedure-like methods have the following extra information.
 */
struct ProcedureMethod {
    int version;		/* Version of this structure. Currently must
				 * be TCLOO_PROCEDURE_METHOD_VERSION_1. */
    Proc *procPtr;		/* Core of the implementation of the method;
				 * includes the argument definition and the
				 * body bytecodes. */
    int flags;			/* Flags to control features. */
    Tcl_Size refCount;
    void *clientData;
    TclOO_PmCDDeleteProc *deleteClientdataProc;
    TclOO_PmCDCloneProc *cloneClientdataProc;
    ProcErrorProc *errProc;	/* Replacement error handler. */
    TclOO_PreCallProc *preCallProc;
				/* Callback to allow for additional setup
				 * before the method executes. */
    TclOO_PostCallProc *postCallProc;
				/* Callback to allow for additional cleanup
				 * after the method executes. */
    GetFrameInfoValueProc *gfivProc;
				/* Callback to allow for fine tuning of how
				 * the method reports itself. */
    Command cmd;		/* Space used to connect to [info frame] */
    ExtraFrameInfo efi;		/* Space used to store data for [info frame] */
    Tcl_Interp *interp;		/* Interpreter in which to compute the name of
				 * the method. */
    Tcl_Method method;		/* Method to compute the name of. */
    int callSiteFlags;		/* Flags from the call chain. Only interested
				 * in whether this is a constructor or
				 * destructor, which we can't know until then
				 * for messy reasons. Other flags are variable
				 * but not used. */
};

enum ProcedureMethodVersion {
    TCLOO_PROCEDURE_METHOD_VERSION_1 = 0
};
#define TCLOO_PROCEDURE_METHOD_VERSION TCLOO_PROCEDURE_METHOD_VERSION_1

/*
 * Flags for use in a ProcedureMethod.
 *
 */
enum ProceudreMethodFlags {
    USE_DECLARER_NS = 0x80	/* When set, the method will use the namespace
				 * of the object or class that declared it (or
				 * the clone of it, if it was from such that
				 * the implementation of the method came to the
				 * particular use) instead of the namespace of
				 * the object on which the method was invoked.
				 * This flag must be distinct from all others
				 * that are associated with methods. */
};

/*
 * Forwarded methods have the following extra information.
 */
struct ForwardMethod {
    Tcl_Obj *prefixObj;		/* The list of values to use to replace the
				 * object and method name with. Will be a
				 * non-empty list. */
};

/*
 * Structure used in private variable mappings. Describes the mapping of a
 * single variable from the user's local name to the system's storage name.
 * [TIP #500]
 */
struct PrivateVariableMapping {
    Tcl_Obj *variableObj;	/* Name used within methods. This is the part
				 * that is properly under user control. */
    Tcl_Obj *fullNameObj;	/* Name used at the instance namespace level. */
};

/*
 * Helper definitions that declare a "list" array. The two varieties are
 * either optimized for simplicity (in the case that the whole array is
 * typically assigned at once) or efficiency (in the case that the array is
 * expected to be expanded over time). These lists are designed to be iterated
 * over with the help of the FOREACH macro (see later in this file).
 *
 * The "num" field always counts the number of listType_t elements used in the
 * "list" field. When a "size" field exists, it describes how many elements
 * are present in the list; when absent, exactly "num" elements are present.
 */

#define LIST_STATIC(listType_t) \
    struct { Tcl_Size num; listType_t *list; }
#define LIST_DYNAMIC(listType_t) \
    struct { Tcl_Size num, size; listType_t *list; }

/*
 * These types are needed in function arguments.
 */

typedef LIST_STATIC(Class *) ClassList;
typedef LIST_DYNAMIC(Class *) VarClassList;
typedef LIST_STATIC(Tcl_Obj *) FilterList;
typedef LIST_DYNAMIC(Object *) ObjectList;
typedef LIST_STATIC(Tcl_Obj *) VariableNameList;
typedef LIST_STATIC(PrivateVariableMapping) PrivateVariableList;
typedef LIST_STATIC(Tcl_Obj *) PropertyList;

/*
 * This type is used in various places. It holds the parts of an object or
 * class relating to property information.
 */
struct PropertyStorage {
    PropertyList readable;	/* The readable properties slot. */
    PropertyList writable;	/* The writable properties slot. */
    Tcl_Obj *allReadableCache;	/* The cache of all readable properties
				 * exposed by this object or class (in its
				 * stereotypical instancs). Contains a sorted
				 * unique list if not NULL. */
    Tcl_Obj *allWritableCache;	/* The cache of all writable properties
				 * exposed by this object or class (in its
				 * stereotypical instances). Contains a sorted
				 * unique list if not NULL. */
    int epoch;			/* The epoch that the caches are valid for. */
};

/*
 * Now, the definition of what an object actually is.
 */

struct Object {
    Foundation *fPtr;		/* The basis for the object system, which is
				 * conceptually part of the interpreter. */
    Tcl_Namespace *namespacePtr;/* This object's namespace. */
    Tcl_Command command;	/* Reference to this object's public
				 * command. */
    Tcl_Command myCommand;	/* Reference to this object's internal
				 * command. */
    Class *selfCls;		/* This object's class. */
    Tcl_HashTable *methodsPtr;	/* Object-local Tcl_Obj (method name) to
				 * Method* mapping. */
    ClassList mixins;		/* Classes mixed into this object. */
    FilterList filters;		/* List of filter names. */
    Class *classPtr;		/* This is non-NULL for all classes, and NULL
				 * for everything else. It points to the class
				 * structure. */
    Tcl_Size refCount;		/* Number of strong references to this object.
				 * Note that there may be many more weak
				 * references; this mechanism exists to
				 * avoid Tcl_Preserve. */
    int flags;			/* See ObjectFlags. */
    Tcl_Size creationEpoch;	/* Unique value to make comparisons of objects
				 * easier. */
    Tcl_Size epoch;		/* Per-object epoch, incremented when the way
				 * an object should resolve call chains is
				 * changed. */
    Tcl_HashTable *metadataPtr;	/* Mapping from pointers to metadata type to
				 * the void *values that are the values
				 * of each piece of attached metadata. This
				 * field starts out as NULL and is only
				 * allocated if metadata is attached. */
    Tcl_Obj *cachedNameObj;	/* Cache of the name of the object. */
    Tcl_HashTable *chainCache;	/* Place to keep unused contexts. This table
				 * is indexed by method name as Tcl_Obj. */
    Tcl_ObjectMapMethodNameProc *mapMethodNameProc;
				/* Function to allow remapping of method
				 * names. For itcl-ng. */
    VariableNameList variables;
    PrivateVariableList privateVariables;
				/* Configurations for the variable resolver
				 * used inside methods. */
    Tcl_Command myclassCommand;	/* Reference to this object's class dispatcher
				 * command. */
    PropertyStorage properties;	/* Information relating to the lists of
				 * properties that this object *claims* to
				 * support. */
    Tcl_Obj *linkedCmdsList;	/* List of names of linked commands. */
};

enum ObjectFlags {
    OBJECT_DESTRUCTING = 1,	/* Indicates that an object is being or has
				 *  been destroyed  */
    DESTRUCTOR_CALLED = 2,	/* Indicates that evaluation of destructor
				 * script for the object has began */
    ROOT_OBJECT = 0x1000,	/* Flag to say that this object is the root of
				 * the class hierarchy and should be treated
				 * specially during teardown. */
    FILTER_HANDLING = 0x2000,	/* Flag set when the object is processing a
				 * filter; when set, filters are *not*
				 * processed on the object, preventing nasty
				 * recursive filtering problems. */
    USE_CLASS_CACHE = 0x4000,	/* Flag set to say that the object is a pure
				 * instance of the class, and has had nothing
				 * added that changes the dispatch chain (i.e.
				 * no methods, mixins, or filters. */
    ROOT_CLASS = 0x8000,	/* Flag to say that this object is the root
				 * class of classes, and should be treated
				 * specially during teardown (and in a few
				 * other spots). */
    FORCE_UNKNOWN = 0x10000,	/* States that we are *really* looking up the
				 * unknown method handler at that point. */
    DONT_DELETE = 0x20000,	/* Inhibit deletion of this object. Used
				 * during fundamental object type mutation to
				 * make sure that the object actually survives
				 * to the end of the operation. */
    HAS_PRIVATE_METHODS = 0x40000
				/* Object/class has (or had) private methods,
				 * and so shouldn't be cached so
				 * aggressively. */
};

/*
 * And the definition of a class. Note that every class also has an associated
 * object, through which it is manipulated.
 */

struct Class {
    Object *thisPtr;		/* Reference to the object associated with
				 * this class. */
    int flags;			/* Assorted flags. */
    ClassList superclasses;	/* List of superclasses, used for generation
				 * of method call chains. */
    VarClassList subclasses;	/* List of subclasses, used to ensure deletion
				 * of dependent entities happens properly when
				 * the class itself is deleted. */
    ObjectList instances;	/* List of instances, used to ensure deletion
				 * of dependent entities happens properly when
				 * the class itself is deleted. */
    FilterList filters;		/* List of filter names, used for generation
				 * of method call chains. */
    ClassList mixins;		/* List of mixin classes, used for generation
				 * of method call chains. */
    VarClassList mixinSubs;	/* List of classes that this class is mixed
				 * into, used to ensure deletion of dependent
				 * entities happens properly when the class
				 * itself is deleted. */
    Tcl_HashTable classMethods;	/* Hash table of all methods. Hash maps from
				 * the (Tcl_Obj*) method name to the (Method*)
				 * method record. */
    Method *constructorPtr;	/* Method record of the class constructor (if
				 * any). */
    Method *destructorPtr;	/* Method record of the class destructor (if
				 * any). */
    Tcl_HashTable *metadataPtr;	/* Mapping from pointers to metadata type to
				 * the void *values that are the values
				 * of each piece of attached metadata. This
				 * field starts out as NULL and is only
				 * allocated if metadata is attached. */
    CallChain *constructorChainPtr;
    CallChain *destructorChainPtr;
    Tcl_HashTable *classChainCache;
				/* Places where call chains are stored. For
				 * constructors, the class chain is always
				 * used. For destructors and ordinary methods,
				 * the class chain is only used when the
				 * object doesn't override with its own mixins
				 * (and filters and method implementations for
				 * when getting method chains). */
    VariableNameList variables;
    PrivateVariableList privateVariables;
				/* Configurations for the variable resolver
				 * used inside methods. */
    Tcl_Obj *clsDefinitionNs;	/* Name of the namespace to use for
				 * definitions commands of instances of this
				 * class in when those instances are defined
				 * as classes. If NULL, use the value from the
				 * class hierarchy. It's an error at
				 * [oo::define] call time if this namespace is
				 * defined but doesn't exist; we also check at
				 * setting time but don't check between
				 * times. */
    Tcl_Obj *objDefinitionNs;	/* Name of the namespace to use for
				 * definitions commands of instances of this
				 * class in when those instances are defined
				 * as instances. If NULL, use the value from
				 * the class hierarchy. It's an error at
				 * [oo::objdefine]/[self] call time if this
				 * namespace is defined but doesn't exist; we
				 * also check at setting time but don't check
				 * between times. */
    PropertyStorage properties;	/* Information relating to the lists of
				 * properties that this class *claims* to
				 * support. */
};

/*
 * Master epoch counter for making unique IDs for objects that can be compared
 * cheaply.
 */
typedef struct ThreadLocalData {
    Tcl_Size nsCount;		/* Epoch counter is used for keeping
				 * the values used in Tcl_Obj internal
				 * representations sane. Must be thread-local
				 * because Tcl_Objs can cross interpreter
				 * boundaries within a thread (objects don't
				 * generally cross threads). */
} ThreadLocalData;

/*
 * The foundation of the object system within an interpreter contains
 * references to the key classes and namespaces, together with a few other
 * useful bits and pieces. Probably ought to eventually go in the Interp
 * structure itself.
 */
struct Foundation {
    Tcl_Interp *interp;		/* The interpreter this is attached to. */
    Class *objectCls;		/* The root of the object system. */
    Class *classCls;		/* The class of all classes. */
    Tcl_Namespace *ooNs;	/* ::oo namespace. */
    Tcl_Namespace *helpersNs;	/* Namespace containing the commands that are
				 * only valid when executing inside a
				 * procedural method. */
    Tcl_Size epoch;		/* Used to invalidate method chains when the
				 * class structure changes. */
    ThreadLocalData *tsdPtr;	/* Counter so we can allocate a unique
				 * namespace to each object. */
    Tcl_Obj *unknownMethodNameObj;
				/* Shared object containing the name of the
				 * unknown method handler method. */
    Tcl_Obj *constructorName;	/* Shared object containing the "name" of a
				 * constructor. */
    Tcl_Obj *destructorName;	/* Shared object containing the "name" of a
				 * destructor. */
    Tcl_Obj *clonedName;	/* Shared object containing the name of a
				 * "<cloned>" pseudo-constructor. */
    Tcl_Obj *defineName;	/* Fully qualified name of oo::define. */
    Tcl_Obj *myName;		/* The "my" shared object. */
    Tcl_Obj *slotGetName;	/* The "Get" name used by slots. */
    Tcl_Obj *slotSetName;	/* The "Set" name used by slots. */
    Tcl_Obj *slotResolveName;	/* The "Resolve" name used by slots. */
    Tcl_Obj *slotDefOpName;	/* The "--default-operation" name used by slots. */
};

/*
 * The number of MInvoke records in the CallChain before we allocate
 * separately.
 */
#define CALL_CHAIN_STATIC_SIZE 4

/*
 * Information relating to the invocation of a particular method implementation
 * in a call chain.
 */
struct MInvoke {
    Method *mPtr;		/* Reference to the method implementation
				 * record. */
    int isFilter;		/* Whether this is a filter invocation. */
    Class *filterDeclarer;	/* What class decided to add the filter; if
				 * NULL, it was added by the object. */
};

/*
 * The cacheable part of a call context.
 */
struct CallChain {
    Tcl_Size objectCreationEpoch;/* The object's creation epoch. Note that the
				 * object reference is not stored in the call
				 * chain; it is in the call context. */
    Tcl_Size objectEpoch;	/* Local (object structure) epoch counter
				 * snapshot. */
    Tcl_Size epoch;		/* Global (class structure) epoch counter
				 * snapshot. */
    int flags;			/* Assorted flags, see below. */
    Tcl_Size refCount;		/* Reference count. */
    Tcl_Size numChain;		/* Size of the call chain. */
    MInvoke *chain;		/* Array of call chain entries. May point to
				 * staticChain if the number of entries is
				 * small. */
    MInvoke staticChain[CALL_CHAIN_STATIC_SIZE];
};

/*
 * A call context structure is built when a method is called. It contains the
 * chain of method implementations that are to be invoked by a particular
 * call, and the process of calling walks the chain, with the [next] command
 * proceeding to the next entry in the chain.
 */
struct CallContext {
    Object *oPtr;		/* The object associated with this call. */
    Tcl_Size index;		/* Index into the call chain of the currently
				 * executing method implementation. */
    Tcl_Size skip;		/* Current number of arguments to skip; can
				 * vary depending on whether it is a direct
				 * method call or a continuation via the
				 * [next] command. */
    CallChain *callPtr;		/* The actual call chain. */
};

/*
 * Bits for the 'flags' field of the call chain.
 */
enum TclOOCallChainFlags {
    PUBLIC_METHOD = 0x01,	/* This is a public (exported) method. */
    PRIVATE_METHOD = 0x02,	/* This is a private (class's direct instances
				 * only) method. Supports itcl. */
    OO_UNKNOWN_METHOD = 0x04,	/* This is an unknown method. */
    CONSTRUCTOR = 0x08,		/* This is a constructor. */
    DESTRUCTOR = 0x10,		/* This is a destructor. */
    TRUE_PRIVATE_METHOD = 0x20	/* This is a private method only accessible
				 * from other methods defined on this class
				 * or instance. [TIP #500] */
};
#define SCOPE_FLAGS (PUBLIC_METHOD | PRIVATE_METHOD | TRUE_PRIVATE_METHOD)

/*
 * Structure containing definition information about basic class methods.
 */
struct DeclaredClassMethod {
    const char *name;		/* Name of the method in question. */
    int isPublic;		/* Whether the method is public by default. */
    Tcl_MethodType definition;	/* How to call the method. */
};

/*
 *----------------------------------------------------------------
 * Commands relating to OO support.
 *----------------------------------------------------------------
 */

MODULE_SCOPE int		TclOOInit(Tcl_Interp *interp);
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOOObjDefObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineClassMethodObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineConstructorObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineDefnNsObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineDeleteMethodObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineDestructorObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineExportObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineForwardObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineInitialiseObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineMethodObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineRenameMethodObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineUnexportObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineClassObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineSelfObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefineObjSelfObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefinePrivateObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODefinePropertyCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOOUnknownDefinition;
MODULE_SCOPE Tcl_ObjCmdProc	TclOOCallbackObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOOClassVariableObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOOCopyObjectCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOODelegateNameObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOOLinkObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOONextObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOONextToObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOOSelfObjCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOOInfoObjectPropCmd;
MODULE_SCOPE Tcl_ObjCmdProc	TclOOInfoClassPropCmd;

/*
 * Method implementations (in tclOOBasic.c).
 */

MODULE_SCOPE Tcl_MethodCallProc	TclOO_Class_Cloned;
MODULE_SCOPE Tcl_MethodCallProc	TclOO_Class_Constructor;
MODULE_SCOPE Tcl_MethodCallProc	TclOO_Class_Create;
MODULE_SCOPE Tcl_MethodCallProc	TclOO_Class_CreateNs;
MODULE_SCOPE Tcl_MethodCallProc	TclOO_Class_New;
MODULE_SCOPE Tcl_MethodCallProc	TclOO_Object_Cloned;
MODULE_SCOPE Tcl_MethodCallProc	TclOO_Object_Destroy;
MODULE_SCOPE Tcl_MethodCallProc	TclOO_Object_Eval;
MODULE_SCOPE Tcl_MethodCallProc	TclOO_Object_LinkVar;
MODULE_SCOPE Tcl_MethodCallProc	TclOO_Object_Unknown;
MODULE_SCOPE Tcl_MethodCallProc	TclOO_Object_VarName;
MODULE_SCOPE Tcl_MethodCallProc TclOO_Configurable_Configure;
MODULE_SCOPE Tcl_MethodCallProc TclOO_Configurable_Constructor;
MODULE_SCOPE Tcl_MethodCallProc TclOO_Singleton_New;
MODULE_SCOPE Tcl_MethodCallProc TclOO_SingletonInstance_Cloned;
MODULE_SCOPE Tcl_MethodCallProc TclOO_SingletonInstance_Destroy;

/*
 * Private definitions, some of which perhaps ought to be exposed properly or
 * maybe just put in the internal stubs table.
 */

MODULE_SCOPE void	TclOOAddToInstances(Object *oPtr, Class *clsPtr);
MODULE_SCOPE void	TclOOAddToMixinSubs(Class *subPtr, Class *mixinPtr);
MODULE_SCOPE void	TclOOAddToSubclasses(Class *subPtr, Class *superPtr);
MODULE_SCOPE Class *	TclOOAllocClass(Tcl_Interp *interp,
			    Object *useThisObj);
MODULE_SCOPE int	TclMethodIsType(Tcl_Method method,
			    const Tcl_MethodType *typePtr,
			    void **clientDataPtr);
MODULE_SCOPE Tcl_Method TclNewInstanceMethod(Tcl_Interp *interp,
			    Tcl_Object object, Tcl_Obj *nameObj,
			    int flags, const Tcl_MethodType *typePtr,
			    void *clientData);
MODULE_SCOPE Tcl_Method TclNewMethod(Tcl_Class cls,
			    Tcl_Obj *nameObj, int flags,
			    const Tcl_MethodType *typePtr,
			    void *clientData);
MODULE_SCOPE int	TclNRNewObjectInstance(Tcl_Interp *interp,
			    Tcl_Class cls, const char *nameStr,
			    const char *nsNameStr, Tcl_Size objc,
			    Tcl_Obj *const *objv, Tcl_Size skip,
			    Tcl_Object *objectPtr);
MODULE_SCOPE Object *	TclNewObjectInstanceCommon(Tcl_Interp *interp,
			    Class *classPtr,
			    const char *nameStr,
			    const char *nsNameStr);
MODULE_SCOPE int	TclOODecrRefCount(Object *oPtr);
MODULE_SCOPE int	TclOOObjectDestroyed(Object *oPtr);
MODULE_SCOPE int	TclOODefineSlots(Foundation *fPtr);
MODULE_SCOPE void	TclOODeleteChain(CallChain *callPtr);
MODULE_SCOPE void	TclOODeleteChainCache(Tcl_HashTable *tablePtr);
MODULE_SCOPE void	TclOODeleteContext(CallContext *contextPtr);
MODULE_SCOPE void	TclOODeleteDescendants(Tcl_Interp *interp,
			    Object *oPtr);
MODULE_SCOPE void	TclOODelMethodRef(Method *method);
MODULE_SCOPE int	TclOOExportMethods(Class *clsPtr, ...);
MODULE_SCOPE CallContext *TclOOGetCallContext(Object *oPtr,
			    Tcl_Obj *methodNameObj, int flags,
			    Object *contextObjPtr, Class *contextClsPtr,
			    Tcl_Obj *cacheInThisObj);
MODULE_SCOPE Class *	TclOOGetClassDefineCmdContext(Tcl_Interp *interp);
MODULE_SCOPE Class *	TclOOGetClassFromObj(Tcl_Interp *interp,
			    Tcl_Obj *objPtr);
MODULE_SCOPE Tcl_Namespace *TclOOGetDefineContextNamespace(
			    Tcl_Interp *interp, Object *oPtr, int forClass);
MODULE_SCOPE CallChain *TclOOGetStereotypeCallChain(Class *clsPtr,
			    Tcl_Obj *methodNameObj, int flags);
MODULE_SCOPE Foundation	*TclOOGetFoundation(Tcl_Interp *interp);
MODULE_SCOPE Tcl_Obj *	TclOOGetFwdFromMethod(Method *mPtr);
MODULE_SCOPE Proc *	TclOOGetProcFromMethod(Method *mPtr);
MODULE_SCOPE Tcl_Obj *	TclOOGetMethodBody(Method *mPtr);
MODULE_SCOPE size_t	TclOOGetSortedClassMethodList(Class *clsPtr,
			    int flags, const char ***stringsPtr);
MODULE_SCOPE int	TclOOGetSortedMethodList(Object *oPtr,
			    Object *contextObj, Class *contextCls, int flags,
			    const char ***stringsPtr);
MODULE_SCOPE int	TclOOInit(Tcl_Interp *interp);
MODULE_SCOPE void	TclOOInitInfo(Tcl_Interp *interp);
MODULE_SCOPE int	TclOOInvokeContext(void *clientData,
			    Tcl_Interp *interp, int objc,
			    Tcl_Obj *const objv[]);
MODULE_SCOPE Tcl_Var	TclOOLookupObjectVar(Tcl_Interp *interp,
			    Tcl_Object object, Tcl_Obj *varName,
			    Tcl_Var *aryPtr);
MODULE_SCOPE int	TclNRObjectContextInvokeNext(Tcl_Interp *interp,
			    Tcl_ObjectContext context, Tcl_Size objc,
			    Tcl_Obj *const *objv, Tcl_Size skip);
MODULE_SCOPE void	TclOODefineBasicMethods(Class *clsPtr,
			    const DeclaredClassMethod *dcm);
MODULE_SCOPE Tcl_Obj *	TclOOObjectName(Tcl_Interp *interp, Object *oPtr);
MODULE_SCOPE Tcl_Obj *	TclOOObjectMyName(Tcl_Interp *interp, Object *oPtr);
MODULE_SCOPE void	TclOOReleaseClassContents(Tcl_Interp *interp,
			    Object *oPtr);
MODULE_SCOPE int	TclOORemoveFromInstances(Object *oPtr, Class *clsPtr);
MODULE_SCOPE int	TclOORemoveFromMixins(Class *mixinPtr, Object *oPtr);
MODULE_SCOPE int	TclOORemoveFromMixinSubs(Class *subPtr,
			    Class *mixinPtr);
MODULE_SCOPE int	TclOORemoveFromSubclasses(Class *subPtr,
			    Class *superPtr);
MODULE_SCOPE Tcl_Obj *	TclOORenderCallChain(Tcl_Interp *interp,
			    CallChain *callPtr);
MODULE_SCOPE void	TclOOSetSuperclasses(Class *clsPtr, Tcl_Size superc,
			    Class **superclasses);
MODULE_SCOPE void	TclOOStashContext(Tcl_Obj *objPtr,
			    CallContext *contextPtr);
MODULE_SCOPE void	TclOOSetupVariableResolver(Tcl_Namespace *nsPtr);
MODULE_SCOPE int	TclOOUnexportMethods(Class *clsPtr, ...);
MODULE_SCOPE Tcl_Obj *	TclOOGetAllObjectProperties(Object *oPtr,
			    int writable);
MODULE_SCOPE Tcl_Obj *	TclOOGetPropertyList(PropertyList *propList);
MODULE_SCOPE void	TclOOReleasePropertyStorage(PropertyStorage *propsPtr);
MODULE_SCOPE void	TclOOInstallReadableProperties(PropertyStorage *props,
			    Tcl_Size objc, Tcl_Obj *const objv[]);
MODULE_SCOPE void	TclOOInstallWritableProperties(PropertyStorage *props,
			    Tcl_Size objc, Tcl_Obj *const objv[]);
MODULE_SCOPE int	TclOOInstallStdPropertyImpls(void *useInstance,
			    Tcl_Interp *interp, Tcl_Obj *propName,
			    int readable, int writable);
MODULE_SCOPE void	TclOORegisterProperty(Class *clsPtr,
			    Tcl_Obj *propName, int mayRead, int mayWrite);
MODULE_SCOPE void	TclOORegisterInstanceProperty(Object *oPtr,
			    Tcl_Obj *propName, int mayRead, int mayWrite);

/*
 * Include all the private API, generated from tclOO.decls.
 */

#include "tclOOIntDecls.h"  /* IWYU pragma: export */

/*
 * Alternatives to Tcl_Preserve/Tcl_EventuallyFree/Tcl_Release.
 */

#define AddRef(ptr) ((ptr)->refCount++)

/*
 * A convenience macro for iterating through the lists used in the internal
 * memory management of objects.
 * REQUIRES DECLARATION: Tcl_Size i;
 */

#define FOREACH(var,ary) \
    for(i=0 ; i<(ary).num; i++) if ((ary).list[i] == NULL) { \
	continue; \
    } else if ((var) = (ary).list[i], 1)

/*
 * A variation where the array is an array of structs. There's no issue with
 * possible NULLs; every element of the array will be iterated over and the
 * variable set to a pointer to each of those elements in turn.
 * REQUIRES DECLARATION: Tcl_Size i; See [96551aca55] for more FOREACH_STRUCT details.
 */

#define FOREACH_STRUCT(var,ary) \
    if (i=0, (ary).num>0) for(; var=&((ary).list[i]), i<(ary).num; i++)

/*
 * Convenience macros for iterating through hash tables. FOREACH_HASH_DECLS
 * sets up the declarations needed for the main macro, FOREACH_HASH, which
 * does the actual iteration. FOREACH_HASH_KEY and FOREACH_HASH_VALUE are
 * restricted versions that only iterate over keys or values respectively.
 * REQUIRES DECLARATION: FOREACH_HASH_DECLS;
 */

#define FOREACH_HASH_DECLS \
    Tcl_HashEntry *hPtr;Tcl_HashSearch search
#define FOREACH_HASH(key, val, tablePtr) \
    for(hPtr = Tcl_FirstHashEntry((tablePtr), &search); hPtr != NULL ? \
	    (*(void **)&(key) = Tcl_GetHashKey((tablePtr), hPtr), \
	    *(void **)&(val) = Tcl_GetHashValue(hPtr), 1) : 0; \
	    hPtr = Tcl_NextHashEntry(&search))
#define FOREACH_HASH_KEY(key, tablePtr) \
    for(hPtr = Tcl_FirstHashEntry((tablePtr), &search); hPtr != NULL ? \
	    (*(void **)&(key) = Tcl_GetHashKey((tablePtr), hPtr), 1) : 0; \
	    hPtr = Tcl_NextHashEntry(&search))
#define FOREACH_HASH_VALUE(val, tablePtr) \
    for(hPtr = Tcl_FirstHashEntry((tablePtr), &search); hPtr != NULL ? \
	    (*(void **)&(val) = Tcl_GetHashValue(hPtr), 1) : 0; \
	    hPtr = Tcl_NextHashEntry(&search))

/*
 * Convenience macro for duplicating a list. Needs no external declaration,
 * but all arguments are used multiple times and so must have no side effects.
 */

#undef DUPLICATE /* prevent possible conflict with definition in WINAPI nb30.h */
#define DUPLICATE(target,source,type) \
    do { \
	size_t len = sizeof(type) * ((target).num=(source).num);\
	if (len != 0) { \
	    memcpy(((target).list=(type*)Tcl_Alloc(len)), (source).list, len); \
	} else { \
	    (target).list = NULL; \
	} \
    } while(0)

/*
 * Convenience macro for generating error codes.
 */
#define OO_ERROR(interp, code) \
    Tcl_SetErrorCode((interp), "TCL", "OO", #code, (char *)NULL)

#endif /* TCL_OO_INTERNAL_H */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
