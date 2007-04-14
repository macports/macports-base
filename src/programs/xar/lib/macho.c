#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <arpa/inet.h>

#include "config.h"
#ifndef HAVE_ASPRINTF
#include "asprintf.h"
#endif
#include "macho.h"
#include "util.h"
#include "xar.h"

#define BIT64 0x01000000
#define PPC   0x00000012
#define I386  0x00000007

struct arches {
	int32_t size;
	int32_t offset;
};

static int initted = 0;
static struct arches *inflight = NULL;
static int32_t numarches = 0;
static int32_t curroffset = 0;

static int32_t parse_arch(xar_file_t f, struct mach_header *mh);

int32_t xar_macho_in(xar_t x, xar_file_t f, const char *attr, void **in, size_t *inlen) {
	struct mach_header *mh = *in;
	struct fat_header *fh = *in;
	uint32_t magic;
	int i;

	if( strcmp(attr, "data") != 0 )
		return 0;

	if( initted && (inflight != NULL) )
		return 0;

	/* First, check for fat */
	magic = htonl(fh->magic);
	if( magic == 0xcafebabe ) {
		struct fat_arch *fa = (struct fat_arch *)((unsigned char *)*in + sizeof(struct fat_header));
		numarches = htonl(fh->nfat_arch);

		/* sanity check, arbitrary number */
		if( numarches > 7 )
			return 0;

		xar_prop_set(f, "contents/type", "Mach-O Fat File");

		inflight = malloc( numarches * sizeof(struct arches) );
		if( !inflight )
			return -1;
		
		for( i = 0; i < numarches; ++i ) {
			int32_t sz = htonl(fa[i].size);
			int32_t off = htonl(fa[i].offset);

			inflight[i].size = sz;
			inflight[i].offset = off;
		}
		curroffset += *inlen;
		return 0;
	}

	if( inflight ) {
		for(i = 0; i < numarches; ++i) {
			if( (inflight[i].offset >= curroffset) && (inflight[i].offset < (curroffset+*inlen)) ) {

				mh = (struct mach_header *)((char *)*in + (inflight[i].offset - curroffset));
				parse_arch(f, mh);
			}
		}
		curroffset += *inlen;
		return 0;
	}

	parse_arch(f, mh);

	curroffset += *inlen;

	return 0;
}

int32_t xar_macho_done(xar_t x, xar_file_t f, const char *attr) {
	if( inflight )
		free(inflight);
	inflight = NULL;
	curroffset = 0;
	numarches = 0;
	initted = 0;
	return 0;
}

static int32_t parse_arch(xar_file_t f, struct mach_header *mh) {
	const char *cpustr, *typestr;
	char *typestr2;
	struct lc *lc;
	int n, byteflip = 0;;
	int32_t magic, cpu, type, ncmds;

	magic = mh->magic;
	cpu = mh->cputype;
	type = mh->filetype;
	ncmds = mh->ncmds;
	if( (magic == 0xcefaedfe) || (magic == 0xcffaedfe) ) {
		magic = xar_swap32(magic);
		cpu = xar_swap32(cpu);
		type = xar_swap32(type);
		ncmds = xar_swap32(ncmds);
		byteflip = 1;
	}
	if( (magic != 0xfeedface) && (magic != 0xfeedfacf) ) {
		return 1;
	}
	lc = (struct lc *)((unsigned char *)mh + sizeof(struct mach_header));
	if( magic == 0xfeedfacf ) {
		lc = (struct lc *)((unsigned char *)lc + 4);
	}
	switch(cpu) {
	case PPC: cpustr = "ppc"; break;
	case I386: cpustr = "i386"; break;
	case PPC|BIT64: cpustr = "ppc64"; break;
	default: cpustr = "unknown"; break;
	};

	switch(type) {
	case 0x01: typestr = "Mach-O Object"; break;
	case 0x02: typestr = "Mach-O Executable"; break;
	case 0x03: typestr = "Mach-O Fixed VM Library"; break;
	case 0x04: typestr = "Mach-O core"; break;
	case 0x05: typestr = "Mach-O Preloaded Executable"; break;
	case 0x06: typestr = "Mach-O Dylib"; break;
	case 0x07: typestr = "Mach-O Dylinker"; break;
	case 0x08: typestr = "Mach-O Bundle"; break;
	case 0x09: typestr = "Mach-O Stub"; break;
	default: typestr = "Unknown"; break;
	};

	if( xar_prop_get(f, "contents/type", (const char **)&typestr2) ) {
		xar_prop_set(f, "contents/type", typestr);
	}
	asprintf(&typestr2, "contents/%s/type", cpustr);
	xar_prop_set(f, typestr2, typestr);
	free(typestr2);

	for(n = 0; n < ncmds; ++n) {
		int32_t cmd, cmdsize, stroff = 0;
		char *tmpstr = NULL;
		char *propstr = NULL;
		cmd = lc->cmd;
		cmdsize = lc->cmdsize;
		if( byteflip ) {
			cmd = xar_swap32(cmd);
			cmdsize = xar_swap32(cmdsize);
		}
		switch(cmd) {
		case 0xc:
		case 0xd:
			stroff = *(int32_t *)((unsigned char *)lc+8);
			if(byteflip)
				stroff = xar_swap32(stroff);
			tmpstr = (char *)((unsigned char *)lc+stroff);
			asprintf(&propstr, "contents/%s/library",cpustr);
			xar_prop_create(f, propstr, tmpstr);
			free(propstr);
			break;
		};
		lc = (struct lc *)((unsigned char *)lc + cmdsize);
	}

	return 0;
}
