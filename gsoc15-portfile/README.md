# port-create

## Installation
`jq` and `curl` is needed to run `github2port`, to install:

    $ sudo port install jq
    $ sudo port install curl

## Usage
TODO

## TODO
- Make port-create becomes the entry point
- Consider merging `port-create`, `portfile-gen`, `github2port` and `bitbucket2port`
- Split gathering meta data (i.e, Portfile variables) and generating Portfile.
- Support more groups at a time
- Allow updating Portfile, e.g., `port-create -update Portfile -license GPLv3`
- Integrate port-create into base, invoke with `port create`
