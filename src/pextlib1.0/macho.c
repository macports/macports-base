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
Tcl_Interp *interp2;
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

/* return a human readable formatted version number. the result must be free()'d. */
char *macho_format_dylib_version (uint32_t version) {
	char *result;
	asprintf(&result, "%"PRIu32".%"PRIu32".%"PRIu32, (version >> 16) & 0xFF, (version >> 8) & 0xFF, version & 0xFF);
	return result;
}

/* Some byteswap wrappers */
static uint32_t macho_swap32 (uint32_t input) {
	return OSSwapInt32(input);
}

static uint32_t macho_nswap32(uint32_t input) {
	return input;
}

/* Parse a Mach-O header */
Tcl_Obj * list_macho_dlibs_l (macho_input_t *input, Tcl_Obj * dlibs) {
	/* Read the file type. */
	const uint32_t *magic = macho_read(input, input->data, sizeof(uint32_t));

	/* Parse the Mach-O header */
	bool m64 = false;
	bool universal = false;
	uint32_t (*swap32)(uint32_t) = macho_nswap32;

	const struct mach_header *header;
	const struct mach_header_64 *header64;
	size_t header_size;
	const struct fat_header *fat_header;

	const NXArchInfo *archInfo;
	const struct load_command *cmd;
	uint32_t ncmds;
	uint32_t i;


	if (magic == NULL)
		return TCL_ERROR;

	switch (*magic) {
		case MH_CIGAM:
			swap32 = macho_swap32;
			/* Fall-through */

		case MH_MAGIC:
			header_size = sizeof(*header);
			header = macho_read(input, input->data, header_size);
			if (header == NULL) {
				return false;
			}
			break;

		case MH_CIGAM_64:
			swap32 = macho_swap32;
			/* Fall-through */

		case MH_MAGIC_64:
			header_size = sizeof(*header64);
			header64 = macho_read(input, input->data, sizeof(*header64));
			if (header64 == NULL)
				return false;

			/* The 64-bit header is a direct superset of the 32-bit header */

			header = (struct mach_header *) header64;

			m64 = true;
			break;

		case FAT_CIGAM:
		case FAT_MAGIC:
			fat_header = macho_read(input, input->data, sizeof(*fat_header));
			universal = true;
			break;

		default:
			return TCL_ERROR;
	}

	/* Parse universal file. */
	if (universal) {
		uint32_t i;
		uint32_t nfat = OSSwapBigToHostInt32(fat_header->nfat_arch);
		const struct fat_arch *archs = macho_offset(input, fat_header, sizeof(struct fat_header), sizeof(struct fat_arch));
		if (archs == NULL)
			return false;

		for (i = 0; i < nfat; i++) {
			const struct fat_arch *arch = macho_read(input, archs + i, sizeof(struct fat_arch));
			macho_input_t arch_input;
			if (arch == NULL)
				return false;

			/* Fetch a pointer to the architecture's Mach-O header. */
			arch_input.length = OSSwapBigToHostInt32(arch->size);
			arch_input.data = macho_offset(input, input->data, OSSwapBigToHostInt32(arch->offset), arch_input.length);
			if (arch_input.data == NULL)
				return false;

			/* Parse the architecture's Mach-O header */
			if (!list_macho_dlibs_l(&arch_input,dlibs))
				return false;
		}

		return dlibs;
	}

	/* Fetch the arch name */
	archInfo = NXGetArchInfoFromCpuType(swap32(header->cputype), swap32(header->cpusubtype));

	/* Parse the Mach-O load commands */
	cmd = macho_offset(input, header, header_size, sizeof(struct load_command));
	if (cmd == NULL)
		return TCL_ERROR;
	ncmds = swap32(header->ncmds);

	/* Iterate over the load commands */
	for (i = 0; i < ncmds; i++) {
		/* Load the full command */
		uint32_t cmdsize = swap32(cmd->cmdsize);
		cmd = macho_read(input, cmd, cmdsize);
		if (cmd == NULL)
			return TCL_ERROR;

		/* Handle known types */
		uint32_t cmd_type = swap32(cmd->cmd);
		switch (cmd_type) {
			case LC_RPATH: {
				/* Fetch the path */
				if (cmdsize < sizeof(struct rpath_command)) {
					return TCL_ERROR;
				}

				size_t pathlen = cmdsize - sizeof(struct rpath_command);
				const void *pathptr = macho_offset(input, cmd, sizeof(struct rpath_command), pathlen);
				if (pathptr == NULL)
					return TCL_ERROR;

				char *path = malloc(pathlen);
				strlcpy(path, pathptr, pathlen);
				free(path);
				break;
			}

			case LC_ID_DYLIB:
			case LC_LOAD_WEAK_DYLIB:
			case LC_REEXPORT_DYLIB:
			case LC_LOAD_DYLIB: {
				const struct dylib_command *dylib_cmd = (const struct dylib_command *) cmd;

				/* Extract the install name */
				if (cmdsize < sizeof(struct dylib_command)) {
					return TCL_ERROR;
				}

				size_t namelen = cmdsize - sizeof(struct dylib_command);
				const void *nameptr = macho_offset(input, cmd, sizeof(struct dylib_command), namelen);
				if (nameptr == NULL)
					return TCL_ERROR;

				char *name = malloc(namelen);
				strlcpy(name, nameptr, namelen);

				/* This is a dyld library identifier */
				Tcl_ListObjAppendElement(interp2, dlibs, Tcl_NewStringObj(name, -1));

				free(name);
				break;
			}

			default:
					break;
		}

		/* Load the next command */
		cmd = macho_offset(input, cmd, cmdsize, sizeof(struct load_command));
		if (cmd == NULL)
			return TCL_ERROR;
	}

	return dlibs;
}

Tcl_Obj * list_macho_dlibs(macho_input_t *input) {
	return list_macho_dlibs_l(input, Tcl_NewListObj(0,NULL));
}

/* List Mach-O archs */
Tcl_Obj * list_macho_archs_l(macho_input_t *input, Tcl_Obj * archs_list) {
	/* Read the file type. */
	const uint32_t *magic = macho_read(input, input->data, sizeof(uint32_t));
	if (magic == NULL)
		return false;

	/* Parse the Mach-O header */
	bool universal = false;
	uint32_t (*swap32)(uint32_t) = macho_nswap32;

	const struct mach_header *header;
	const struct mach_header_64 *header64;
	size_t header_size;
	const struct fat_header *fat_header;

	switch (*magic) {
		case MH_CIGAM:
			swap32 = macho_swap32;
			/* Fall-through */

		case MH_MAGIC:
			header_size = sizeof(*header);
			header = macho_read(input, input->data, header_size);
			if (header == NULL) {
				return TCL_ERROR;
			}
			break;


		case MH_CIGAM_64:
			swap32 = macho_swap32;
			/* Fall-through */

		case MH_MAGIC_64:
			header_size = sizeof(*header64);
			header64 = macho_read(input, input->data, sizeof(*header64));
			if (header64 == NULL)
				return TCL_ERROR;

			/* The 64-bit header is a direct superset of the 32-bit header */
			header = (struct mach_header *) header64;

			break;

		case FAT_CIGAM:
		case FAT_MAGIC:
			fat_header = macho_read(input, input->data, sizeof(*fat_header));
			universal = true;
			break;

		default:
			return TCL_ERROR;
	}

	/* Parse universal file. */
	if (universal) {
		uint32_t nfat = OSSwapBigToHostInt32(fat_header->nfat_arch);
		const struct fat_arch *archs = macho_offset(input, fat_header, sizeof(struct fat_header), sizeof(struct fat_arch));
		if (archs == NULL)
			return TCL_ERROR;

		uint32_t i;
		for (i = 0; i < nfat; i++) {
			const struct fat_arch *arch = macho_read(input, archs + i, sizeof(struct fat_arch));
			if (arch == NULL)
				return TCL_ERROR;

			/* Fetch a pointer to the architecture's Mach-O header. */
			macho_input_t arch_input;
			arch_input.length = OSSwapBigToHostInt32(arch->size);
			arch_input.data = macho_offset(input, input->data, OSSwapBigToHostInt32(arch->offset), arch_input.length);
			if (arch_input.data == NULL)
				return TCL_ERROR;

			/* Parse the architecture's Mach-O header */
			if (!list_macho_archs_l(&arch_input, archs_list))
				return TCL_ERROR;
		}

		return archs_list;
	}

	/* Fetch the arch name */
	const NXArchInfo *archInfo = NXGetArchInfoFromCpuType(swap32(header->cputype), swap32(header->cpusubtype));
	if (archInfo != NULL) {
		Tcl_ListObjAppendElement(interp2, archs_list, Tcl_NewStringObj(archInfo->name,-1));
	}
	return archs_list;
}

Tcl_Obj * list_macho_archs(macho_input_t *input) {
	return list_macho_archs_l(input, Tcl_NewListObj(0,NULL));
}

int list_dlibs(ClientData clientData , Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]){
	const char *path;
	interp2 = interp;

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "directory");
		return TCL_ERROR;
	}

	path = Tcl_GetString(objv[1]);

	int fd = open(path, O_RDONLY);
	if (fd < 0) {
		return TCL_ERROR;
	}

	struct stat stbuf;
	if (fstat(fd, &stbuf) != 0) {
		return TCL_ERROR;
	}

	/* mmap */
	void *data = mmap(NULL, stbuf.st_size, PROT_READ, MAP_FILE|MAP_PRIVATE, fd, 0);
	if (data == MAP_FAILED)
		return TCL_ERROR;

	/* Parse */
	macho_input_t input_file;
	input_file.data = data;
	input_file.length = stbuf.st_size;

	Tcl_Obj * libs = list_macho_dlibs(&input_file);

	munmap(data, stbuf.st_size);
	close(fd);
	Tcl_SetObjResult(interp, libs);
	return TCL_OK;
}


int list_archs(ClientData clientData , Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]){
	interp2 = interp;
	const char *path;

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "directory");
		return TCL_ERROR;
	}

	path = Tcl_GetString(objv[1]);

	int fd = open(path, O_RDONLY);
	if (fd < 0) {
		return TCL_ERROR;
	}

	struct stat stbuf;
	if (fstat(fd, &stbuf) != 0) {
		return TCL_ERROR;
	}

	/* mmap */
	void *data = mmap(NULL, stbuf.st_size, PROT_READ, MAP_FILE|MAP_PRIVATE, fd, 0);
	if (data == MAP_FAILED)
		return TCL_ERROR;

	/* Parse */
	macho_input_t input_file;
	input_file.data = data;
	input_file.length = stbuf.st_size;

	Tcl_Obj * archs = list_macho_archs(&input_file);

	munmap(data, stbuf.st_size);
	close(fd);
	Tcl_SetObjResult(interp, archs);
	return TCL_OK;
}
