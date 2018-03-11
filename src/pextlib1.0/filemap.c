/*
 * filemap.c
 *
 * Copyright (c) 2004 Paul Guyot, The MacPorts Project.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of MacPorts Team nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

/* needed for NAME_MAX and PATH_MAX on Linux */
#define _XOPEN_SOURCE

#include <sys/stat.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

#include <tcl.h>

#include "filemap.h"

/* ========================================================================= **
 * Definitions
 * ========================================================================= */

/* ------------------------------------------------------------------------- **
 * Internal structures
 * ------------------------------------------------------------------------- */
/* For the moment, we represent the map as a simple tree. */

/** Constants saying whether a node is a leaf or not */
typedef enum {
	kNode,
	kLeaf
} ENodeType;

/**
 * Structure for the header of a node.
 */
typedef struct {
	/** Kind for this node */
	ENodeType		fNodeType;
	/** Name of the directory or of the file.
	 The root has an empty string there. */
	char			fKeySubpart[NAME_MAX+1];
} SHeader;

/**
 * Structure for a node with subnode (i.e. a directory node).
 */
typedef struct {
	/** Header common to nodes and leaves */
	SHeader			fHeader;
	/** Number of subnodes */
	unsigned int	fSubnodesCount;
	/** Array of subnodes */
	SHeader*		fSubnodes[1];
} SNode;

/**
 * Structure for a leaf (i.e. a file node).
 */
typedef struct {
	/** Header common to nodes and leaves */
	SHeader			fHeader;
	/** Value, i.e. port name */
	char			fValue[NAME_MAX+1];
} SLeaf;

/**
 * Structure for the internal representation of filemaps.
 * We don't allow deep clones hence we're refcounting.
 */
typedef struct {
	/** Ref count */
	unsigned int fRefCount;
	/** Path to the database file. */
	char	fFilemapPath[PATH_MAX];
	/** File descriptor on lock. */
	int 	fLockFD;
	/** Root of the filemap */
	SNode*	fRoot;
	/** If the filemap is read only */
	char	fIsReadOnly;
	/** If the filemap was changed */
	char	fIsDirty;
	/** If the filemap is RAM only (in which case fFilemapPath is just
	    garbage) */
	char	fIsRAMOnly;
} SFilemapObject;

/** Error codes */
enum {
	kSignatureMismatch_Err		= -100000,
	kUnknownVersion_Err			= -100001,
	kKeyNotFound_Err			= -100002,
	kUnknownNodeKind_Err		= -100003,
	kNameTooLong_Err			= -100004,
	kEOFWhileLoadingDB_Err		= -100005,
	kUnknownOption_Err			= -100006
};

/* Constants relative to the storage format. */
/** Signature at the beginning of filemap in files */
static const char kFilemapSignature[24] = "org.darwinports.filemap";
/** Version */
static const char kFilemapVersion[4] = { 0x0, 0x1, 0x0, 0x0 };

/* ------------------------------------------------------------------------- **
 * Prototypes
 * ------------------------------------------------------------------------- */
int Load(const char* inDatabasePath, SNode** outTree);
void Create(SNode** outTree);
int LoadNode(
		char** const ioDatabaseBuffer,
		SHeader** outNode, ssize_t* ioBytesLeft);
int Save(const char* inDatabasePath, SNode* inTree);
int SaveNode(int inDatabaseFd, SHeader* inNode);
void Free(SNode** ioRoot);
int Set(SNode** ioRoot, const char* inPath, const char* inValue);
const char* Get(SNode* inRoot, const char* inPath);
Tcl_Obj* List(SNode* inRoot, const char* inValue);
void ListSubtree(
		SHeader* inRoot, const char* inValue,
		Tcl_Obj* outList, const char* inSubpath,
		unsigned int inSubpathLen);
int Delete(SNode** ioRoot, const char* inPath);
void FreeFilemapInternalRep(Tcl_Obj* inObjPtr);
void DupFilemapInternalRep(Tcl_Obj* inSrcPtr, Tcl_Obj* inDupPtr);
void UpdateStringOfFilemap(Tcl_Obj* inObjPtr);
int SetFilemapFromAny(Tcl_Interp* inInterp, Tcl_Obj* inObjPtr);
int SetResultFromErrorCode(Tcl_Interp* interp, int inErrorCode);
SFilemapObject* GetObjectFromVarName(Tcl_Interp* interp, Tcl_Obj* inVarName);
int FilemapCloseCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int FilemapCreateCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int FilemapExistsCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int FilemapGetCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int FilemapIsReadOnlyCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int FilemapListCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int FilemapOpenCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int FilemapRevertCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int FilemapSaveCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int FilemapSetCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);
int FilemapUnsetCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);

/* ------------------------------------------------------------------------- **
 * ObjType definition
 * ------------------------------------------------------------------------- */
Tcl_ObjType tclFilemapType = {
	"org.opendarwin.filemap",
	FreeFilemapInternalRep,
	DupFilemapInternalRep,
	UpdateStringOfFilemap,
	SetFilemapFromAny
};

/* ========================================================================= **
 * Tree access functions
 * ========================================================================= */

/**
 * Load the database from a file.
 * This function reads the whole file into a buffer, checks the header and then
 * calls LoadNode.
 *
 * @param inDatabasePath	path to the database file.
 * @param outTree			on output, tree in memory
 */
int
Load(
		const char* inDatabasePath,
		SNode** outTree)
{
	int theErr = 0;
	char* theFileBuffer = NULL;
	int theFD = -1;
	
	do {
		struct stat theFileInfo;
		char* theFileCursor;
		ssize_t theFileSize;

		/* Open the file for reading, creating it if necessary. */
		theFD = open(inDatabasePath, O_RDONLY | O_CREAT, 0664);
		if (theFD < 0)
		{
			theErr = errno;
			break;
		}

		/* if the file is empty (i.e. we just created it), just return an empty root */
		if (fstat(theFD, &theFileInfo) < 0)
		{
			theErr = errno;
			break;
		}
		
		theFileSize = theFileInfo.st_size;
		if (theFileSize == 0)
		{
			SNode* theRoot = (SNode*) ckalloc(sizeof(SNode) - sizeof(SHeader*));
			theRoot->fSubnodesCount = 0;
			theRoot->fHeader.fNodeType = kNode;
			theRoot->fHeader.fKeySubpart[0] = '\0';
			*outTree = theRoot;
			break;
		}
		
		if (theFileSize < (ssize_t) (sizeof(kFilemapSignature) + sizeof(kFilemapVersion)))
		{
			theErr = kUnknownVersion_Err;
			break;
		}
		
		/* allocate a buffer to put the whole file.
			(note: the tree itself is just as big as the file) */
		theFileBuffer = (char*) ckalloc(theFileSize);
		
		/* read the whole file */
		if (read(theFD, theFileBuffer, theFileSize) != theFileSize)
		{
			theErr = errno;
			break;
		}
		
		/* check the signature */
		if (memcmp(theFileBuffer, kFilemapSignature, sizeof(kFilemapSignature)) != 0)
		{
			theErr = kSignatureMismatch_Err;
			break;
		}
		
		theFileCursor = theFileBuffer;
		theFileCursor += sizeof(kFilemapSignature);
		theFileSize -= sizeof(kFilemapSignature);
		
		/* check the version */
		if (memcmp(theFileCursor, kFilemapVersion, sizeof(kFilemapVersion)) != 0)
		{
			theErr = kUnknownVersion_Err;
			break;
		}
		
		theFileCursor += sizeof(kFilemapVersion);
		theFileSize -= sizeof(kFilemapVersion);
		
		/* load the tree recursively */
		theErr = LoadNode(&theFileCursor, (SHeader**) outTree, &theFileSize);
	} while (0);

	if (theFileBuffer)
	{
		ckfree(theFileBuffer);
	}

	/* close the file if required */
	if (theFD >= 0)
	{
		(void) close(theFD);
	}

	return theErr;
}

/**
 * Create an empty tree in RAM.
 *
 * @param outTree			on output, tree in memory
 */
void
Create(
		SNode** outTree)
{
	SNode* theRoot = (SNode*) ckalloc(sizeof(SNode) - sizeof(SHeader*));
	theRoot->fSubnodesCount = 0;
	theRoot->fHeader.fNodeType = kNode;
	theRoot->fHeader.fKeySubpart[0] = '\0';
	*outTree = theRoot;
}

/**
 * Recursive function to load the database from a buffer.
 *
 * @param ioDatabaseBuffer	pointer to the buffer (where the node starts),
 *							updated by this function.
 * @param outNode			on output, a tree in memory.
 * @param ioBytesLeft		number of bytes remaining in the buffer (updated
 *							by this function).
 */
int
LoadNode(
		char** const ioDatabaseBuffer,
		SHeader** outNode,
		ssize_t* ioBytesLeft)
{
	int theErr = 0;
	char* theDatabaseBuffer = *ioDatabaseBuffer;
	ssize_t theBytesLeft = *ioBytesLeft;

	do {
		char theKind;
		unsigned int theKeySubpartSize;

		/* get the kind (it's one byte) */
		if (theBytesLeft == 0)
		{
			theErr = kEOFWhileLoadingDB_Err;
			break;
		}
		theBytesLeft--;
		theKind = *theDatabaseBuffer++;
		
		if ((theKind != kLeaf) && (theKind != kNode))
		{
			theErr = kUnknownNodeKind_Err;
			break;
		}

		/* get the key subpart size (it's a null terminated string) */
		theKeySubpartSize = strlen(theDatabaseBuffer);
		if (theKeySubpartSize > NAME_MAX)
		{
			theErr = kNameTooLong_Err;
			break;
		}
		if (theKeySubpartSize > (unsigned int) theBytesLeft)
		{
			/* it's not very good to have overrun the buffer. OTOH, we're just reading ... */
			theErr = kEOFWhileLoadingDB_Err;
			break;
		}
		theBytesLeft -= theKeySubpartSize;

		if (theKind == kLeaf)
		{
			SLeaf* theLeaf;
			unsigned int theValueSize;

			/* create the leaf */
			theLeaf = (SLeaf*) ckalloc(sizeof(SLeaf));
			
			theLeaf->fHeader.fNodeType = kLeaf;
			
			/* copy the key */
			(void) memcpy(
					theLeaf->fHeader.fKeySubpart,
					theDatabaseBuffer,
					theKeySubpartSize + 1);
			theDatabaseBuffer += theKeySubpartSize + 1;
			
			/* get the value size */
			theValueSize = strlen(theDatabaseBuffer);
			if (theValueSize > NAME_MAX)
			{
				theErr = kNameTooLong_Err;
				break;
			}
			if (theValueSize > (unsigned int) theBytesLeft)
			{
				theErr = kEOFWhileLoadingDB_Err;
				break;
			}
			theBytesLeft -= theValueSize;
			
			/* copy the value */
			(void) memcpy(
					theLeaf->fValue,
					(const char*) theDatabaseBuffer,
					theValueSize + 1);
			theDatabaseBuffer += theValueSize + 1;
			
			*outNode = (SHeader*) theLeaf;
		} else {
			/* it's a node */
			char* theKeysubpartPointer = theDatabaseBuffer;
			
			unsigned int subnodesCount;
			SNode* theNode;
			SHeader** theNodeCursor;
			unsigned int indexSubnodes;

			/* skip to the number of nodes */
			theDatabaseBuffer += theKeySubpartSize + 1;
			
			/* get the number of nodes, it's a 4 bytes integer */
			if (theBytesLeft < 4)
			{
				theErr = kEOFWhileLoadingDB_Err;
				break;
			}
			subnodesCount =
					(((unsigned char) theDatabaseBuffer[0]) << 24)
				|	(((unsigned char) theDatabaseBuffer[1]) << 16)
				|	(((unsigned char) theDatabaseBuffer[2]) << 8)
				|	(((unsigned char) theDatabaseBuffer[3]));
		
			theDatabaseBuffer += 4;
			theBytesLeft -= 4;
			
			/* create the node */
			theNode = (SNode*) ckalloc(
				sizeof(SNode) + (subnodesCount - 1) * sizeof(SHeader*));
			
			theNode->fHeader.fNodeType = kNode;

			/* copy the key */
			(void) memcpy(
					theNode->fHeader.fKeySubpart,
					theKeysubpartPointer,
					theKeySubpartSize + 1);
			
			/* process the subnodes */
			theNode->fSubnodesCount = subnodesCount;
			theNodeCursor = theNode->fSubnodes;

			/* call us recursively. */
			for (indexSubnodes = 0; indexSubnodes < subnodesCount; indexSubnodes++)
			{
				theErr = LoadNode(&theDatabaseBuffer, theNodeCursor, &theBytesLeft);
				if (theErr != 0)
				{
					break;
				}
				theNodeCursor++;
			}

			*outNode = (SHeader*) theNode;
		}
	} while (0);
	
	*ioDatabaseBuffer = theDatabaseBuffer;
	*ioBytesLeft = theBytesLeft;
	
	return theErr;
}

/**
 * Save the database to the file.
 * This function saves the header and then calls SaveNode.
 *
 * @param inDatabasePath	file descriptor of the open file (the cursor is reset)
 * @param inTree			tree of the database.
 */
int
Save(
		const char* inDatabasePath,
		SNode* inTree)
{
	int theErr = 0;
	int theFD = -1;
	char theTempFilePath[PATH_MAX];
	
	do {
		/* Create the temporary file */
		theTempFilePath[sizeof(theTempFilePath) - 1] = 0;
		(void) snprintf(
			theTempFilePath,
			sizeof(theTempFilePath) - 1,
			"%s.w",
			inDatabasePath);

		/* Create it. */
		theFD = open(theTempFilePath, O_WRONLY | O_CREAT | O_TRUNC, 0664);
		if (theFD < 0)
		{
			theErr = errno;
			break;
		}
		
		/* Write the signature */
		if (write(theFD, kFilemapSignature, sizeof(kFilemapSignature))
				!= sizeof(kFilemapSignature))
		{
			theErr = errno;
			break;
		}
		
		/* Write the version */
		if (write(theFD, kFilemapVersion, sizeof(kFilemapVersion))
				!= sizeof(kFilemapVersion))
		{
			theErr = errno;
			break;
		}
		
		/* then, write, recursively, the tree */
		theErr = SaveNode(theFD, (SHeader*) inTree);
		if (theErr != 0)
		{
			break;
		}
		
		/* Close the file */
		(void) close(theFD);
		theFD = -1;
		
		/* Atomically swap the temporary file with the new copy */
		if (rename(theTempFilePath, inDatabasePath) < 0)
		{
			theErr = errno;
			break;
		}
	} while (0);
	
	/* close the copy if required */
	if (theFD >= 0)
	{
		(void) close(theFD);
	}

	return theErr;
}

/**
 * Recursive function to save the database to a file.
 *
 * @param inDatabaseFd	file descriptor of the open file.
 * @param inNode		node to save.
 */
int
SaveNode(
		int inDatabaseFd,
		SHeader* inNode)
{
	int theErr = 0;
	
	do {
		char theKind = inNode->fNodeType;
		int theKeySize = strlen(inNode->fKeySubpart) + 1;

		/* write the kind */
		if (write(inDatabaseFd, &theKind, sizeof(theKind)) != sizeof(theKind))
		{
			theErr = errno;
			break;
		}
		
		/* write the key */
		if (write(inDatabaseFd, inNode->fKeySubpart, theKeySize) != theKeySize)
		{
			theErr = errno;
			break;
		}
		
		if (theKind == kLeaf)
		{
			/* it's a leaf */
			SLeaf* theLeaf = (SLeaf*) inNode;
			int theValueSize = strlen(theLeaf->fValue) + 1;

			if (write(inDatabaseFd, theLeaf->fValue, theValueSize) != theValueSize)
			{
				theErr = errno;
				break;
			}
		} else {
			/* it's a node */
			SNode* theNode = (SNode*) inNode;
			unsigned int theSubnodesCount = theNode->fSubnodesCount;
			SHeader** theSubnodeCursor = theNode->fSubnodes;
			unsigned char theSubnodesCountAsBytes[4];
			unsigned int indexSubnodes;
			
			theSubnodesCountAsBytes[0] = (theSubnodesCount >> 24) & 0xFF;
			theSubnodesCountAsBytes[1] = (theSubnodesCount >> 16) & 0xFF;
			theSubnodesCountAsBytes[2] = (theSubnodesCount >> 8) & 0xFF;
			theSubnodesCountAsBytes[3] = theSubnodesCount & 0xFF;
			
			if (write(inDatabaseFd, theSubnodesCountAsBytes, sizeof(theSubnodesCountAsBytes))
				!= sizeof(theSubnodesCountAsBytes))
			{
				theErr = errno;
				break;
			}
			
			/* iterate on the subnodes */
			for (indexSubnodes = 0; indexSubnodes < theSubnodesCount; indexSubnodes++)
			{
				theErr = SaveNode(inDatabaseFd, *theSubnodeCursor);
				if (theErr != 0)
				{
					break;
				}
				
				theSubnodeCursor++;
			}
		}
	} while (0);
	
	return theErr;
}

/**
 * Recursive function to dispose the tree.
 *
 * @param ioRoot		on input, the tree to free, on output, 0L
 */
void
Free(SNode** ioRoot)
{
	SNode* theRoot = *ioRoot;
	if (theRoot != 0)
	{
		SHeader** theSubnodeCursor = theRoot->fSubnodes;
		unsigned int nbSubnodes = theRoot->fSubnodesCount;
		SHeader* theSubnode = NULL;
		unsigned int indexSubnodes;
	
		for (indexSubnodes = 0; indexSubnodes < nbSubnodes; indexSubnodes++)
		{
			theSubnode = *theSubnodeCursor;
			if (theSubnode)
			{
				if (theSubnode->fNodeType == kNode)
				{	
					Free((SNode**) theSubnodeCursor);
				} else {
					ckfree((char*) theSubnode);
					*theSubnodeCursor = 0;
				}
				
				theSubnodeCursor++;
			}
		}
		
		ckfree((char*) theRoot);
	}
	*ioRoot = 0;
}

/**
 * Recursive function to set a value.
 *
 * @param ioRoot		pointer to the current root of the subtree.
 *						Can be modified.
 * @param inPath		path to the value to set.
 * @param inValue		value to set in the map.
 * @return 0 if everything is fine, an error code otherwise.
 */
int
Set(SNode** ioRoot, const char* inPath, const char* inValue)
{
	int theResult = 0;
	SNode* theRoot = *ioRoot;

	do {
		const char* beginCursor = inPath;
		SHeader* theSubnode = NULL;
		SHeader** theSubnodeCursor = theRoot->fSubnodes;
		unsigned int nbSubnodes = theRoot->fSubnodesCount;
		unsigned int indexSubnodes;
		const char* endCursor;
		char theCurrentChar;
		int partLength;
		
		/* jump to first non / character in the path */
		do {
			theCurrentChar = *beginCursor++;
		} while (theCurrentChar == '/');

		/* one char too far */
		beginCursor--;
		
		if (theCurrentChar == '\0')
		{
			/* eek. we've been provided an empty path. return an error */
			theResult = EISDIR;
			break;
		}
		
		/* find end of path element and determine if we have a file name or a
			directory name (i.e. if there is a leading / or not) */
		endCursor = beginCursor;

		do {
			theCurrentChar = *endCursor++;
		} while ((theCurrentChar != '/') && (theCurrentChar != '\0'));

		/* one char too far */
		endCursor--;
		partLength = endCursor - beginCursor;

		/* do we have a node for this entry? */
		for (indexSubnodes = 0; indexSubnodes < nbSubnodes; indexSubnodes++)
		{
			int theCompResult;
			theSubnode = *theSubnodeCursor++;
			theCompResult = strncasecmp(theSubnode->fKeySubpart, beginCursor, partLength);
			if (theCompResult == 0)
			{
				/* first partLength bytes are equal, we need to check that fKeySubpart
					is not longer */
				theCompResult = theSubnode->fKeySubpart[partLength];
			}
			if (theCompResult == 0)
			{
				/* found it. */
				--theSubnodeCursor;
				break;
			} else if (theCompResult > 0) {
				theSubnode = NULL;
				break;
			}
			
			theSubnode = NULL;
		}
		
		if (theSubnode == NULL)
		{
			/* not found. We need to create a node for this entry */
			theRoot =
				(SNode*) ckrealloc(
							(char*) theRoot,
							sizeof(SNode) + (sizeof(SHeader*) * nbSubnodes));
			*ioRoot = theRoot;
			/* Push the pointers after the current node lower. */
			(void) memmove(
						&theRoot->fSubnodes[indexSubnodes + 1],
						(const void*) &theRoot->fSubnodes[indexSubnodes],
						(nbSubnodes - indexSubnodes) * sizeof(SHeader*));
			nbSubnodes++;
			theRoot->fSubnodesCount = nbSubnodes;

			if (theCurrentChar == '/')
			{
				/* It's a directory node that we need. */
				theSubnode = (SHeader*) ckalloc(sizeof(SNode) - sizeof(SHeader*));
				theSubnode->fNodeType = kNode;
				((SNode*) theSubnode)->fSubnodesCount = 0;
			} else {
				theSubnode = (SHeader*) ckalloc(sizeof(SLeaf));
				theSubnode->fNodeType = kLeaf;
				((SLeaf*) theSubnode)->fValue[NAME_MAX] = 0;
			}
			
			(void) memcpy(
					theSubnode->fKeySubpart,
					beginCursor,
					partLength);
			/* add the null terminator */
			theSubnode->fKeySubpart[partLength] = 0;
			
			/* put the node in the parent node */
			theRoot->fSubnodes[indexSubnodes] = theSubnode;
			theSubnodeCursor = &theRoot->fSubnodes[indexSubnodes];
		}
		
		if (theCurrentChar == '/')
		{
			if (theSubnode->fNodeType != kNode)
			{
				theResult = ENOTDIR;
				break;
			}
			
			/* if it's a directory, call us recursively */
			theResult = Set((SNode**) theSubnodeCursor, (endCursor + 1), inValue);
		} else {
			if (theSubnode->fNodeType != kLeaf)
			{
				theResult = EISDIR;
				break;
			}

			/* if it's a file, set the value */
			strncpy(((SLeaf*) theSubnode)->fValue, inValue, NAME_MAX);
		}
	} while (0);
	
	return theResult;
}

/**
 * Recursive function to retrieve a value.
 * This function will return NULL if the value is not in the map.
 * The pointer to the value is valid until the tree is changed.
 *
 * @param inRoot		the current root of the subtree.
 * @param inPath		path to the value to retrieve.
 * @return the value or NULL if it's not in the map.
 */
const char*
Get(SNode* inRoot, const char* inPath)
{
	const char* theResult = NULL;
	
	do {
		const char* beginCursor = inPath;
		SHeader* theSubnode = NULL;
		SHeader** theSubnodeCursor = inRoot->fSubnodes;
		unsigned int nbSubnodes = inRoot->fSubnodesCount;
		unsigned int indexSubnodes;
		const char* endCursor;
		char theCurrentChar;
		int partLength;
		
		/* jump to first non / character in the path */
		do {
			theCurrentChar = *beginCursor++;
		} while (theCurrentChar == '/');

		/* one char too far */
		beginCursor--;
		
		if (theCurrentChar == '\0')
		{
			/* eek. we've been provided an empty path. we return NULL then. */
			break;
		}
		
		/* find end of path element and determine if we have a file name or a
			directory name (i.e. if there is a leading / or not) */
		endCursor = beginCursor;

		do {
			theCurrentChar = *endCursor++;
		} while ((theCurrentChar != '/') && (theCurrentChar != '\0'));

		/* one char too far */
		endCursor--;
		partLength = endCursor - beginCursor;

		/* do we have a node for this entry? */
		for (indexSubnodes = 0; indexSubnodes < nbSubnodes; indexSubnodes++)
		{
			int theCompResult;
			theSubnode = *theSubnodeCursor++;
			theCompResult = strncasecmp(theSubnode->fKeySubpart, beginCursor, partLength);
			if (theCompResult == 0)
			{
				/* first partLength bytes are equal, we need to check that fKeySubpart
					is not longer */
				theCompResult = theSubnode->fKeySubpart[partLength];
			}
			if (theCompResult == 0)
			{
				/* found it. */
				--theSubnodeCursor;
				break;
			} else if (theCompResult > 0) {
				theSubnode = NULL;
				break;
			}
			
			theSubnode = NULL;
		}
		
		if (theSubnode == NULL)
		{
			/* not found. */
			break;
		}
		
		if (theCurrentChar == '/')
		{
			if (theSubnode->fNodeType != kNode)
			{
				break;
			}
			
			/* if it's a directory, call us recursively */
			theResult = Get((SNode*) theSubnode, (endCursor + 1));
		} else {
			if (theSubnode->fNodeType != kLeaf)
			{
				break;
			}

			/* if it's a file, return the value */
			theResult = ((SLeaf*) theSubnode)->fValue;
		}
	} while (0);
	
	return theResult;
}

/**
 * Return the list of paths for a given value.
 *
 * @param inRoot		the root of the tree.
 * @param inValue		value of the keys to find.
 * @return the list of paths which has value for their value.
 */
Tcl_Obj*
List(SNode* inRoot, const char* inValue)
{
	/* Create the result (a list) */
	Tcl_Obj* theResult = Tcl_NewListObj(0, NULL);
	
	/* Call the recursive function */
	ListSubtree((SHeader*) inRoot, inValue, theResult, "", 0);
	
	return theResult;
}

/**
 * Recursive function to return the list of paths for a given value.
 *
 * @param inRoot		the current root of the tree.
 * @param inValue		value of the keys to find.
 * @param outList		the list to populate with paths.
 * @param inSubpath		the path of the current root.
 * @param inSubpathLen	the length, without the terminator, of the path.
 */
void
ListSubtree(
	SHeader* inRoot,
	const char* inValue,
	Tcl_Obj* outList,
	const char* inSubpath,
	unsigned int inSubpathLen)
{
	if (inRoot->fNodeType == kLeaf)
	{
		/* it's a leaf. Does the value match? */
		if (strcasecmp(((SLeaf*) inRoot)->fValue, inValue) == 0)
		{
			/* It matches. */
			char* thePath = ckalloc(inSubpathLen + NAME_MAX + 1);
			(void) memcpy(thePath, inSubpath, inSubpathLen);
			(void) strcpy(
						&thePath[inSubpathLen],
						(const char*) inRoot->fKeySubpart);
			
			Tcl_ListObjAppendElement(
					NULL,
					outList,
					Tcl_NewStringObj(thePath, -1) );

			ckfree(thePath);
		}
	} else {
		/* it's a node. */
		SNode* theNode = (SNode*) inRoot;

		unsigned int theKeySubpartLen = strlen(inRoot->fKeySubpart);
		unsigned int thePathLen = inSubpathLen + theKeySubpartLen + 1;
		char* thePath = ckalloc(thePathLen + 1);

		SHeader** theSubnodeCursor = theNode->fSubnodes;
		unsigned int nbSubnodes = theNode->fSubnodesCount;
		unsigned int indexSubnodes;

		/* Let's build the path */
		(void) memcpy(thePath, inSubpath, inSubpathLen);
		(void) memcpy(
					&thePath[inSubpathLen],
					inRoot->fKeySubpart,
					theKeySubpartLen);
		inSubpathLen += theKeySubpartLen;
		thePath[thePathLen - 1] = '/';
		thePath[thePathLen] = '\0';

		/* Iteration on the nodes */
		for (indexSubnodes = 0; indexSubnodes < nbSubnodes; indexSubnodes++)
		{
			ListSubtree(*theSubnodeCursor, inValue, outList, thePath, thePathLen);

			theSubnodeCursor++;
		}
		
		/* clean up */
		ckfree(thePath);
	}
}

/**
 * Recursive function to delete a value.
 * This function will return an error if the value is not in the map.
 * This function also prunes the tree (i.e. will delete any node with no subnode).
 *
 * @param ioRoot		pointer to the current root of the subtree.
 *						Can be modified.
 * @param inPath		path to the value to delete.
 * @return an error code if a problem occurred (like the value is not in the
 * tree), 0 otherwise.
 */
int
Delete(SNode** ioRoot, const char* inPath)
{
	int theResult = 0;
	SNode* theRoot = *ioRoot;

	do {
		const char* beginCursor = inPath;
		SHeader* theSubnode = NULL;
		SHeader** theSubnodeCursor = theRoot->fSubnodes;
		unsigned int nbSubnodes = theRoot->fSubnodesCount;
		unsigned int indexSubnodes;
		const char* endCursor;
		char theCurrentChar;
		int partLength;
		
		/* jump to first non / character in the path */
		do {
			theCurrentChar = *beginCursor++;
		} while (theCurrentChar == '/');

		/* one char too far */
		beginCursor--;
		
		if (theCurrentChar == '\0')
		{
			/* eek. we've been provided an empty path. return an error */
			theResult = EISDIR;
			break;
		}
		
		/* find end of path element and determine if we have a file name or a
			directory name (i.e. if there is a leading / or not) */
		endCursor = beginCursor;

		do {
			theCurrentChar = *endCursor++;
		} while ((theCurrentChar != '/') && (theCurrentChar != '\0'));

		/* one char too far */
		endCursor--;
		partLength = endCursor - beginCursor;

		/* do we have a node for this entry? */
		for (indexSubnodes = 0; indexSubnodes < nbSubnodes; indexSubnodes++)
		{
			int theCompResult;
			theSubnode = *theSubnodeCursor++;
			theCompResult = strncasecmp(theSubnode->fKeySubpart, beginCursor, partLength);
			if (theCompResult == 0)
			{
				/* first partLength bytes are equal, we need to check that fKeySubpart
					is not longer */
				theCompResult = theSubnode->fKeySubpart[partLength];
			}
			if (theCompResult == 0)
			{
				/* found it. */
				--theSubnodeCursor;
				break;
			} else if (theCompResult > 0) {
				theSubnode = NULL;
				break;
			}
			
			theSubnode = NULL;
		}
		
		if (theSubnode == NULL)
		{
			/* not found. Return an error */
			theResult = kKeyNotFound_Err;
			break;
		}

		if (theCurrentChar == '/')
		{
			/* if it's a directory, call us recursively */
			SNode* theSubnodePointer = (SNode*) theSubnode;
			theResult = Delete(&theSubnodePointer, (endCursor + 1));

			/* Then prune the entry if it's empty */
			if (theSubnodePointer->fSubnodesCount == 0)
			{
				ckfree((char*) theSubnodePointer);
				nbSubnodes--;
				theRoot->fSubnodesCount = nbSubnodes;
				(void) memmove(
					&theRoot->fSubnodes[indexSubnodes],
					&theRoot->fSubnodes[indexSubnodes+1],
					(nbSubnodes - indexSubnodes) * sizeof(SHeader*));
				
				/* we don't realloc. */
			} else {
				*theSubnodeCursor = (SHeader*) theSubnodePointer;
			}
		} else {
			/* if it's a file, simply delete the entry */
			ckfree((char*) theSubnode);
			nbSubnodes--;
			theRoot->fSubnodesCount = nbSubnodes;
			(void) memmove(
				&theRoot->fSubnodes[indexSubnodes],
				&theRoot->fSubnodes[indexSubnodes+1],
				(nbSubnodes - indexSubnodes) * sizeof(SHeader*));
		}
	} while (0);
	
	return theResult;
}

/* ========================================================================= **
 * Tcl object functions
 * ========================================================================= */

/**
 * Free the object.
 * If the ref count reaches 0, we save the file, close it and we free the tree.
 *
 * @param inObjPtr	pointer to the object.
 */
void
FreeFilemapInternalRep(Tcl_Obj* inObjPtr)
{
	SFilemapObject* theObject = (SFilemapObject*) inObjPtr->internalRep.otherValuePtr;
	if ((--theObject->fRefCount) == 0)
	{
		SNode* theRoot = theObject->fRoot;
		int theFD = theObject->fLockFD;
		if (theFD >= 0)
		{
			/* close the file */
			close(theFD);
			theObject->fLockFD = -1;
		}
		
		/* free it */
		Free(&theRoot);
	}
	
	inObjPtr->internalRep.otherValuePtr = NULL;
}

/**
 * Duplicate the object.
 * Actually, we just increase the ref count.
 *
 * @param inSrcPtr	pointer to the object.
 * @param inDupPtr	pointer to the copy of the object.
 */
void
DupFilemapInternalRep(Tcl_Obj* inSrcPtr, Tcl_Obj* inDupPtr)
{
	/* increment the ref count */
	SFilemapObject* theObject = (SFilemapObject*) inSrcPtr->internalRep.otherValuePtr;
	theObject->fRefCount++;
	
	/* duplicate the Tcl's obj stuff */
	inDupPtr->internalRep.otherValuePtr = (VOID*) theObject;
	inDupPtr->typePtr = inSrcPtr->typePtr;
}

/**
 * Update the string representation of the filemap.
 * Filemaps don't have a real string representation, they're just "some filemap".
 * Actually, we just increase the ref count.
 *
 * @param inObjPtr	pointer to the object.
 */
void
UpdateStringOfFilemap(Tcl_Obj* inObjPtr)
{
	size_t theLength = strlen("some filemap");
	inObjPtr->length = (int) theLength;
	inObjPtr->bytes = (char*) ckalloc(theLength + 1);
	memcpy(inObjPtr->bytes, (const char*) "some filemap", theLength + 1);
}

/**
 * Convert some object to this type.
 * This always fails.
 *
 * @param inInterp	pointer to the interpreter.
 * @param inObjPtr	pointer to the object.
 */
int
SetFilemapFromAny(Tcl_Interp* inInterp, Tcl_Obj* inObjPtr UNUSED)
{
	if (inInterp != NULL) {
		Tcl_SetObjResult(inInterp,
			Tcl_NewStringObj("Conversions to filemaps are not supported", -1));
    }
    
    return TCL_ERROR;
}

/* ========================================================================= **
 * Entry points
 * ========================================================================= */

/**
 * Set the result if an error occurred and return TCL_ERROR.
 * Otherwise, set the result to "" and return TCL_OK.
 *
 * @param interp		pointer to the interpreter.
 * @param inErrorCode	code of the error.
 * @return TCL_OK if inErrorCode is 0, TCL_ERROR otherwise.
 */
int
SetResultFromErrorCode(Tcl_Interp* interp, int inErrorCode)
{
	int theResult;

	switch(inErrorCode)
	{
		case kSignatureMismatch_Err:
			Tcl_SetResult(interp, "filemap database signature is incorrect", TCL_STATIC);
			theResult = TCL_ERROR;
			break;

		case kUnknownVersion_Err:
			Tcl_SetResult(interp, "filemap database version is unknown", TCL_STATIC);
			theResult = TCL_ERROR;
			break;
	
		case kKeyNotFound_Err:
			Tcl_SetResult(interp, "key could not be found in filemap database", TCL_STATIC);
			theResult = TCL_ERROR;
			break;

		case kUnknownNodeKind_Err:
			Tcl_SetResult(
				interp,
				"unknown node kind in database (database is corrupted?)",
				TCL_STATIC);
			theResult = TCL_ERROR;
			break;

		case kNameTooLong_Err:
			Tcl_SetResult(
				interp,
				"key subpart or value string too long (the maximum length is NAME_MAX)",
				TCL_STATIC);
			theResult = TCL_ERROR;
			break;

		case kEOFWhileLoadingDB_Err:
			Tcl_SetResult(
				interp,
				"unexpected EOF while loading database (database is corrupted?)",
				TCL_STATIC);
			theResult = TCL_ERROR;
			break;

		case kUnknownOption_Err:
			Tcl_SetResult(interp, "unknown option was passed to command", TCL_STATIC);
			theResult = TCL_ERROR;
			break;

		case 0:
			Tcl_SetResult(interp, "", TCL_STATIC);
			theResult = TCL_OK;
			break;
		
		default:
			Tcl_SetResult(interp, strerror(inErrorCode), TCL_VOLATILE);
			theResult = TCL_ERROR;
	}
	
	return theResult;
}

/**
 * Retrieve the filemap internal object from the variable name.
 * If it cannot be found, set the interpreter's result to some error message.
 *
 * @param interp		pointer to the interpreter.
 * @param inVarName		object representing the variable name.
 * @return a pointer to the object or NULL if it wasn't found.
 */
SFilemapObject*
GetObjectFromVarName(Tcl_Interp* interp, Tcl_Obj* inVarName)
{
	SFilemapObject* theResult = NULL;
	
	Tcl_Obj* theTclObject = Tcl_ObjGetVar2(
				interp,
				inVarName,
				NULL,
				TCL_LEAVE_ERR_MSG);
	
	if (theTclObject != NULL)
	{
		/* Check that it's a filemap */
		if (theTclObject->typePtr != &tclFilemapType)
		{
			Tcl_SetResult(interp, "variable is not a filemap", TCL_STATIC);
		} else {
			theResult =
				(SFilemapObject*) theTclObject->internalRep.otherValuePtr;
		}
	}
	
	return theResult;
}

/**
 * filemap close subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
FilemapCloseCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;

	do {
		SFilemapObject* theFilemapObject;
		int theErr;
		
		/*	unique (second) parameter is the variable name */
		if (objc != 3) {
			Tcl_WrongNumArgs(interp, 1, objv, "close filemapName");
			theResult = TCL_ERROR;
			break;
		}

		/* retrieve the pointer to the variable */
		theFilemapObject = GetObjectFromVarName(interp, objv[2]);
		if (theFilemapObject == NULL)
		{
			theResult = TCL_ERROR;
			break;
		}
		
		/* Save the filemap to file if it's dirty & not RAM only */
		if (!(theFilemapObject->fIsDirty) || (theFilemapObject->fIsRAMOnly)) {
			theErr = 0;
		} else {
			theErr = Save(
						theFilemapObject->fFilemapPath,
						theFilemapObject->fRoot);
		}
		
		/* Return any error. */
		theResult = SetResultFromErrorCode(interp, theErr);
		
		/* Unset the variable name */
		(void) Tcl_UnsetVar(
					interp,
					Tcl_GetString(objv[2]),
					0);
    } while (0);
    
	return theResult;
}

/**
 * filemap create subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
FilemapCreateCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	Tcl_Obj* theObject;
	SFilemapObject* theFilemapObject;
	SNode* theRoot = NULL;

	/*	first (second) parameter is the variable name */
	if (objc != 3) {
		Tcl_WrongNumArgs(interp, 1, objv, "create filemapName");
		return TCL_ERROR;
	}	

	/* Create an empty root */
	Create(&theRoot);

	/* Create the object */
	theObject = Tcl_NewObj();
	theFilemapObject = (SFilemapObject*) ckalloc(sizeof(SFilemapObject));
	theFilemapObject->fRefCount = 1;
	theFilemapObject->fLockFD = -1;
	theFilemapObject->fRoot = theRoot;
	theFilemapObject->fIsReadOnly = 0;
	theFilemapObject->fIsRAMOnly = 1;
	theFilemapObject->fIsDirty = 0;
	theObject->internalRep.otherValuePtr = (VOID*) theFilemapObject;
	theObject->typePtr = &tclFilemapType;
	
	/* Save it in global variable */
	(void) Tcl_ObjSetVar2(
				interp,
				objv[2],
				NULL,
				theObject,
				0);
	
	return TCL_OK;
}

/**
 * filemap exists subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
FilemapExistsCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;

	do {
		SFilemapObject* theFilemapObject;
		const char* theValue;
		
		/*	first (second) parameter is the variable name,
			second (third) parameter is the key */
		if (objc != 4) {
			Tcl_WrongNumArgs(interp, 1, objv, "exists filemapName key");
			theResult = TCL_ERROR;
			break;
		}
	
		/* retrieve the pointer to the variable */
		theFilemapObject = GetObjectFromVarName(interp, objv[2]);
		if (theFilemapObject == NULL)
		{
			theResult = TCL_ERROR;
			break;
		}
		
		/* Retrieve the value */
		theValue = Get(theFilemapObject->fRoot, Tcl_GetString(objv[3]));
		
		/* Say if we found it */
	    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(theValue != NULL));
    } while (0);
    
	return theResult;
}

/**
 * filemap get subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
FilemapGetCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;

	do {
		SFilemapObject* theFilemapObject;
		const char* theValue;
		
		/*	first (second) parameter is the variable name,
			second (third) parameter is the key */
		if (objc != 4) {
			Tcl_WrongNumArgs(interp, 1, objv, "get filemapName key");
			theResult = TCL_ERROR;
			break;
		}
	
		/* retrieve the pointer to the variable */
		theFilemapObject = GetObjectFromVarName(interp, objv[2]);
		if (theFilemapObject == NULL)
		{
			theResult = TCL_ERROR;
			break;
		}
		
		/* Retrieve the value */
		theValue = Get(theFilemapObject->fRoot, Tcl_GetString(objv[3]));
		
		/* Return it. */
		Tcl_SetResult(interp, (char*) theValue, TCL_VOLATILE);
    } while (0);
    
	return theResult;
}

/**
 * filemap isreadonly subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
FilemapIsReadOnlyCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;

	do {
		SFilemapObject* theFilemapObject;
		
		/*	first (second) parameter is the variable name */
		if (objc != 3) {
			Tcl_WrongNumArgs(interp, 1, objv, "isreadonly filemapName");
			theResult = TCL_ERROR;
			break;
		}
	
		/* retrieve the pointer to the variable */
		theFilemapObject = GetObjectFromVarName(interp, objv[2]);
		if (theFilemapObject == NULL)
		{
			theResult = TCL_ERROR;
			break;
		}
		
		/* Say if the database is readonly */
	    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(theFilemapObject->fIsReadOnly));
    } while (0);
    
	return theResult;
}

/**
 * filemap list subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
FilemapListCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;

	do {
		SFilemapObject* theFilemapObject;
		Tcl_Obj* theList;
		
		/*	first (second) parameter is the variable name,
			second (third) parameter is the value */
		if (objc != 4) {
			Tcl_WrongNumArgs(interp, 1, objv, "list filemapName value");
			theResult = TCL_ERROR;
			break;
		}
	
		/* retrieve the pointer to the variable */
		theFilemapObject = GetObjectFromVarName(interp, objv[2]);
		if (theFilemapObject == NULL)
		{
			theResult = TCL_ERROR;
			break;
		}

		/* Build the list */
		theList = List(theFilemapObject->fRoot, Tcl_GetString(objv[3]));

		/* Return the list. */
		Tcl_SetObjResult(interp, theList);
    } while (0);
    
	return theResult;
}

/**
 * filemap open subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
FilemapOpenCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theErr = 0;
	char isReadOnly = 0;

	/*	first (second) parameter is the variable name,
		second (third) parameter is the database path,
		third (fourth) optional parameter is readonly */
	if ((objc != 4) && (objc != 5)) {
		Tcl_WrongNumArgs(interp, 1, objv, "open filemapName path [readonly]");
		return TCL_ERROR;
	}
	if (objc == 5)
	{
		if (strcmp(Tcl_GetString(objv[4]), "readonly") != 0)
		{
			return SetResultFromErrorCode(interp, kUnknownOption_Err);
		}
		
		isReadOnly = 1;
	}
	
	do {
		const char* thePath;
		Tcl_Obj* theObject;
		SFilemapObject* theFilemapObject;
		int theLockFD = -1;
		struct flock theLock;
		SNode* theRoot = NULL;
		char theLockPath[PATH_MAX];
	
		thePath = Tcl_GetString(objv[3]);
				
		/* open the lock file */
		theLockPath[sizeof(theLockPath) - 1] = 0;
		(void) snprintf(
			theLockPath, sizeof(theLockPath) - 1, "%s.lock", thePath);

		if (isReadOnly == 0)
		{
			theLockFD = open(theLockPath, O_RDWR | O_CREAT, 0664);
			if (theLockFD >= 0)
			{
				/* Get a R/W lock on it (wait if required) */
				theLock.l_type = F_WRLCK;
				theLock.l_whence = SEEK_SET;
				theLock.l_start = 0;
				theLock.l_len = 0;
				if (fcntl(theLockFD, F_SETLKW, &theLock) == -1)
				{
					theErr = errno;
					break;
				}
			} else {
				theErr = errno;
				if (theErr == EACCES)
				{
					theErr = 0;
				} else {
					break;
				}
			}
		}
		
		/* isReadOnly == 1 or opening it r/w failed because of an access
		permission error */
		if (theLockFD < 0)
		{
			/* try again without R/W */
			isReadOnly = 1;
			theLockFD = open(theLockPath, O_RDONLY | O_CREAT, 0664);
			if (theLockFD < 0)
			{
				theErr = errno;
				break;
			}

			theLock.l_type = F_RDLCK;
			theLock.l_whence = SEEK_SET;
			theLock.l_start = 0;
			theLock.l_len = 0;
			if (fcntl(theLockFD, F_SETLKW, &theLock) == -1)
			{
				theErr = errno;
				break;
			}
		}
		
		/* load the map from the file */
		theErr = Load(thePath, &theRoot);
		if (theErr != 0)
		{
			if (theRoot)
			{
				Free(&theRoot);
			}
			
			/* Close the lock */
			(void) close(theLockFD);
			break;
		}
		
		/* Create the object */
		theObject = Tcl_NewObj();
		theFilemapObject = (SFilemapObject*) ckalloc(sizeof(SFilemapObject));
		theFilemapObject->fRefCount = 1;
		(void) strncpy(
			theFilemapObject->fFilemapPath,
			thePath,
			sizeof(theFilemapObject->fFilemapPath));
		theFilemapObject->fLockFD = theLockFD;
		theFilemapObject->fRoot = theRoot;
		theFilemapObject->fIsReadOnly = isReadOnly;
		theFilemapObject->fIsDirty = 0;
		theFilemapObject->fIsRAMOnly = 0;
		theObject->internalRep.otherValuePtr = (VOID*) theFilemapObject;
		theObject->typePtr = &tclFilemapType;
		
		/* Save it in global variable */
		(void) Tcl_ObjSetVar2(
					interp,
					objv[2],
					NULL,
					theObject,
					0);
	} while (0);
	
	return SetResultFromErrorCode(interp, theErr);
}

/**
 * filemap revert subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
FilemapRevertCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;

	do {
		SFilemapObject* theFilemapObject;
		int theErr;
		
		/*	unique (second) parameter is the variable name */
		if (objc != 3) {
			Tcl_WrongNumArgs(interp, 1, objv, "revert filemapName");
			theResult = TCL_ERROR;
			break;
		}

		/* retrieve the pointer to the variable */
		theFilemapObject = GetObjectFromVarName(interp, objv[2]);
		if (theFilemapObject == NULL)
		{
			theResult = TCL_ERROR;
			break;
		}
		
		/* If the map is RAM only, return an error */
		if (theFilemapObject->fIsRAMOnly) {
			theResult = TCL_ERROR;
			break;			
		}
		
		/* Free the tree */
		Free(&theFilemapObject->fRoot);
		
		/* Reload the map from the file */
		theErr = Load(theFilemapObject->fFilemapPath, &theFilemapObject->fRoot);
		
		/* The file tree is not dirty */
		theFilemapObject->fIsDirty = 0;

		/* return any error */	
		theResult = SetResultFromErrorCode(interp, theErr);
    } while (0);
    
	return theResult;
}

/**
 * filemap save subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
FilemapSaveCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;

	do {
		SFilemapObject* theFilemapObject;
		int theErr;
		
		if (objc != 3) {
			Tcl_WrongNumArgs(interp, 1, objv, "save filemapName");
			theResult = TCL_ERROR;
			break;
		}
	
		/* retrieve the pointer to the variable */
		theFilemapObject = GetObjectFromVarName(interp, objv[2]);
		if (theFilemapObject == NULL)
		{
			theResult = TCL_ERROR;
			break;
		}
	
		/* If the map is RAM only, return an error */
		if (theFilemapObject->fIsRAMOnly) {
			theResult = TCL_ERROR;
			break;			
		}

		/* Only do anything if the tree was modified */
		/* If the tree is read only, fIsDirty is never set */
		if (theFilemapObject->fIsDirty)
		{
			/* Save the filemap to file */
			theErr = Save(
					theFilemapObject->fFilemapPath,
					theFilemapObject->fRoot);
		
			/* The file tree is not dirty */
			theFilemapObject->fIsDirty = 0;

			/* Return any error. */
			theResult = SetResultFromErrorCode(interp, theErr);	
		} else {
			Tcl_SetResult(interp, "", TCL_STATIC);
		}
    } while (0);
    
	return theResult;
}

/**
 * filemap set subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
FilemapSetCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;

	do {
		SFilemapObject* theFilemapObject;
		int theErr;
		
		/*	first (second) parameter is the variable name,
			second (third) parameter is the key,
			third (fourth) parameter is the valeu */
		if (objc != 5) {
			Tcl_WrongNumArgs(interp, 1, objv, "set filemapName key value");
			theResult = TCL_ERROR;
			break;
		}
	
		/* retrieve the pointer to the variable */
		theFilemapObject = GetObjectFromVarName(interp, objv[2]);
		if (theFilemapObject == NULL)
		{
			theResult = TCL_ERROR;
			break;
		}
		
		/* Only change the value if the map is not read only */
		if (theFilemapObject->fIsReadOnly)
		{
			theErr = EPERM;
		} else {
			/* Set the value */
			theErr = Set(
							&theFilemapObject->fRoot,
							Tcl_GetString(objv[3]),
							Tcl_GetString(objv[4]));
			
			/* The map is now dirty */
			theFilemapObject->fIsDirty = 1;
		}
		/* Return any error. */
		theResult = SetResultFromErrorCode(interp, theErr);
    } while (0);
    
	return theResult;
}

/**
 * filemap unset subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
FilemapUnsetCmd(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;

	do {
		SFilemapObject* theFilemapObject;
		int theErr;
		
		/*	first (second) parameter is the variable name,
			second (third) parameter is the key */
		if (objc != 4) {
			Tcl_WrongNumArgs(interp, 1, objv, "unset filemapName key");
			theResult = TCL_ERROR;
			break;
		}
	
		/* retrieve the pointer to the variable */
		theFilemapObject = GetObjectFromVarName(interp, objv[2]);
		if (theFilemapObject == NULL)
		{
			theResult = TCL_ERROR;
			break;
		}
		
		/* Only change the value if the map is not read only */
		if (theFilemapObject->fIsReadOnly)
		{
			theErr = EPERM;
		} else {
			/* Delete the value */
			theErr = Delete(&theFilemapObject->fRoot, Tcl_GetString(objv[3]));
			
			/* The map is now dirty */
			theFilemapObject->fIsDirty = 1;
		}

		/* Return any error. */
		theResult = SetResultFromErrorCode(interp, theErr);
    } while (0);
    
	return theResult;
	return TCL_OK;
}

/**
 * filemap command entry point.
 *
 * @param clientData	custom data (ignored)
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
FilemapCmd(
		ClientData clientData UNUSED,
		Tcl_Interp* interp,
		int objc, 
		Tcl_Obj* CONST objv[])
{
    typedef enum {
    	kFilemapClose,
    	kFilemapCreate,
    	kFilemapExists,
    	kFilemapGet,
    	kFilemapList,
    	kFilemapOpen,
    	kFilemapRevert,
    	kFilemapSave,
    	kFilemapSet,
    	kFilemapUnset,
    	kFilemapIsReadOnly
    } EOption;
    
	static const char *options[] = {
		"close", "create", "exists", "get", "list", "open", "revert", "save",
		"set", "unset", "isreadonly", NULL
	};
	int theResult = TCL_OK;
    EOption theOptionIndex;

	if (objc < 3) {
		Tcl_WrongNumArgs(interp, 1, objv, "option filemapName ?arg ...?");
		return TCL_ERROR;
	}

	theResult = Tcl_GetIndexFromObj(
				interp,
				objv[1],
				options,
				"option",
				0,
				(int*) &theOptionIndex);
	if (theResult == TCL_OK) {
		switch (theOptionIndex)
		{
			case kFilemapClose:
				theResult = FilemapCloseCmd(interp, objc, objv);
				break;

			case kFilemapCreate:
				theResult = FilemapCreateCmd(interp, objc, objv);
				break;

			case kFilemapExists:
				theResult = FilemapExistsCmd(interp, objc, objv);
				break;
			
			case kFilemapGet:
				theResult = FilemapGetCmd(interp, objc, objv);
				break;
			
			case kFilemapList:
				theResult = FilemapListCmd(interp, objc, objv);
				break;
			
			case kFilemapOpen:
				theResult = FilemapOpenCmd(interp, objc, objv);
				break;
			
			case kFilemapRevert:
				theResult = FilemapRevertCmd(interp, objc, objv);
				break;
			
			case kFilemapSave:
				theResult = FilemapSaveCmd(interp, objc, objv);
				break;
			
			case kFilemapSet:
				theResult = FilemapSetCmd(interp, objc, objv);
				break;
			
			case kFilemapUnset:
				theResult = FilemapUnsetCmd(interp, objc, objv);
				break;

			case kFilemapIsReadOnly:
				theResult = FilemapIsReadOnlyCmd(interp, objc, objv);
				break;
		}
	}
	
	return theResult;
}
