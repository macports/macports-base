#ifndef _MACHO_H_
#define _MACHO_H_

#include "xar.h"

struct mach_header {
   uint32_t magic;
   uint32_t cputype;
   uint32_t cpusubtype;
   uint32_t filetype;
   uint32_t ncmds;
   uint32_t sizeofcmds;
   uint32_t flags;
};

struct lc {
	uint32_t cmd;
	uint32_t cmdsize;
};

struct fat_header {
	uint32_t magic;
	uint32_t nfat_arch;
};

struct fat_arch {
	uint32_t cputype;
	uint32_t cpusubtype;
	uint32_t offset;
	uint32_t size;
	uint32_t alighn;
};

int32_t xar_macho_in(xar_t x, xar_file_t f, const char *attr, void **in, size_t *inlen);
int32_t xar_macho_done(xar_t x, xar_file_t f, const char *attr);

#endif /* _MACHO_H_ */
