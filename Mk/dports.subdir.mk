.PHONY : all
.PHONY : clean distclean
.PHONY : install

all::
	@for subdir in $(SUBDIR); do\
		echo ===\> making $@ in ${DIRPRFX}$$subdir; \
		( cd $$subdir && $(MAKE) DIRPRFX=${DIRPRFX}$$subdir/ $@) || exit 1; \
	done

clean distclean::
	@for subdir in $(SUBDIR); do\
		echo ===\> making $@ in ${DIRPRFX}$$subdir; \
		( cd $$subdir && $(MAKE) DIRPRFX=${DIRPRFX}$$subdir/ $@) || exit 1; \
	done

test::
	@for subdir in $(SUBDIR); do\
		echo ===\> making $@ in ${DIRPRFX}$$subdir; \
		( cd $$subdir && $(MAKE) DIRPRFX=${DIRPRFX}$$subdir/ $@) || exit 1; \
	done

install::
	@for subdir in $(SUBDIR); do\
		echo ===\> making $@ in ${DIRPRFX}$$subdir; \
		( cd $$subdir && $(MAKE) DIRPRFX=${DIRPRFX}$$subdir/ $@) || exit 1; \
	done
