#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>

#include <string.h>

#include <mach-o/arch.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>

#include <libkern/OSAtomic.h>

#include <tcl.h>

#include "macho.h"
typedef struct macho_input {
	const void *data;
	size_t length;
} macho_input_t;

/* Verify that the given range is within bounds. */
static const void *macho_read (macho_input_t *input, const void *address, size_t length) {
	if ((((uint8_t *) address) - ((uint8_t *) input->data)) + length > input->length) {
		return NULL;
	}

	return address;
}

/* Verify that address + offset + length is within bounds. */
static const void *macho_offset (macho_input_t *input, const void *address, size_t offset, size_t length) {
	void *result = ((uint8_t *) address) + offset;
	return macho_read(input, result, length);
}

/* Some byteswap wrappers */
static uint32_t macho_swap32 (uint32_t input) {
	return OSSwapInt32(input);
}
static uint32_t macho_nswap32(uint32_t input) {
	return input;
}

/* If the file is a universal binary, this function is called to call the callback function on each header.
 * This is needed because an universal file has multiple single file headers, and so to get all the arches
 * and libraries we should parse each one. The callback_func is the function that gets the arches or the libraries
 * */
Tcl_Obj * handle_universal(macho_input_t *input, Tcl_Interp * interp,  const struct fat_header * fat_header,
	Tcl_Obj* (*callback_func)(macho_input_t *, Tcl_Interp *, Tcl_Obj *) ){
	uint32_t i;
	uint32_t nfat = OSSwapBigToHostInt32(fat_header->nfat_arch);
	const struct fat_arch *archs = macho_offset(input, fat_header, sizeof(struct fat_header), sizeof(struct fat_arch));
	Tcl_Obj * return_list = Tcl_NewListObj(0,NULL);
	if (archs == NULL)
		return (Tcl_Obj *)TCL_ERROR;

	for (i = 0; i < nfat; i++) {
		const struct fat_arch *arch = macho_read(input, archs + i, sizeof(struct fat_arch));
		macho_input_t arch_input;
		if (arch == NULL)
			return (Tcl_Obj *)TCL_ERROR;

		/* Fetch a pointer to the architecture's Mach-O header. */
		arch_input.length = OSSwapBigToHostInt32(arch->size);
		arch_input.data = macho_offset(input, input->data, OSSwapBigToHostInt32(arch->offset), arch_input.length);
		if (arch_input.data == NULL)
			return (Tcl_Obj *)TCL_ERROR;

		/* Parse the architecture's Mach-O header */
		if (!callback_func(&arch_input, interp, return_list))
			return (Tcl_Obj *)TCL_ERROR;
	}
	return return_list;
}

/* For a giver magic, this function takes the file header. Note that if the file is universal, 
 * he flag universal is marked as true, and the file header is set on fat_header. If the file 
 * is not universal, the flag universal is not set and the file header is set on header.
 */

Tcl_Obj * check_magic(const uint32_t magic, macho_input_t **input, bool * universal, uint32_t (**swap32)(uint32_t), const struct mach_header ** header, const struct fat_header ** fat_header, size_t * header_size){
	const struct mach_header_64 *header64;
	switch (magic) {
		case MH_CIGAM:
			*swap32 = macho_swap32;
			/* Fall-through */

		case MH_MAGIC:
			*header_size = sizeof(**header);
			*header = macho_read(*input, (*input)->data, *header_size);
			if (*header == NULL) {
				return (Tcl_Obj *)TCL_ERROR;
			}
			break;

		case MH_CIGAM_64:
			*swap32 = macho_swap32;
			/* Fall-through */

		case MH_MAGIC_64:
			*header_size = sizeof(*header64);
			header64 = macho_read(*input, (*input)->data, sizeof(*header64));
			if (header64 == NULL)
				return (Tcl_Obj *)TCL_ERROR;

			/* The 64-bit header is a direct superset of the 32-bit header */
			*header = (struct mach_header *) header64;
			break;

		case FAT_CIGAM:
		case FAT_MAGIC:
			*fat_header = macho_read(*input, (*input)->data, sizeof(**fat_header));
			*universal = true;
			break;
		default:
			return (Tcl_Obj *)TCL_ERROR;
	}
	return (Tcl_Obj *)TCL_OK;
}

/* This function parses, for a fiven input, its libraries. The last parameter is a Tcl List,
 * that will hold the libraries, and is needed on the recursion. If is the first call, you
 * should use the function without _l.
 */
Tcl_Obj * list_macho_dlibs_l(macho_input_t *input, Tcl_Interp * interp, Tcl_Obj * dlibs) {
	/* Read the file type. */
	const uint32_t *magic = macho_read(input, input->data, sizeof(uint32_t));

	/* Parse the Mach-O header */
	bool universal = false;
	uint32_t (*swap32)(uint32_t) = macho_nswap32;

	const struct mach_header *header;
	const struct fat_header *fat_header;
	size_t header_size;

	const NXArchInfo *archInfo;
	const struct load_command *cmd;
	uint32_t ncmds;
	uint32_t i;


	if (magic == NULL)
		return (Tcl_Obj *)TCL_ERROR;

	/* Check file header magic */
	if(check_magic(*magic, &input, &universal, &swap32, &header, &fat_header, &header_size) == (Tcl_Obj *)TCL_ERROR){
		return (Tcl_Obj *)TCL_ERROR;
	}

	/* Parse universal file. */
	if (universal) {
		return handle_universal(input, interp, fat_header, list_macho_dlibs_l);
	}

	/* Fetch the arch name */
	archInfo = NXGetArchInfoFromCpuType(swap32(header->cputype), swap32(header->cpusubtype));

	/* Parse the Mach-O load commands */
	cmd = macho_offset(input, header, header_size, sizeof(struct load_command));
	if (cmd == NULL){
		return (Tcl_Obj *)TCL_ERROR;
	}
	ncmds = swap32(header->ncmds);

	/* Iterate over the load commands */
	for (i = 0; i < ncmds; i++) {
		/* Load the full command */
		uint32_t cmdsize = swap32(cmd->cmdsize);
		uint32_t cmd_type = swap32(cmd->cmd);
		size_t pathlen;
		const void * pathptr;
		char * path;
		size_t namelen;
		const void *nameptr;
		char *name;

		cmd = macho_read(input, cmd, cmdsize);
		if (cmd == NULL)
			return (Tcl_Obj *)TCL_ERROR;

		/* Handle known types */
		switch (cmd_type) {
			case LC_RPATH: {
				/* Fetch the path */
				if (cmdsize < sizeof(struct rpath_command)) {
					return (Tcl_Obj *)TCL_ERROR;
				}

				pathlen = cmdsize - sizeof(struct rpath_command);
				pathptr = macho_offset(input, cmd, sizeof(struct rpath_command), pathlen);
				if (pathptr == NULL)
					return (Tcl_Obj *)TCL_ERROR;

				path = malloc(pathlen);
				strlcpy(path, pathptr, pathlen);
				free(path);
				break;
			}

			case LC_ID_DYLIB:
			case LC_LOAD_WEAK_DYLIB:
			case LC_REEXPORT_DYLIB:
			case LC_LOAD_DYLIB: {
				/* Extract the install name */
				if (cmdsize < sizeof(struct dylib_command)) {
					return (Tcl_Obj *)TCL_ERROR;
				}

				namelen = cmdsize - sizeof(struct dylib_command);
				nameptr = macho_offset(input, cmd, sizeof(struct dylib_command), namelen);
				if (nameptr == NULL)
					return (Tcl_Obj *)TCL_ERROR;

				name = malloc(namelen);
				strlcpy(name, nameptr, namelen);

				/* This is a dyld library identifier */
				Tcl_ListObjAppendElement(interp, dlibs, Tcl_NewStringObj(name, -1));

				free(name);
				break;
			}

			default:
					break;
		}

		/* Load the next command */
		cmd = macho_offset(input, cmd, cmdsize, sizeof(struct load_command));
		if (cmd == NULL)
			return (Tcl_Obj *)TCL_ERROR;
	}

	return dlibs;
}

Tcl_Obj * list_macho_dlibs(macho_input_t *input, Tcl_Interp *interp) {
	return list_macho_dlibs_l(input, interp, Tcl_NewListObj(0,NULL));
}

/* This function parses, for a fiven input, its arches. The last parameter is a Tcl List,
 * that will hold the libraries, and is needed on the recursion. If is the first call, you
 * should use the function without _l.
 */
Tcl_Obj * list_macho_archs_l(macho_input_t *input, Tcl_Interp *interp, Tcl_Obj * archs_list) {
	const struct mach_header *header;
	size_t header_size;
	const NXArchInfo *archInfo;
	const struct fat_header *fat_header;

	/* Parse the Mach-O header */
	bool universal = false;
	uint32_t (*swap32)(uint32_t) = macho_nswap32;

	/* Read the file type. */
	const uint32_t *magic = macho_read(input, input->data, sizeof(uint32_t));
	if (magic == NULL)
		return false;


	/* Check file header magic */
	if(check_magic(*magic, &input, &universal, &swap32, &header, &fat_header, &header_size) == (Tcl_Obj *)TCL_ERROR){
		return (Tcl_Obj *)TCL_ERROR;
	}

	/* Parse universal file. */
	if (universal) {
		return handle_universal(input, interp, fat_header, list_macho_archs_l);
	}

	/* Fetch the arch name */
	archInfo = NXGetArchInfoFromCpuType(swap32(header->cputype), swap32(header->cpusubtype));
	if (archInfo != NULL) {
		Tcl_ListObjAppendElement(interp, archs_list, Tcl_NewStringObj(archInfo->name,-1));
	}
	return archs_list;
}

Tcl_Obj * list_macho_archs(macho_input_t *input, Tcl_Interp *interp) {
	return list_macho_archs_l(input, interp, Tcl_NewListObj(0,NULL));
}


/* This is the C function for Tcl list_dlibs call. It returns a list of libraries
 * from a given file. Note that the file is a file path, not a file hander.
 */
int list_dlibs(ClientData clientData __attribute__((unused)) , Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]){
	const char *path;
	int fd;
	struct stat stbuf;
	void * data;
	Tcl_Obj * libs;
	macho_input_t input_file;



	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "Should pass a file path as parameter");
		return TCL_ERROR;
	}

	path = Tcl_GetString(objv[1]);

	fd = open(path, O_RDONLY);
	if (fd < 0) {
		return TCL_ERROR;
	}

	if (fstat(fd, &stbuf) != 0) {
		return TCL_ERROR;
	}

	/* mmap */
	data = mmap(NULL, stbuf.st_size, PROT_READ, MAP_FILE|MAP_PRIVATE, fd, 0);
	if (data != MAP_FAILED){
		/* Parse */
		input_file.data = data;
		input_file.length = stbuf.st_size;

		libs = list_macho_dlibs(&input_file, interp);

		munmap(data, stbuf.st_size);
	}
	else{
		libs = (Tcl_Obj *)TCL_ERROR;
	}
	close(fd);


	if(libs == (Tcl_Obj *)TCL_ERROR){
		Tcl_SetObjResult(interp, Tcl_NewListObj(0,NULL));
	}
	else{
		Tcl_SetObjResult(interp, libs);
	}
	return TCL_OK;
}


/* This is the C function for Tcl list_archs call. It returns a list of libraries
 * from a given file. Note that the file is a file path, not a file hander.
 */
int list_archs(ClientData clientData  __attribute__((unused)), Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]){
	const char *path;
	int fd;
	struct stat stbuf;
	void * data;
	Tcl_Obj * archs;
	macho_input_t input_file;

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv,  "Should pass a file path as parameter");
		return TCL_ERROR;
	}

	path = Tcl_GetString(objv[1]);

	fd = open(path, O_RDONLY);
	if (fd < 0) {
		return TCL_ERROR;
	}

	if (fstat(fd, &stbuf) != 0) {
		return TCL_ERROR;
	}

	/* mmap */
	data = mmap(NULL, stbuf.st_size, PROT_READ, MAP_FILE|MAP_PRIVATE, fd, 0);
	if (data != MAP_FAILED){
		/* Parse */
		input_file.data = data;
		input_file.length = stbuf.st_size;

		archs = list_macho_archs(&input_file, interp);

		munmap(data, stbuf.st_size);
	}
	else{
		archs = (Tcl_Obj *)TCL_ERROR;
	}
	close(fd);

	if(archs == (Tcl_Obj *)TCL_ERROR)
		Tcl_SetObjResult(interp, Tcl_NewListObj(0,NULL));
	else
		Tcl_SetObjResult(interp, archs);
	return TCL_OK;
}
