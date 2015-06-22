# port-create

## Usage

Create blank Portfile template:

    $ ./port-create

Create Portfile template using tarball URL, port name and port version:

    $ ./port-create -name foo -version 1.0
    $ ./port-create -url https://www.kernel.org/pub/software/scm/git/git-2.4.2.tar.gz
    $ ./port-create -url https://www.kernel.org/pub/software/scm/git/git-2.4.2.tar.gz -name foo -version 1.0

Create Portfile template using PortGroup:

    # Github project or tarball URL
    $ ./port-create -group github https://github.com/tmux/tmux
    $ ./port-create -group github https://github.com/tmux/tmux/releases/download/2.0/tmux-2.0.tar.gz
    # Bitbucket project URL
    $ ./port-create -group bitbucket https://bitbucket.org/sshguard/sshguard
    # Python program name and version
    $ ./port-create -group python foo 1.0

## TODO
- Make port-create becomes the entry point
- Consider merging `port-create`, `portfile-gen`, `github2port` and `bitbucket2port`
- Split gathering meta data (i.e, Portfile variables) and generating Portfile.
- Support more groups at a time
- Allow updating Portfile, e.g., `port-create -update Portfile -license GPLv3`
- Integrate port-create into base, invoke with `port create`
