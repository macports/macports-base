# $Id$

UPGRADECHECK    = ${localstatedir}/macports/.mprename


upgrade::
	@echo ""; echo "Upgrading your existing MacPorts installation to the new namespace if necessary:"; echo ""

# We can safely delete the ${TCL_PACKAGE_DIR}/darwinports1.0 dir as files in it are always overwritten and will now be installed onto
# ${TCL_PACKAGE_DIR}/macports1.0 with new names:
	[ ! -d ${TCL_PACKAGE_DIR}/darwinports1.0 ] || rm -rf ${TCL_PACKAGE_DIR}/darwinports1.0

# MacPorts base files in ${datadir} are also safely removed as new ones are always installed, and onto a their new location in this case too:
	[ ! -d ${datadir}/darwinports ] || rm -rf ${datadir}/darwinports

# Old version file can be safely deleted, as it was already used to start this upgrade and a new one will be installed into the new location:
	[ ! -f ${sysconfdir}/ports/dp_version ] || rm -vf ${sysconfdir}/ports/dp_version

# Old ports.conf(5) man page is removed:
	[ ! -f ${prefix}/share/man/man5/ports.conf.5 ] || rm -vf ${prefix}/share/man/man5/ports.conf.5

# Conf files directory is renamed:
	[ ! -d ${sysconfdir}/ports ] || mv -v ${sysconfdir}/ports ${sysconfdir}/macports

# Important directories inside ${localstatedir}/db/dports are moved to their new location, creating it first:
	[ -d ${localstatedir}/macports ] || mkdir -vp ${localstatedir}/macports
	for dir in distfiles packages receipts software; do \
		[ ! -d ${localstatedir}/db/dports/$${dir} ] || mv -v ${localstatedir}/db/dports/$${dir} ${localstatedir}/macports ; \
	done

# Move the default ports tree to the new layout:
	[ ! -d ${localstatedir}/db/dports/sources/rsync.rsync.darwinports.org_dpupdate_dports ] || { mkdir -vp \
		${localstatedir}/macports/sources/rsync.macports.org/release && mv -v \
		${localstatedir}/db/dports/sources/rsync.rsync.darwinports.org_dpupdate_dports ${localstatedir}/macports/sources/rsync.macports.org/release/ports ; \
	}

# Open up receipts and upgrade any paths in them containing old conventions to the new namespace:
	for receipt in ${localstatedir}/macports/receipts/*/*/receipt.bz2 ; do [ ! \( -f $${receipt} -a ! -f $${receipt}.mpsaved \) ] || { \
		cp -v $${receipt} $${receipt}.mpsaved && { \
			$(BZIP2) -q -dc $${receipt} | sed 's/db\/dports/macports/g' | $(BZIP2) -q -zf > $${receipt}.new ; \
		} && mv -v $${receipt}.new $${receipt} ; \
	}; done

# Check for existance of the main configuration file and perform a couple of replacements on it, backing it up first:
## 1) new default path up to our configuration files (referenced through other variables);
## 2) new default value for the portdbpath variable;
## 3) new MacPorts rsync server;
## 4) new default value for the base tree;
## 5) new default value for trunk's base sources for users who have it (some do);
## 6) stray quotes are removed from the value of the rsync_options key in old conf files;
## 7) useless --delete option is removed from the default rsync flags (--delete is implied by --delete-after);
## 8) references to the old ports.conf(5) man page are updated to the new macports.conf(5) page;
	[ ! \( -f ${sysconfdir}/macports/ports.conf -a ! -f ${UPGRADECHECK} \) ] || { \
		mv -v ${sysconfdir}/macports/ports.conf ${sysconfdir}/macports/macports.conf.mpsaved; \
		sed 's/etc\/ports/etc\/macports/g' ${sysconfdir}/macports/macports.conf.mpsaved > ${sysconfdir}/macports/macports.conf.tmp && \
			mv -v ${sysconfdir}/macports/macports.conf.tmp ${sysconfdir}/macports/macports.conf; \
		sed 's/db\/dports/macports/g' ${sysconfdir}/macports/macports.conf > ${sysconfdir}/macports/macports.conf.tmp && \
			mv -v ${sysconfdir}/macports/macports.conf.tmp ${sysconfdir}/macports/macports.conf; \
		sed 's/darwinports/macports/g' ${sysconfdir}/macports/macports.conf > ${sysconfdir}/macports/macports.conf.tmp && \
			mv -v ${sysconfdir}/macports/macports.conf.tmp ${sysconfdir}/macports/macports.conf; \
		sed 's/dpupdate1\/base/release\/base/g' ${sysconfdir}/macports/macports.conf > ${sysconfdir}/macports/macports.conf.tmp && \
			mv -v ${sysconfdir}/macports/macports.conf.tmp ${sysconfdir}/macports/macports.conf; \
		sed 's/dpupdate\/base\/\{0,1\}/trunk\/base\//g' ${sysconfdir}/macports/macports.conf > ${sysconfdir}/macports/macports.conf.tmp && \
			mv -v ${sysconfdir}/macports/macports.conf.tmp ${sysconfdir}/macports/macports.conf; \
		sed '/^rsync_options/s/"\(.*\)"/\1/' ${sysconfdir}/macports/macports.conf > ${sysconfdir}/macports/macports.conf.tmp && \
			mv -v ${sysconfdir}/macports/macports.conf.tmp ${sysconfdir}/macports/macports.conf; \
		sed 's/ --delete / /' ${sysconfdir}/macports/macports.conf > ${sysconfdir}/macports/macports.conf.tmp && \
			mv -v ${sysconfdir}/macports/macports.conf.tmp ${sysconfdir}/macports/macports.conf; \
		sed 's/ ports.conf(5)/ macports.conf(5)/g' ${sysconfdir}/macports/macports.conf > ${sysconfdir}/macports/macports.conf.tmp && \
			mv -v ${sysconfdir}/macports/macports.conf.tmp ${sysconfdir}/macports/macports.conf; \
	}

# Check for existance of the main sources file and perform a couple of replacements on it, backing it up first:
## 1) new MacPorts rsync server;
## 2) new default value for the ports tree.
	[ ! \( -f ${sysconfdir}/macports/sources.conf -a ! -f ${UPGRADECHECK} \) ] || { \
		cp -v ${sysconfdir}/macports/sources.conf ${sysconfdir}/macports/sources.conf.mpsaved; \
		sed 's/darwinports/macports/g' ${sysconfdir}/macports/sources.conf > ${sysconfdir}/macports/sources.conf.tmp && \
			mv -v ${sysconfdir}/macports/sources.conf.tmp ${sysconfdir}/macports/sources.conf; \
		sed 's/dpupdate\/dports/release\/ports\//g' ${sysconfdir}/macports/sources.conf > ${sysconfdir}/macports/sources.conf.tmp && \
			mv -v ${sysconfdir}/macports/sources.conf.tmp ${sysconfdir}/macports/sources.conf; \
	}

# Check for existance of a personal configuration file and perform a couple of replacements on it, backing it up first:
## 1) new default path up to our configuration files (referenced through other variables);
## 2) new default value for the portdbpath variable;
## 3) new MacPorts rsync server;
## 4) new default value for the base tree;
## 5) new default value for trunk's base sources for users who have it (some do);
## 6) stray quotes are removed from the value of the rsync_options key in old conf files;
## 7) useless --delete option is removed from the default rsync flags (--delete is implied by --delete-after);
## 8) references to the old ports.conf(5) man page are updated to the new macports.conf(5) page;
	[ ! \( -f "$${HOME}/.macports/ports.conf" -a ! -f ${UPGRADECHECK} \) ] || { \
		mv -v "$${HOME}/.macports/ports.conf" "$${HOME}/.macports/macports.conf.mpsaved"; \
		sed 's/etc\/ports/etc\/macports/g' "$${HOME}/.macports/macports.conf.mpsaved" > "$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$${HOME}/.macports/macports.conf.tmp" "$${HOME}/.macports/macports.conf"; \
		sed 's/db\/dports/macports/g' "$${HOME}/.macports/macports.conf" > "$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$${HOME}/.macports/macports.conf.tmp" "$${HOME}/.macports/macports.conf"; \
		sed 's/darwinports/macports/g' "$${HOME}/.macports/macports.conf" > "$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$${HOME}/.macports/macports.conf.tmp" "$${HOME}/.macports/macports.conf"; \
		sed 's/dpupdate1\/base/release\/base/g' "$${HOME}/.macports/macports.conf" > "$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$${HOME}/.macports/macports.conf.tmp" "$${HOME}/.macports/macports.conf"; \
		sed 's/dpupdate\/base\/\{0,1\}/trunk\/base\//g' "$${HOME}/.macports/macports.conf" > "$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$${HOME}/.macports/macports.conf.tmp" "$${HOME}/.macports/macports.conf"; \
		sed '/^rsync_options/s/"\(.*\)"/\1/' "$${HOME}/.macports/macports.conf" > "$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$${HOME}/.macports/macports.conf.tmp" "$${HOME}/.macports/macports.conf"; \
		sed 's/ --delete / /' "$${HOME}/.macports/macports.conf" > "$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$${HOME}/.macports/macports.conf.tmp" "$${HOME}/.macports/macports.conf"; \
		sed 's/ ports.conf(5)/ macports.conf(5)/g' "$${HOME}/.macports/macports.conf" > "$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$${HOME}/.macports/macports.conf.tmp" "$${HOME}/.macports/macports.conf"; \
	}

# Upgrade success announcement (meaning we're done ;):
	@[ -f ${UPGRADECHECK} ] || { echo ""; echo "MacPorts installation successfully upgraded from the old DarwinPorts namespace!"; echo ""; \
		echo "MacPorts rename update done!" > ${UPGRADECHECK} ; }
