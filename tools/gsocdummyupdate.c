#include <unistd.h>

int main(int argc, char *argv[]) {
setuid(geteuid());
system("/usr/local/bin/gsocdummyupdate.sh");
return 0;
}
