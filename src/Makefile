TCLPKG=		darwinports1.0 port1.0 pextlib1.0
SUBDIR=		${TCLPKG} port

all:
	@for subdir in $(SUBDIR); do\
		echo making $@ in $$subdir; \
		( cd $$subdir && $(MAKE) $@) || exit 1; \
	done

clean:
	@for subdir in $(SUBDIR); do\
		echo making $@ in $$subdir; \
		( cd $$subdir && $(MAKE) $@) || exit 1; \
	done

install:
	@for subdir in $(SUBDIR); do\
		echo making $@ in $$subdir; \
		( cd $$subdir && $(MAKE) $@) || exit 1; \
	done
