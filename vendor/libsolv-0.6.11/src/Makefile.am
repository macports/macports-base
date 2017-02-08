libsolv_sources = bitmap.c poolarch.c poolvendor.c poolid.c strpool.c dirpool.c\
    solver.c solverdebug.c repo_solv.c repo_write.c evr.c pool.c\
    queue.c repo.c repodata.c repopage.c util.c policy.c solvable.c\
    transaction.c rules.c problems.c linkedpkg.c cplxdeps.c\
    chksum.c md5.c sha1.c sha2.c solvversion.c selection.c
libsolv_headers = bitmap.h evr.h hash.h policy.h poolarch.h poolvendor.h pool.h\
    poolid.h pooltypes.h queue.h solvable.h solver.h solverdebug.h\
    repo.h repodata.h repo_solv.h repo_write.h util.h selection.h\
    strpool.h dirpool.h knownid.h transaction.h rules.h problems.h\
    chksum.h dataiterator.h solvversion.h

lib_LTLIBRARIES = libsolv.la
libsolv_la_CPPFLAGS = -DLIBSOLV_INTERNAL=1
libsolv_la_SOURCES = $(libsolv_sources) $(libsolv_headers)
