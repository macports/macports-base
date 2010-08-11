#include <unistd.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char *argv[]) {
    char *cmd;
    setuid(geteuid());
    if (argc>1) {
        cmd=(char *)malloc(sizeof(char)*strlen(argv[1])+27);
        strcpy(cmd,"/usr/local/bin/gsocmake.sh ");
        strcpy(cmd+27,argv[1]);
    }
    else{
        cmd=(char *)malloc(sizeof(char)*27);
        strcpy(cmd,"/usr/local/bin/gsocmake.sh");
    }
    system(cmd);
    return 0;
}
