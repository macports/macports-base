# $Id$

UPGRADECHECK    = $(DESTDIR)${localstatedir}/macports/.mprename


upgrade::
	@echo ""; echo "Upgrading your existing MacPorts installation to the new namespace if necessary:"; echo ""

# We can safely delete the ${TCL_PACKAGE_DIR}/darwinports1.0 dir as files in it are always overwritten and will now be installed onto
# ${TCL_PACKAGE_DIR}/macports1.0 with new names:
	[ ! -d $(DESTDIR)${TCL_PACKAGE_DIR}/darwinports1.0 ] || rm -rf $(DESTDIR)${TCL_PACKAGE_DIR}/darwinports1.0

# MacPorts base files in ${datadir} are also safely removed as new ones are always installed, and onto a their new location in this case too:
	[ ! -d $(DESTDIR)${datadir}/darwinports ] || rm -rf $(DESTDIR)${datadir}/darwinports

# Old version file can be safely deleted, as it was already used to start this upgrade and a new one will be installed into the new location:
	[ ! -f $(DESTDIR)${sysconfdir}/ports/dp_version ] || rm -vf $(DESTDIR)${sysconfdir}/ports/dp_version

# Old ports.conf(5) man page is removed:
	[ ! -f $(DESTDIR)${prefix}/share/man/man5/ports.conf.5 ] || rm -vf $(DESTDIR)${prefix}/share/man/man5/ports.conf.5

# Conf files directory is renamed:
	[ ! -d $(DESTDIR)${sysconfdir}/ports ] || mv -v $(DESTDIR)${sysconfdir}/ports $(DESTDIR)${sysconfdir}/macports

# Important directories inside ${localstatedir}/db/dports are moved to their new location, creating it first:
	[ -d $(DESTDIR)${localstatedir}/macports ] || mkdir -vp $(DESTDIR)${localstatedir}/macports
	for dir in distfiles packages receipts software; do \
		[ ! -d $(DESTDIR)${localstatedir}/db/dports/$${dir} ] || mv -v $(DESTDIR)${localstatedir}/db/dports/$${dir} $(DESTDIR)${localstatedir}/macports ; \
	done

# Move the default ports tree to the new layout:
	[ ! -d $(DESTDIR)${localstatedir}/db/dports/sources/rsync.rsync.darwinports.org_dpupdate_dports ] || { mkdir -vp \
		$(DESTDIR)${localstatedir}/macports/sources/rsync.macports.org/release && mv -v \
		$(DESTDIR)${localstatedir}/db/dports/sources/rsync.rsync.darwinports.org_dpupdate_dports $(DESTDIR)${localstatedir}/macports/sources/rsync.macports.org/release/ports ; \
	}

# Open up receipts and upgrade any paths in them containing old conventions to the new namespace:
	for receipt in $(DESTDIR)${localstatedir}/macports/receipts/*/*/receipt.bz2 ; do [ ! \( -f $${receipt} -a ! -f $${receipt}.mpsaved \) ] || { \
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
	[ ! \( -f $(DESTDIR)${sysconfdir}/macports/ports.conf -a ! -f ${UPGRADECHECK} \) ] || { \
		mv -v $(DESTDIR)${sysconfdir}/macports/ports.conf $(DESTDIR)${sysconfdir}/macports/macports.conf.mpsaved; \
		sed 's/etc\/ports/etc\/macports/g' $(DESTDIR)${sysconfdir}/macports/macports.conf.mpsaved > $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp && \
			mv -v $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp $(DESTDIR)${sysconfdir}/macports/macports.conf; \
		sed 's/db\/dports/macports/g' $(DESTDIR)${sysconfdir}/macports/macports.conf > $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp && \
			mv -v $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp $(DESTDIR)${sysconfdir}/macports/macports.conf; \
		sed 's/darwinports/macports/g' $(DESTDIR)${sysconfdir}/macports/macports.conf > $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp && \
			mv -v $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp $(DESTDIR)${sysconfdir}/macports/macports.conf; \
		sed 's/dpupdate1\/base/release\/base/g' $(DESTDIR)${sysconfdir}/macports/macports.conf > $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp && \
			mv -v $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp $(DESTDIR)${sysconfdir}/macports/macports.conf; \
		sed 's/dpupdate\/base\/\{0,1\}/trunk\/base\//g' $(DESTDIR)${sysconfdir}/macports/macports.conf > $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp && \
			mv -v $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp $(DESTDIR)${sysconfdir}/macports/macports.conf; \
		sed '/^rsync_options/s/"\(.*\)"/\1/' $(DESTDIR)${sysconfdir}/macports/macports.conf > $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp && \
			mv -v $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp $(DESTDIR)${sysconfdir}/macports/macports.conf; \
		sed 's/ --delete / /' $(DESTDIR)${sysconfdir}/macports/macports.conf > $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp && \
			mv -v $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp $(DESTDIR)${sysconfdir}/macports/macports.conf; \
		sed 's/ ports.conf(5)/ macports.conf(5)/g' $(DESTDIR)${sysconfdir}/macports/macports.conf > $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp && \
			mv -v $(DESTDIR)${sysconfdir}/macports/macports.conf.tmp $(DESTDIR)${sysconfdir}/macports/macports.conf; \
	}

# Check for existance of the main sources file and perform a couple of replacements on it, backing it up first:
## 1) new MacPorts rsync server;
## 2) new default value for the ports tree.
	[ ! \( -f $(DESTDIR)${sysconfdir}/macports/sources.conf -a ! -f ${UPGRADECHECK} \) ] || { \
		cp -v $(DESTDIR)${sysconfdir}/macports/sources.conf $(DESTDIR)${sysconfdir}/macports/sources.conf.mpsaved; \
		sed 's/darwinports/macports/g' $(DESTDIR)${sysconfdir}/macports/sources.conf > $(DESTDIR)${sysconfdir}/macports/sources.conf.tmp && \
			mv -v $(DESTDIR)${sysconfdir}/macports/sources.conf.tmp $(DESTDIR)${sysconfdir}/macports/sources.conf; \
		sed 's/dpupdate\/dports/release\/ports\//g' $(DESTDIR)${sysconfdir}/macports/sources.conf > $(DESTDIR)${sysconfdir}/macports/sources.conf.tmp && \
			mv -v $(DESTDIR)${sysconfdir}/macports/sources.conf.tmp $(DESTDIR)${sysconfdir}/macports/sources.conf; \
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
	[ ! \( -f "$(DESTDIR)$${HOME}/.macports/ports.conf" -a ! -f ${UPGRADECHECK} \) ] || { \
		mv -v "$(DESTDIR)$${HOME}/.macports/ports.conf" "$(DESTDIR)$${HOME}/.macports/macports.conf.mpsaved"; \
		sed 's/etc\/ports/etc\/macports/g' "$(DESTDIR)$${HOME}/.macports/macports.conf.mpsaved" > "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" "$(DESTDIR)$${HOME}/.macports/macports.conf"; \
		sed 's/db\/dports/macports/g' "$(DESTDIR)$${HOME}/.macports/macports.conf" > "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" "$(DESTDIR)$${HOME}/.macports/macports.conf"; \
		sed 's/darwinports/macports/g' "$(DESTDIR)$${HOME}/.macports/macports.conf" > "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" "$(DESTDIR)$${HOME}/.macports/macports.conf"; \
		sed 's/dpupdate1\/base/release\/base/g' "$(DESTDIR)$${HOME}/.macports/macports.conf" > "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" "$(DESTDIR)$${HOME}/.macports/macports.conf"; \
		sed 's/dpupdate\/base\/\{0,1\}/trunk\/base\//g' "$(DESTDIR)$${HOME}/.macports/macports.conf" > "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" "$(DESTDIR)$${HOME}/.macports/macports.conf"; \
		sed '/^rsync_options/s/"\(.*\)"/\1/' "$(DESTDIR)$${HOME}/.macports/macports.conf" > "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" "$(DESTDIR)$${HOME}/.macports/macports.conf"; \
		sed 's/ --delete / /' "$(DESTDIR)$${HOME}/.macports/macports.conf" > "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" "$(DESTDIR)$${HOME}/.macports/macports.conf"; \
		sed 's/ ports.conf(5)/ macports.conf(5)/g' "$(DESTDIR)$${HOME}/.macports/macports.conf" > "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" && \
			mv -v "$(DESTDIR)$${HOME}/.macports/macports.conf.tmp" "$(DESTDIR)$${HOME}/.macports/macports.conf"; \
	}

# Upgrade success announcement (meaning we're done ;):
	@[ -f ${UPGRADECHECK} ] || { echo ""; echo "MacPorts installation successfully upgraded from the old DarwinPorts namespace!"; echo ""; \
		echo "MacPorts rename update done!" > ${UPGRADECHECK} ; }
