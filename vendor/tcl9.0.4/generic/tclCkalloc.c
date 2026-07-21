/*
 * tclCkalloc.c --
 *
 *    Interface to malloc and free that provides support for debugging
 *    problems involving overwritten, double freeing memory and loss of
 *    memory.
 *
 * Copyright © 1991-1994 The Regents of the University of California.
 * Copyright © 1994-1997 Sun Microsystems, Inc.
 * Copyright © 1998-1999 Scriptics Corporation.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * This code contributed by Karl Lehenbauer and Mark Diekhans
 */

#include "tclInt.h"

#define FALSE	0
#define TRUE	1

#undef Tcl_Alloc
#undef Tcl_Free
#undef Tcl_Realloc
#undef Tcl_AttemptAlloc
#undef Tcl_AttemptRealloc

#ifdef TCL_MEM_DEBUG

/*
 * One of the following structures is allocated each time the
 * "memory tag" command is invoked, to hold the current tag.
 */

typedef struct {
    size_t refCount;		/* Number of mem_headers referencing this
				 * tag. */
    char string[TCLFLEXARRAY];	/* Actual size of string will be as large as
				 * needed for actual tag. This must be the
				 * last field in the structure. */
} MemTag;

#define TAG_SIZE(bytesInString) ((offsetof(MemTag, string) + 1U) + (bytesInString))

static MemTag *curTagPtr = NULL;/* Tag to use in all future mem_headers (set
				 * by "memory tag" command). */

/*
 * One of the following structures is allocated just before each dynamically
 * allocated chunk of memory, both to record information about the chunk and
 * to help detect chunk under-runs.
 */

#define LOW_GUARD_SIZE (8 + (32 - (sizeof(size_t) + sizeof(int)))%8)
struct mem_header {
    struct mem_header *flink;
    struct mem_header *blink;
    MemTag *tagPtr;		/* Tag from "memory tag" command; may be
				 * NULL. */
    const char *file;
    size_t length;
    int line;
    unsigned char low_guard[LOW_GUARD_SIZE];
				/* Aligns body on 8-byte boundary, plus
				 * provides at least 8 additional guard bytes
				 * to detect underruns. */
    char body[TCLFLEXARRAY];	/* First byte of client's space. Actual size
				 * of this field will be larger than one. */
};

static struct mem_header *allocHead = NULL;  /* List of allocated structures */

#define GUARD_VALUE  0x61

/*
 * The following macro determines the amount of guard space *above* each chunk
 * of memory.
 */

#define HIGH_GUARD_SIZE 8

/*
 * The following macro computes the offset of the "body" field within
 * mem_header. It is used to get back to the header pointer from the body
 * pointer that's used by clients.
 */

#define BODY_OFFSET \
	((size_t) (&((struct mem_header *) 0)->body))

static size_t total_mallocs = 0;
static size_t total_frees = 0;
static size_t current_bytes_malloced = 0;
static size_t maximum_bytes_malloced = 0;
static size_t current_malloc_packets = 0;
static size_t  maximum_malloc_packets = 0;
static size_t break_on_malloc = 0;
static size_t trace_on_at_malloc = 0;
static int alloc_tracing = FALSE;
static int init_malloced_bodies = TRUE;
#ifdef MEM_VALIDATE
static int validate_memory = TRUE;
#else
static int validate_memory = FALSE;
#endif

/*
 * The following variable indicates to TclFinalizeMemorySubsystem() that it
 * should dump out the state of memory before exiting. If the value is
 * non-NULL, it gives the name of the file in which to dump memory usage
 * information.
 */

char *tclMemDumpFileName = NULL;

static char *onExitMemDumpFileName = NULL;
static char dumpFile[100];	/* Records where to dump memory allocation
				 * information. */

/*
 * Mutex to serialize allocations. This is a low-level mutex that must be
 * explicitly initialized. This is necessary because the self initializing
 * mutexes use Tcl_Alloc...
 */

static Tcl_Mutex *ckallocMutexPtr;
static int ckallocInit = 0;

/*
 *----------------------------------------------------------------------
 *
 * TclInitDbCkalloc --
 *
 *	Initialize the locks used by the allocator. This is only appropriate
 *	to call in a single threaded environment, such as during
 *	Tcl_InitSubsystems.
 *
 *----------------------------------------------------------------------
 */

void
TclInitDbCkalloc(void)
{
    if (!ckallocInit) {
	ckallocInit = 1;
	ckallocMutexPtr = Tcl_GetAllocMutex();
#if !TCL_THREADS
	/* Silence compiler warning */
	(void)ckallocMutexPtr;
#endif
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclDumpMemoryInfo --
 *
 *	Display the global memory management statistics.
 *
 *----------------------------------------------------------------------
 */

int
TclDumpMemoryInfo(
    void *clientData,
    int flags)
{
    char buf[1024];

    if (clientData == NULL) {
	return 0;
    }
    snprintf(buf, sizeof(buf),
	    "total mallocs             %10" TCL_Z_MODIFIER "u\n"
	    "total frees               %10" TCL_Z_MODIFIER "u\n"
	    "current packets allocated %10" TCL_Z_MODIFIER "u\n"
	    "current bytes allocated   %10" TCL_Z_MODIFIER "u\n"
	    "maximum packets allocated %10" TCL_Z_MODIFIER "u\n"
	    "maximum bytes allocated   %10" TCL_Z_MODIFIER "u\n",
	    total_mallocs,
	    total_frees,
	    current_malloc_packets,
	    current_bytes_malloced,
	    maximum_malloc_packets,
	    maximum_bytes_malloced);
    if (flags == 0) {
	fprintf((FILE *)clientData, "%s", buf);
    } else {
	/* Assume objPtr to append to */
	Tcl_AppendToObj((Tcl_Obj *) clientData, buf, -1);
    }
    return 1;
}

/*
 *----------------------------------------------------------------------
 *
 * ValidateMemory --
 *
 *	Validate memory guard zones for a particular chunk of allocated
 *	memory.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Prints validation information about the allocated memory to stderr.
 *
 *----------------------------------------------------------------------
 */

static void
ValidateMemory(
    struct mem_header *memHeaderP,
				/* Memory chunk to validate */
    const char *file,		/* File containing the call to
				 * Tcl_ValidateAllMemory */
    int line,			/* Line number of call to
				 * Tcl_ValidateAllMemory */
    int nukeGuards)		/* If non-zero, indicates that the memory
				 * guards are to be reset to 0 after they have
				 * been printed */
{
    unsigned char *hiPtr;
    size_t idx;
    int guard_failed = FALSE;
    int byte;

    for (idx = 0; idx < LOW_GUARD_SIZE; idx++) {
	byte = *(memHeaderP->low_guard + idx);
	if (byte != GUARD_VALUE) {
	    guard_failed = TRUE;
	    fflush(stdout);
	    byte &= 0xFF;
	    fprintf(stderr, "low guard byte %" TCL_Z_MODIFIER "u is 0x%x  \t%c\n", idx, byte,
		    (isprint(UCHAR(byte)) ? byte : ' ')); /* INTL: bytes */
	}
    }
    if (guard_failed) {
	TclDumpMemoryInfo(stderr, 0);
	fprintf(stderr, "low guard failed at %p, %s %d\n",
		memHeaderP->body, file, line);
	fflush(stderr);			/* In case name pointer is bad. */
	fprintf(stderr, "%" TCL_Z_MODIFIER "u bytes allocated at (%s %d)\n", memHeaderP->length,
		memHeaderP->file, memHeaderP->line);
	Tcl_Panic("Memory validation failure");
    }

    hiPtr = (unsigned char *)memHeaderP->body + memHeaderP->length;
    for (idx = 0; idx < HIGH_GUARD_SIZE; idx++) {
	byte = hiPtr[idx];
	if (byte != GUARD_VALUE) {
	    guard_failed = TRUE;
	    fflush(stdout);
	    byte &= 0xFF;
	    fprintf(stderr, "hi guard byte %" TCL_Z_MODIFIER "u is 0x%x  \t%c\n", idx, byte,
		    (isprint(UCHAR(byte)) ? byte : ' ')); /* INTL: bytes */
	}
    }

    if (guard_failed) {
	TclDumpMemoryInfo(stderr, 0);
	fprintf(stderr, "high guard failed at %p, %s %d\n",
		memHeaderP->body, file, line);
	fflush(stderr);			/* In case name pointer is bad. */
	fprintf(stderr, "%" TCL_Z_MODIFIER "u bytes allocated at (%s %d)\n",
		memHeaderP->length, memHeaderP->file,
		memHeaderP->line);
	Tcl_Panic("Memory validation failure");
    }

    if (nukeGuards) {
	memset(memHeaderP->low_guard, 0, LOW_GUARD_SIZE);
	memset(hiPtr, 0, HIGH_GUARD_SIZE);
    }

}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ValidateAllMemory --
 *
 *	Validate memory guard regions for all allocated memory.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Displays memory validation information to stderr.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_ValidateAllMemory(
    const char *file,		/* File from which Tcl_ValidateAllMemory was
				 * called. */
    int line)			/* Line number of call to
				 * Tcl_ValidateAllMemory */
{
    struct mem_header *memScanP;

    if (!ckallocInit) {
	TclInitDbCkalloc();
    }
    Tcl_MutexLock(ckallocMutexPtr);
    for (memScanP = allocHead; memScanP != NULL; memScanP = memScanP->flink) {
	ValidateMemory(memScanP, file, line, FALSE);
    }
    Tcl_MutexUnlock(ckallocMutexPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DumpActiveMemory --
 *
 *	Displays all allocated memory to a file; if no filename is given,
 *	information will be written to stderr.
 *
 * Results:
 *	Return TCL_ERROR if an error accessing the file occurs, `errno' will
 *	have the file error number left in it.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_DumpActiveMemory(
    const char *fileName)	/* Name of the file to write info to */
{
    FILE *fileP;
    struct mem_header *memScanP;
    char *address;

    if (fileName == NULL) {
	fileP = stderr;
    } else {
	fileP = fopen(fileName, "w");
	if (fileP == NULL) {
	    return TCL_ERROR;
	}
    }

    Tcl_MutexLock(ckallocMutexPtr);
    for (memScanP = allocHead; memScanP != NULL; memScanP = memScanP->flink) {
	address = &memScanP->body[0];
	fprintf(fileP, "%p - %p  %" TCL_Z_MODIFIER "u @ %s %d %s",
		address, address + memScanP->length - 1,
		memScanP->length, memScanP->file, memScanP->line,
		(memScanP->tagPtr == NULL) ? "" : memScanP->tagPtr->string);
	(void) fputc('\n', fileP);
    }
    Tcl_MutexUnlock(ckallocMutexPtr);

    if (fileP != stderr) {
	fclose(fileP);
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DbCkalloc - debugging Tcl_Alloc
 *
 *	Allocate the requested amount of space plus some extra for guard bands
 *	at both ends of the request, plus a size, panicking if there isn't
 *	enough space, then write in the guard bands and return the address of
 *	the space in the middle that the user asked for.
 *
 *	The second and third arguments are file and line, these contain the
 *	filename and line number corresponding to the caller. These are sent
 *	by the Tcl_Alloc macro; it uses the preprocessor autodefines __FILE__
 *	and __LINE__.
 *
 *----------------------------------------------------------------------
 */

void *
Tcl_DbCkalloc(
    size_t size,
    const char *file,
    int line)
{
    struct mem_header *result = NULL;

    if (validate_memory) {
	Tcl_ValidateAllMemory(file, line);
    }

    /* Don't let size argument to TclpAlloc overflow */
    if (size <= (size_t)-2 - offsetof(struct mem_header, body) - HIGH_GUARD_SIZE) {
	result = (struct mem_header *) TclpAlloc(size +
		offsetof(struct mem_header, body) + 1U + HIGH_GUARD_SIZE);
    }
    if (result == NULL) {
	fflush(stdout);
	TclDumpMemoryInfo(stderr, 0);
	Tcl_Panic("unable to alloc %" TCL_Z_MODIFIER "u bytes, %s line %d", size, file, line);
    }

    /*
     * Fill in guard zones and size. Also initialize the contents of the block
     * with bogus bytes to detect uses of initialized data. Link into
     * allocated list.
     */

    if (init_malloced_bodies) {
	memset(result, GUARD_VALUE,
		offsetof(struct mem_header, body) + 1U + HIGH_GUARD_SIZE + size);
    } else {
	memset(result->low_guard, GUARD_VALUE, LOW_GUARD_SIZE);
	memset(result->body + size, GUARD_VALUE, HIGH_GUARD_SIZE);
    }
    if (!ckallocInit) {
	TclInitDbCkalloc();
    }
    Tcl_MutexLock(ckallocMutexPtr);
    result->length = size;
    result->tagPtr = curTagPtr;
    if (curTagPtr != NULL) {
	curTagPtr->refCount++;
    }
    result->file = file;
    result->line = line;
    result->flink = allocHead;
    result->blink = NULL;

    if (allocHead != NULL) {
	allocHead->blink = result;
    }
    allocHead = result;

    total_mallocs++;
    if (trace_on_at_malloc && (total_mallocs >= trace_on_at_malloc)) {
	(void) fflush(stdout);
	fprintf(stderr, "reached malloc trace enable point (%" TCL_Z_MODIFIER "u)\n",
		total_mallocs);
	fflush(stderr);
	alloc_tracing = TRUE;
	trace_on_at_malloc = 0;
    }

    if (alloc_tracing) {
	fprintf(stderr,"Tcl_Alloc %p %" TCL_Z_MODIFIER "u %s %d\n",
		result->body, size, file, line);
    }

    if (break_on_malloc && (total_mallocs >= break_on_malloc)) {
	break_on_malloc = 0;
	(void) fflush(stdout);
	Tcl_Panic("reached malloc break limit (%" TCL_Z_MODIFIER "u)", total_mallocs);
    }

    current_malloc_packets++;
    if (current_malloc_packets > maximum_malloc_packets) {
	maximum_malloc_packets = current_malloc_packets;
    }
    current_bytes_malloced += size;
    if (current_bytes_malloced > maximum_bytes_malloced) {
	maximum_bytes_malloced = current_bytes_malloced;
    }

    Tcl_MutexUnlock(ckallocMutexPtr);

    return result->body;
}

void *
Tcl_AttemptDbCkalloc(
    size_t size,
    const char *file,
    int line)
{
    struct mem_header *result = NULL;

    if (validate_memory) {
	Tcl_ValidateAllMemory(file, line);
    }

    /* Don't let size argument to TclpAlloc overflow */
    if (size <= (size_t)-2 - offsetof(struct mem_header, body) - HIGH_GUARD_SIZE) {
	result = (struct mem_header *) TclpAlloc(size +
		offsetof(struct mem_header, body) + 1U + HIGH_GUARD_SIZE);
    }
    if (result == NULL) {
	fflush(stdout);
	TclDumpMemoryInfo(stderr, 0);
	return NULL;
    }

    /*
     * Fill in guard zones and size. Also initialize the contents of the block
     * with bogus bytes to detect uses of initialized data. Link into
     * allocated list.
     */
    if (init_malloced_bodies) {
	memset(result, GUARD_VALUE,
		offsetof(struct mem_header, body) + 1U + HIGH_GUARD_SIZE + size);
    } else {
	memset(result->low_guard, GUARD_VALUE, LOW_GUARD_SIZE);
	memset(result->body + size, GUARD_VALUE, HIGH_GUARD_SIZE);
    }
    if (!ckallocInit) {
	TclInitDbCkalloc();
    }
    Tcl_MutexLock(ckallocMutexPtr);
    result->length = size;
    result->tagPtr = curTagPtr;
    if (curTagPtr != NULL) {
	curTagPtr->refCount++;
    }
    result->file = file;
    result->line = line;
    result->flink = allocHead;
    result->blink = NULL;

    if (allocHead != NULL) {
	allocHead->blink = result;
    }
    allocHead = result;

    total_mallocs++;
    if (trace_on_at_malloc && (total_mallocs >= trace_on_at_malloc)) {
	(void) fflush(stdout);
	fprintf(stderr, "reached malloc trace enable point (%" TCL_Z_MODIFIER "u)\n",
		total_mallocs);
	fflush(stderr);
	alloc_tracing = TRUE;
	trace_on_at_malloc = 0;
    }

    if (alloc_tracing) {
	fprintf(stderr,"Tcl_Alloc %p %" TCL_Z_MODIFIER "u %s %d\n",
		result->body, size, file, line);
    }

    if (break_on_malloc && (total_mallocs >= break_on_malloc)) {
	break_on_malloc = 0;
	(void) fflush(stdout);
	Tcl_Panic("reached malloc break limit (%" TCL_Z_MODIFIER "u)", total_mallocs);
    }

    current_malloc_packets++;
    if (current_malloc_packets > maximum_malloc_packets) {
	maximum_malloc_packets = current_malloc_packets;
    }
    current_bytes_malloced += size;
    if (current_bytes_malloced > maximum_bytes_malloced) {
	maximum_bytes_malloced = current_bytes_malloced;
    }

    Tcl_MutexUnlock(ckallocMutexPtr);

    return result->body;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_DbCkfree - debugging Tcl_Free
 *
 *	Verify that the low and high guards are intact, and if so then free
 *	the buffer else Tcl_Panic.
 *
 *	The guards are erased after being checked to catch duplicate frees.
 *
 *	The second and third arguments are file and line, these contain the
 *	filename and line number corresponding to the caller. These are sent
 *	by the Tcl_Free macro; it uses the preprocessor autodefines __FILE__ and
 *	__LINE__.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_DbCkfree(
    void *ptr,
    const char *file,
    int line)
{
    struct mem_header *memp;

    if (ptr == NULL) {
	return;
    }

    /*
     * The following cast is *very* tricky. Must convert the pointer to an
     * integer before doing arithmetic on it, because otherwise the arithmetic
     * will be done differently (and incorrectly) on word-addressed machines
     * such as Crays (will subtract only bytes, even though BODY_OFFSET is in
     * words on these machines).
     */

    memp = (struct mem_header *) (((size_t) ptr) - BODY_OFFSET);

    if (alloc_tracing) {
	fprintf(stderr, "Tcl_Free %p %" TCL_Z_MODIFIER "u %s %d\n",
		memp->body, memp->length, file, line);
    }

    if (validate_memory) {
	Tcl_ValidateAllMemory(file, line);
    }

    Tcl_MutexLock(ckallocMutexPtr);
    ValidateMemory(memp, file, line, TRUE);
    if (init_malloced_bodies) {
	memset(ptr, GUARD_VALUE, memp->length);
    }

    total_frees++;
    current_malloc_packets--;
    current_bytes_malloced -= memp->length;

    if (memp->tagPtr != NULL) {
	if ((memp->tagPtr->refCount-- <= 1) && (curTagPtr != memp->tagPtr)) {
	    TclpFree(memp->tagPtr);
	}
    }

    /*
     * Delink from allocated list
     */

    if (memp->flink != NULL) {
	memp->flink->blink = memp->blink;
    }
    if (memp->blink != NULL) {
	memp->blink->flink = memp->flink;
    }
    if (allocHead == memp) {
	allocHead = memp->flink;
    }
    TclpFree(memp);
    Tcl_MutexUnlock(ckallocMutexPtr);
}

/*
 *--------------------------------------------------------------------
 *
 * Tcl_DbCkrealloc - debugging Tcl_Realloc
 *
 *	Reallocate a chunk of memory by allocating a new one of the right
 *	size, copying the old data to the new location, and then freeing the
 *	old memory space, using all the memory checking features of this
 *	package.
 *
 *--------------------------------------------------------------------
 */

void *
Tcl_DbCkrealloc(
    void *ptr,
    size_t size,
    const char *file,
    int line)
{
    char *newPtr;
    size_t copySize;
    struct mem_header *memp;

    if (ptr == NULL) {
	return Tcl_DbCkalloc(size, file, line);
    }

    /*
     * See comment from Tcl_DbCkfree before you change the following line.
     */

    memp = (struct mem_header *) (((size_t) ptr) - BODY_OFFSET);

    copySize = size;
    if (copySize > memp->length) {
	copySize = memp->length;
    }
    newPtr = (char *)Tcl_DbCkalloc(size, file, line);
    memcpy(newPtr, ptr, copySize);
    Tcl_DbCkfree(ptr, file, line);
    return newPtr;
}

void *
Tcl_AttemptDbCkrealloc(
    void *ptr,
    size_t size,
    const char *file,
    int line)
{
    char *newPtr;
    size_t copySize;
    struct mem_header *memp;

    if (ptr == NULL) {
	return Tcl_AttemptDbCkalloc(size, file, line);
    }

    /*
     * See comment from Tcl_DbCkfree before you change the following line.
     */

    memp = (struct mem_header *) (((size_t) ptr) - BODY_OFFSET);

    copySize = size;
    if (copySize > memp->length) {
	copySize = memp->length;
    }
    newPtr = (char *)Tcl_AttemptDbCkalloc(size, file, line);
    if (newPtr == NULL) {
	return NULL;
    }
    memcpy(newPtr, ptr, copySize);
    Tcl_DbCkfree(ptr, file, line);
    return newPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_Alloc, et al. --
 *
 *	These functions are defined in terms of the debugging versions when
 *	TCL_MEM_DEBUG is set.
 *
 * Results:
 *	Same as the debug versions.
 *
 * Side effects:
 *	Same as the debug versions.
 *
 *----------------------------------------------------------------------
 */

void *
Tcl_Alloc(
    size_t size)
{
    return Tcl_DbCkalloc(size, "unknown", 0);
}

void *
Tcl_AttemptAlloc(
    size_t size)
{
    return Tcl_AttemptDbCkalloc(size, "unknown", 0);
}

void
Tcl_Free(
    void *ptr)
{
    Tcl_DbCkfree(ptr, "unknown", 0);
}

void *
Tcl_Realloc(
    void *ptr,
    size_t size)
{
    return Tcl_DbCkrealloc(ptr, size, "unknown", 0);
}
void *
Tcl_AttemptRealloc(
    void *ptr,
    size_t size)
{
    return Tcl_AttemptDbCkrealloc(ptr, size, "unknown", 0);
}

/*
 *----------------------------------------------------------------------
 *
 * MemoryCmd --
 *
 *	Implements the Tcl "memory" command, which provides Tcl-level control
 *	of Tcl memory debugging information.
 *		memory active $file
 *		memory break_on_malloc $count
 *		memory info
 *		memory init on|off
 *		memory onexit $file
 *		memory tag $string
 *		memory trace on|off
 *		memory trace_on_at_malloc $count
 *		memory validate on|off
 *
 * Results:
 *	Standard TCL results.
 *
 *----------------------------------------------------------------------
 */
static int
MemoryCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Obj values of arguments. */
{
    const char *fileName;
    FILE *fileP;
    Tcl_DString buffer;
    int result;
    size_t len;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "option [args..]");
	return TCL_ERROR;
    }

    if (strcmp(TclGetString(objv[1]), "active") == 0 || strcmp(TclGetString(objv[1]), "display") == 0) {
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "file");
	    return TCL_ERROR;
	}
	fileName = Tcl_TranslateFileName(interp, TclGetString(objv[2]), &buffer);
	if (fileName == NULL) {
	    return TCL_ERROR;
	}
	result = Tcl_DumpActiveMemory(fileName);
	Tcl_DStringFree(&buffer);
	if (result != TCL_OK) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf("error accessing %s: %s",
		    TclGetString(objv[2]), Tcl_PosixError(interp)));
	    return TCL_ERROR;
	}
	return TCL_OK;
    }
    if (strcmp(TclGetString(objv[1]),"break_on_malloc") == 0) {
	Tcl_WideInt value;
	if (objc != 3) {
	    goto argError;
	}
	if (TclGetWideIntFromObj(interp, objv[2], &value) != TCL_OK) {
	    return TCL_ERROR;
	}
	break_on_malloc = value;
	return TCL_OK;
    }
    if (strcmp(TclGetString(objv[1]),"info") == 0) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"%-25s %10" TCL_Z_MODIFIER "u\n%-25s %10" TCL_Z_MODIFIER "u\n%-25s %10" TCL_Z_MODIFIER "u\n%-25s %10" TCL_Z_MODIFIER "u\n%-25s %10" TCL_Z_MODIFIER "u\n%-25s %10" TCL_Z_MODIFIER "u\n",
		"total mallocs", total_mallocs, "total frees", total_frees,
		"current packets allocated", current_malloc_packets,
		"current bytes allocated", current_bytes_malloced,
		"maximum packets allocated", maximum_malloc_packets,
		"maximum bytes allocated", maximum_bytes_malloced));
	return TCL_OK;
    }
    if (strcmp(TclGetString(objv[1]), "init") == 0) {
	if (objc != 3) {
	    goto bad_suboption;
	}
	init_malloced_bodies = (strcmp(TclGetString(objv[2]),"on") == 0);
	return TCL_OK;
    }
    if (strcmp(TclGetString(objv[1]), "objs") == 0) {
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "file");
	    return TCL_ERROR;
	}
	fileName = Tcl_TranslateFileName(interp, TclGetString(objv[2]), &buffer);
	if (fileName == NULL) {
	    return TCL_ERROR;
	}
	fileP = fopen(fileName, "w");
	if (fileP == NULL) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "cannot open output file: %s",
		    Tcl_PosixError(interp)));
	    return TCL_ERROR;
	}
	TclDbDumpActiveObjects(fileP);
	fclose(fileP);
	Tcl_DStringFree(&buffer);
	return TCL_OK;
    }
    if (strcmp(TclGetString(objv[1]),"onexit") == 0) {
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "file");
	    return TCL_ERROR;
	}
	fileName = Tcl_TranslateFileName(interp, TclGetString(objv[2]), &buffer);
	if (fileName == NULL) {
	    return TCL_ERROR;
	}
	onExitMemDumpFileName = dumpFile;
	strcpy(onExitMemDumpFileName,fileName);
	Tcl_DStringFree(&buffer);
	return TCL_OK;
    }
    if (strcmp(TclGetString(objv[1]),"tag") == 0) {
	if (objc != 3) {
	    Tcl_WrongNumArgs(interp, 2, objv, "file");
	    return TCL_ERROR;
	}
	if ((curTagPtr != NULL) && (curTagPtr->refCount == 0)) {
	    TclpFree(curTagPtr);
	}
	len = strlen(TclGetString(objv[2]));
	curTagPtr = (MemTag *) TclpAlloc(TAG_SIZE(len));
	curTagPtr->refCount = 0;
	memcpy(curTagPtr->string, TclGetString(objv[2]), len + 1);
	return TCL_OK;
    }
    if (strcmp(TclGetString(objv[1]),"trace") == 0) {
	if (objc != 3) {
	    goto bad_suboption;
	}
	alloc_tracing = (strcmp(TclGetString(objv[2]),"on") == 0);
	return TCL_OK;
    }

    if (strcmp(TclGetString(objv[1]),"trace_on_at_malloc") == 0) {
	Tcl_WideInt value;
	if (objc != 3) {
	    goto argError;
	}
	if (TclGetWideIntFromObj(interp, objv[2], &value) != TCL_OK) {
	    return TCL_ERROR;
	}
	trace_on_at_malloc = value;
	return TCL_OK;
    }
    if (strcmp(TclGetString(objv[1]),"validate") == 0) {
	if (objc != 3) {
	    goto bad_suboption;
	}
	validate_memory = (strcmp(TclGetString(objv[2]),"on") == 0);
	return TCL_OK;
    }

    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "bad option \"%s\": should be active, break_on_malloc, info, "
	    "init, objs, onexit, tag, trace, trace_on_at_malloc, or validate",
	    TclGetString(objv[1])));
    return TCL_ERROR;

  argError:
    Tcl_WrongNumArgs(interp, 2, objv, "count");
    return TCL_ERROR;

  bad_suboption:
    Tcl_WrongNumArgs(interp, 2, objv, "on|off");
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * CheckmemCmd --
 *
 *	This is the command procedure for the "checkmem" command, which causes
 *	the application to exit after printing information about memory usage
 *	to the file passed to this command as its first argument.
 *
 * Results:
 *	Returns a standard Tcl completion code.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */
static int
CheckmemCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Interpreter for evaluation. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Obj values of arguments. */
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "fileName");
	return TCL_ERROR;
    }
    tclMemDumpFileName = dumpFile;
    strcpy(tclMemDumpFileName, TclGetString(objv[1]));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_InitMemory --
 *
 *	Create the "memory" and "checkmem" commands in the given interpreter.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	New commands are added to the interpreter.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_InitMemory(
    Tcl_Interp *interp)		/* Interpreter in which commands should be
				 * added */
{
    TclInitDbCkalloc();
    Tcl_CreateObjCommand(interp, "memory", MemoryCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "checkmem", CheckmemCmd, NULL, NULL);
}

#else	/* TCL_MEM_DEBUG */

/* This is the !TCL_MEM_DEBUG case */

#undef Tcl_InitMemory
#undef Tcl_DumpActiveMemory
#undef Tcl_ValidateAllMemory

/*
 *----------------------------------------------------------------------
 *
 * Tcl_Alloc --
 *
 *	Interface to TclpAlloc when TCL_MEM_DEBUG is disabled. It does check
 *	that memory was actually allocated.
 *
 *----------------------------------------------------------------------
 */

void *
Tcl_Alloc(
    size_t size)
{
    void *result = TclpAlloc(size);

    /*
     * Most systems will not alloc(0), instead bumping it to one so that NULL
     * isn't returned. Some systems (AIX, Tru64) will alloc(0) by returning
     * NULL, so we have to check that the NULL we get is not in response to
     * alloc(0).
     *
     * The ANSI spec actually says that systems either return NULL *or* a
     * special pointer on failure, but we only check for NULL
     */

    if ((result == NULL) && size) {
	Tcl_Panic("unable to alloc %" TCL_Z_MODIFIER "u bytes", size);
    }
    return result;
}

void *
Tcl_DbCkalloc(
    size_t size,
    const char *file,
    int line)
{
    void *result = TclpAlloc(size);

    if ((result == NULL) && size) {
	fflush(stdout);
	Tcl_Panic("unable to alloc %" TCL_Z_MODIFIER "u bytes, %s line %d",
		size, file, line);
    }
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_AttemptAlloc --
 *
 *	Interface to TclpAlloc when TCL_MEM_DEBUG is disabled. It does not
 *	check that memory was actually allocated.
 *
 *----------------------------------------------------------------------
 */

void *
Tcl_AttemptAlloc(
    size_t size)
{
    return (char *)TclpAlloc(size);
}

void *
Tcl_AttemptDbCkalloc(
    size_t size,
    TCL_UNUSED(const char *) /*file*/,
    TCL_UNUSED(int) /*line*/)
{
    return (char *)TclpAlloc(size);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_Realloc --
 *
 *	Interface to TclpRealloc when TCL_MEM_DEBUG is disabled. It does check
 *	that memory was actually allocated.
 *
 *----------------------------------------------------------------------
 */

void *
Tcl_Realloc(
    void *ptr,
    size_t size)
{
    void *result = TclpRealloc(ptr, size);

    if ((result == NULL) && size) {
	Tcl_Panic("unable to realloc %" TCL_Z_MODIFIER "u bytes", size);
    }
    return result;
}

void *
Tcl_DbCkrealloc(
    void *ptr,
    size_t size,
    const char *file,
    int line)
{
    void *result = TclpRealloc(ptr, size);

    if ((result == NULL) && size) {
	fflush(stdout);
	Tcl_Panic("unable to realloc %" TCL_Z_MODIFIER "u bytes, %s line %d",
		size, file, line);
    }
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_AttemptRealloc --
 *
 *	Interface to TclpRealloc when TCL_MEM_DEBUG is disabled. It does not
 *	check that memory was actually allocated.
 *
 *----------------------------------------------------------------------
 */

void *
Tcl_AttemptRealloc(
    void *ptr,
    size_t size)
{
    return (char *)TclpRealloc(ptr, size);
}

void *
Tcl_AttemptDbCkrealloc(
    void *ptr,
    size_t size,
    TCL_UNUSED(const char *) /*file*/,
    TCL_UNUSED(int) /*line*/)
{
    return (char *)TclpRealloc(ptr, size);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_Free --
 *
 *	Interface to TclpFree when TCL_MEM_DEBUG is disabled. Done here rather
 *	in the macro to keep some modules from being compiled with
 *	TCL_MEM_DEBUG enabled and some with it disabled.
 *
 *----------------------------------------------------------------------
 */

void
Tcl_Free(
    void *ptr)
{
    TclpFree(ptr);
}

void
Tcl_DbCkfree(
    void *ptr,
    TCL_UNUSED(const char *) /*file*/,
    TCL_UNUSED(int) /*line*/)
{
    TclpFree(ptr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_InitMemory --
 *
 *	Dummy initialization for memory command, which is only available if
 *	TCL_MEM_DEBUG is on.
 *
 *----------------------------------------------------------------------
 */
void
Tcl_InitMemory(
    TCL_UNUSED(Tcl_Interp *) /*interp*/)
{
}

int
Tcl_DumpActiveMemory(
    TCL_UNUSED(const char *) /*fileName*/)
{
    return TCL_OK;
}

void
Tcl_ValidateAllMemory(
    TCL_UNUSED(const char *) /*file*/,
    TCL_UNUSED(int) /*line*/)
{
}

int
TclDumpMemoryInfo(
    TCL_UNUSED(void *),
    TCL_UNUSED(int) /*flags*/)
{
    return 1;
}

#endif	/* TCL_MEM_DEBUG */

/*
 *------------------------------------------------------------------------
 *
 * TclAllocElemsEx --
 *
 *    See TclAttemptAllocElemsEx. This function differs in that it panics
 *    on failure.
 *
 * Results:
 *    Non-NULL pointer to allocated memory block.
 *
 * Side effects:
 *    Panics if memory of at least the requested size could not be
 *    allocated.
 *
 *------------------------------------------------------------------------
 */
void *
TclAllocElemsEx(
    Tcl_Size elemCount,		/* Allocation will store at least these many... */
    Tcl_Size elemSize,		/* ...elements of this size */
    Tcl_Size leadSize,		/* Additional leading space in bytes */
    Tcl_Size *capacityPtr)	/* OUTPUT: Actual capacity is stored here if
				 * non-NULL. Only modified on success */
{
    void *ptr = TclAttemptReallocElemsEx(
	NULL, elemCount, elemSize, leadSize, capacityPtr);
    if (ptr == NULL) {
	Tcl_Panic("Failed to allocate %" TCL_SIZE_MODIFIER
		  "d elements of size %" TCL_SIZE_MODIFIER "d bytes.",
		  elemCount,
		  elemSize);
    }
    return ptr;
}

/*
 *------------------------------------------------------------------------
 *
 * TclAttemptReallocElemsEx --
 *
 *    Attempts to allocate (oldPtr == NULL) or reallocate memory of the
 *    requested size plus some more for future growth. The amount of
 *    reallocation is adjusted depending on failure.
 *
 *
 * Results:
 *    Pointer to allocated memory block which is at least as large
 *    as the requested size or NULL if allocation failed.
 *
 *------------------------------------------------------------------------
 */
void *
TclAttemptReallocElemsEx(
    void *oldPtr,		/* Pointer to memory block to reallocate or
				 * NULL to indicate this is a new allocation */
    Tcl_Size elemCount,		/* Allocation will store at least these many... */
    Tcl_Size elemSize,		/* ...elements of this size */
    Tcl_Size leadSize,		/* Additional leading space in bytes */
    Tcl_Size *capacityPtr)	/* OUTPUT: Actual capacity is stored here if
				 * non-NULL. Only modified on success */
{
    void *ptr;
    Tcl_Size limit;
    Tcl_Size attempt;

    assert(elemCount > 0);
    assert(elemSize > 0);
    assert(elemSize < TCL_SIZE_MAX);
    assert(leadSize >= 0);
    assert(leadSize < TCL_SIZE_MAX);

    limit = (TCL_SIZE_MAX - leadSize) / elemSize;
    if (elemCount > limit) {
	return NULL;
    }
    /* Loop trying for extra space, reducing request each time */
    attempt = TclUpsizeAlloc(0, elemCount, limit);
    ptr = NULL;
    while (attempt > elemCount) {
	if (oldPtr) {
	    ptr = Tcl_AttemptRealloc(oldPtr, leadSize + attempt * elemSize);
	} else {
	    ptr = Tcl_AttemptAlloc(leadSize + attempt * elemSize);
	}
	if (ptr) {
	    break;
	}
	attempt = TclUpsizeRetry(elemCount, attempt);
    }
    /* Try exact size as a last resort */
    if (ptr == NULL) {
	attempt = elemCount;
	if (oldPtr) {
	    ptr = Tcl_AttemptRealloc(oldPtr, leadSize + attempt * elemSize);
	} else {
	    ptr = Tcl_AttemptAlloc(leadSize + attempt * elemSize);
	}
    }
    if (ptr && capacityPtr) {
	*capacityPtr = attempt;
    }
    return ptr;
}

/*
 *------------------------------------------------------------------------
 *
 * TclReallocElemsEx --
 *
 *    See TclAttemptReallocElemsEx. This function differs in that it panics
 *    on failure.
 *
 * Results:
 *    Non-NULL pointer to allocated memory block.
 *
 * Side effects:
 *    Panics if memory of at least the requested size could not be
 *    allocated.
 *
 *------------------------------------------------------------------------
 */
void *
TclReallocElemsEx(
    void *oldPtr,		/* Pointer to memory block to reallocate */
    Tcl_Size elemCount,		/* Allocation will store at least these many... */
    Tcl_Size elemSize,		/* ...elements of this size */
    Tcl_Size leadSize,		/* Additional leading space in bytes */
    Tcl_Size *capacityPtr)	/* OUTPUT: Actual capacity is stored here if
				 * non-NULL. Only modified on success */
{
    void *ptr = TclAttemptReallocElemsEx(
	oldPtr, elemCount, elemSize, leadSize, capacityPtr);
    if (ptr == NULL) {
	Tcl_Panic("Failed to reallocate %" TCL_SIZE_MODIFIER
		  "d elements of size %" TCL_SIZE_MODIFIER "d bytes.",
		  elemCount,
		  elemSize);
    }
    return ptr;
}

/*
 *---------------------------------------------------------------------------
 *
 * TclFinalizeMemorySubsystem --
 *
 *	This procedure is called to finalize all the structures that are used
 *	by the memory allocator on a per-process basis.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	This subsystem is self-initializing, since memory can be allocated
 *	before Tcl is formally initialized. After this call, this subsystem
 *	has been reset to its initial state and is usable again.
 *
 *---------------------------------------------------------------------------
 */

void
TclFinalizeMemorySubsystem(void)
{
#ifdef TCL_MEM_DEBUG
    if (tclMemDumpFileName != NULL) {
	Tcl_DumpActiveMemory(tclMemDumpFileName);
    } else if (onExitMemDumpFileName != NULL) {
	Tcl_DumpActiveMemory(onExitMemDumpFileName);
    }

    Tcl_MutexLock(ckallocMutexPtr);

    if (curTagPtr != NULL) {
	TclpFree(curTagPtr);
	curTagPtr = NULL;
    }
    allocHead = NULL;

    Tcl_MutexUnlock(ckallocMutexPtr);
#endif

#if defined(USE_TCLALLOC) && USE_TCLALLOC
    TclFinalizeAllocSubsystem();
#endif
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * tab-width: 8
 * indent-tabs-mode: nil
 * End:
 */
