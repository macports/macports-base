
SET (libsolv_MANPAGES3
    libsolv.3 libsolv-bindings.3 libsolv-constantids.3 libsolv-history.3
    libsolv-pool.3)

SET (libsolv_MANPAGES1
    mergesolv.1 dumpsolv.1 installcheck.1 testsolv.1)

IF (ENABLE_RPMDB)
SET (libsolv_MANPAGES1 ${libsolv_MANPAGES1} rpmdb2solv.1 rpms2solv.1)
ENDIF (ENABLE_RPMDB)

IF (ENABLE_RPMMD)
SET (libsolv_MANPAGES1 ${libsolv_MANPAGES1} repomdxml2solv.1 rpmmd2solv.1 updateinfoxml2solv.1 deltainfoxml2solv.1)
ENDIF (ENABLE_RPMMD)

IF (ENABLE_HELIXREPO)
SET (libsolv_MANPAGES1 ${libsolv_MANPAGES1} helix2solv.1)
ENDIF (ENABLE_HELIXREPO)

IF (ENABLE_SUSEREPO)
SET (libsolv_MANPAGES1 ${libsolv_MANPAGES1} susetags2solv.1)
ENDIF (ENABLE_SUSEREPO)

IF (ENABLE_COMPS)
SET (libsolv_MANPAGES1 ${libsolv_MANPAGES1} comps2solv.1)
ENDIF (ENABLE_COMPS)

IF (ENABLE_DEBIAN)
SET (libsolv_MANPAGES1 ${libsolv_MANPAGES1} deb2solv.1)
ENDIF (ENABLE_DEBIAN)

IF (ENABLE_MDKREPO)
SET (libsolv_MANPAGES1 ${libsolv_MANPAGES1} mdk2solv.1)
ENDIF (ENABLE_MDKREPO)

IF (ENABLE_ARCHREPO)
SET (libsolv_MANPAGES1 ${libsolv_MANPAGES1} archpkgs2solv.1 archrepo2solv.1)
ENDIF (ENABLE_ARCHREPO)

IF (ENABLE_APPDATA)
SET (libsolv_MANPAGES1 ${libsolv_MANPAGES1} appdata2solv.1)
ENDIF (ENABLE_APPDATA)

INSTALL(FILES
    ${libsolv_MANPAGES3}
    DESTINATION "${MAN_INSTALL_DIR}/man3")

INSTALL(FILES
    ${libsolv_MANPAGES1}
    DESTINATION "${MAN_INSTALL_DIR}/man1")
