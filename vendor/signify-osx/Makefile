include autoconf.mk

PREFIX= /usr/local
BINDIR= ${PREFIX}/bin
MANDIR= ${PREFIX}/share/man

CVSROOT= anoncvs@anoncvs.openbsd.org:/cvs
#CVSROOT= anoncvs@anoncvs3.usa.openbsd.org:/cvs

### sources from upstream

SRCS+= src/lib/libc/crypt/blowfish.c
SRCS+= src/lib/libc/hash/sha2.c
SRCS+= src/lib/libc/net/base64.c
SRCS+= src/lib/libc/string/explicit_bzero.c
SRCS+= src/lib/libutil/bcrypt_pbkdf.c
SRCS+= src/lib/libutil/ohash.c
SRCS+= src/usr.bin/signify/crypto_api.c
SRCS+= src/usr.bin/signify/fe25519.c
SRCS+= src/usr.bin/signify/mod_ed25519.c
SRCS+= src/usr.bin/signify/mod_ge25519.c
SRCS+= src/usr.bin/signify/signify.c
SRCS+= src/usr.bin/signify/sc25519.c
SRCS+= src/usr.bin/signify/zsig.c

ifeq ($(HAVE_ARC4RANDOM_BUF),yes)
CFLAGS+= -DHAVE_ARC4RANDOM_BUF
else
CFLAGS+= -Isrc/lib/libcrypto
SRCS+= src/lib/libc/crypt/arc4random.c
INCL+= src/lib/libcrypto/arc4random/arc4random_osx.h
INCL+= src/lib/libc/crypt/chacha_private.h
endif

ifeq ($(HAVE_GETENTROPY),yes)
CFLAGS+= -DHAVE_GETENTROPY
else
SRCS+= src/lib/libcrypto/arc4random/getentropy_osx.c
endif

ifeq ($(HAVE_DECL_RPP_STDIN),yes)
CFLAGS+= -DHAVE_DECL_RPP_STDIN
else
SRCS+= src/lib/libc/gen/readpassphrase.c
INCL+= src/include/readpassphrase.h
CFLAGS+= -D_NSIG=NSIG
endif

ifeq ($(HAVE_TIMINGSAFE_BCMP),yes)
CFLAGS+= -DHAVE_TIMINGSAFE_BCMP
else
SRCS+= src/lib/libc/string/timingsafe_bcmp.c
endif

INCL+= src/include/blf.h
INCL+= src/include/sha2.h
INCL+= src/lib/libutil/ohash.h
INCL+= src/lib/libutil/util.h # only for bcrypt_pbkdf decl
INCL+= src/usr.bin/signify/crypto_api.h
INCL+= src/usr.bin/signify/fe25519.h
INCL+= src/usr.bin/signify/ge25519.h
INCL+= src/usr.bin/signify/ge25519_base.data
INCL+= src/usr.bin/signify/sc25519.h
INCL+= src/usr.bin/signify/signify.h

MAN= src/usr.bin/signify/signify.1

FETCH_ONLY+= src/etc/signify # keys
FETCH_ONLY+= src/lib/libc/hash/helper.c # src of generated files
FETCH_ONLY+= src/regress/lib/libc/explicit_bzero
FETCH_ONLY+= src/regress/usr.bin/signify

FROM_CVS+= ${SRCS} ${INCL} ${MAN} ${FETCH_ONLY}

### local files

HASH_HELPERS+= src/lib/libc/hash/sha256hl.c
HASH_HELPERS+= src/lib/libc/hash/sha512hl.c
HASH_HELPERS+= src/lib/libc/hash/sha512_256hl.c

LOCAL_SRCS+= ${HASH_HELPERS}
LOCAL_SRCS+= hashaliases.c
LOCAL_SRCS+= freezero.c

### build cfg

CFLAGS+= -Isrc/include
CFLAGS+= -Isrc/lib/libutil
CFLAGS+= -include missing.h
CFLAGS+= '-DDEF_WEAK(a)=__asm__("")'
CFLAGS+= '-DMAKE_CLONE(a,b)=__asm__("")'
CFLAGS+= '-Dpledge(a,b)=(0)'
CFLAGS+= -Wall -Wextra
CFLAGS+= -Wno-pointer-sign
CFLAGS+= -Wno-sign-compare
CFLAGS+= -Wno-unused-parameter

### targets

.PHONY: fetch hash-helpers clean install check test up check-updates ls

signify: ${LOCAL_SRCS} ${SRCS} ${INCL}
	${CC} ${CFLAGS} -o $@ ${SRCS} ${LOCAL_SRCS}
	cp src/usr.bin/signify/signify.1 .

hash-helpers: ${HASH_HELPERS}

src/lib/libc/hash/sha256hl.c: src/lib/libc/hash/helper.c
	sed -e 's/hashinc/sha2.h/g' \
	    -e 's/HASH/SHA256/g' \
	    -e 's/SHA[0-9][0-9][0-9]_CTX/SHA2_CTX/g' $< > $@

src/lib/libc/hash/sha512hl.c: src/lib/libc/hash/helper.c
	sed -e 's/hashinc/sha2.h/g' \
	    -e 's/HASH/SHA512/g' \
	    -e 's/SHA[0-9][0-9][0-9]_CTX/SHA2_CTX/g' $< > $@

src/lib/libc/hash/sha512_256hl.c: src/lib/libc/hash/helper.c
	sed -e 's/hashinc/sha2.h/g' \
	    -e 's/HASH/SHA512_256/g' \
	    -e 's/SHA512_256_CTX/SHA2_CTX/g' $< > $@

src/lib/libc/hash/helper.c:
	$(error Missing source files... Maybe you want to `make fetch`?)

fetch:
	# Fetch the sources via CVS.
	cvs -qd ${CVSROOT} get -P ${FROM_CVS}
	# Don't keep CVS Root files around. All they do is cause false-positives
	# for change detection when fetching from different CVS mirrors.
	find src -name Root -exec rm {} +

install: signify
	install -d ${BINDIR} ${MANDIR}/man1
	install -S -m 755 signify ${BINDIR}
	install -S -m 644 signify.1 ${MANDIR}/man1


### regression test targets

REGRESS_BZ_SRCS=  src/lib/libc/string/explicit_bzero.c
REGRESS_BZ_SRCS+= src/regress/lib/libc/explicit_bzero/explicit_bzero.c
explicit_bzero: ${REGRESS_BZ_SRCS}
	${CC} ${CFLAGS} -o $@ ${REGRESS_BZ_SRCS}

check: test

test: signify explicit_bzero
	@sh ./regress.sh


### syncing with upstream

up: check-updates

check-updates:
	@(cd src && CVS_RSH=ssh cvs -qnd ${CVSROOT} up 2>&1 \
	    | (grep -v '^? ' || echo 'Up to date!'))


### misc

ls:
	@echo $(FROM_CVS:src/%=%)

clean:
	rm -rf signify signify.dSYM signify.1 test-results explicit_bzero

distclean: clean
	-rm -f autoconf.mk
