#include "tcl.h"
#include <stdio.h>

MODULE_SCOPE const TclStubs *tclStubsPtr;

int main(int argc, char **argv) {
    const char *version;
    int exitcode = 0;
    (void)argc;

    if (tclStubsPtr != NULL) {
	printf("ERROR: stub table is already initialized");
	exitcode = 1;
    }
    tclStubsPtr = NULL;
    version = Tcl_SetPanicProc(Tcl_ConsolePanic);
    if (tclStubsPtr == NULL) {
	printf("ERROR: Tcl_SetPanicProc does not initialize the stub table\n");
	exitcode = 1;
    }
    tclStubsPtr = NULL;
    version = Tcl_InitSubsystems();
    if (tclStubsPtr == NULL) {
	printf("ERROR: Tcl_InitSubsystems does not initialize the stub table\n");
	exitcode = 1;
    }
    tclStubsPtr = NULL;
    version = Tcl_FindExecutable(argv[0]);
    if (version != NULL) {
	printf("Tcl_FindExecutable gives version %s\n", version);
    }
    if (tclStubsPtr == NULL) {
	printf("ERROR: Tcl_FindExecutable does not initialize the stub table\n");
	exitcode = 1;
    }
    if (!exitcode) {
	printf("All OK!\n");
    }
    return exitcode;
}
