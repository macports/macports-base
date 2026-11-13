# MacPorts on Tiger

This branch restores MacPorts base compatibility with Mac OS X 10.4 Tiger.
Validation uses 10.4.11 (8S165), PowerPC G4, Xcode 2.5, Apple GCC 4.0.1,
and the system curl 7.16.3. The C++20 toolchain is not required to build base.

## Build in a separate prefix

From the source directory:

```sh
./standard_configure.sh --prefix=/opt/macports-tiger \
    --with-macports-user=mptiger \
    --with-applications-dir=/opt/macports-tiger/Applications \
    --with-frameworks-dir=/opt/macports-tiger/Library/Frameworks
make -j1
sudo make install
/opt/macports-tiger/bin/port version
sudo /opt/macports-tiger/bin/port sync
```

A separate build user keeps its home directory separate from another MacPorts
installation. A non-default prefix requires source builds of ports.

The system compiler can build base. Ports have their own compiler requirements;
base's built-in version blacklists replace the removed
`compiler_blacklist_versions` PortGroup.

## Compatibility details

- Keep the Tiger Mach-O declarations and SHA-256 aliases for the system SDK.
- Avoid `chmod -h` and GNU Make's newer `and` function on Tiger.
- Keep Tiger-specific Xcode, compiler fallback, and universal SDK selections.
- Use `OnDemand` for Tiger launchd and the older `launchctl list` interface.
- Handle the Tiger tar error when reading `+CONTENTS` from bzip2 archives.
- Use the portable folder-package builder on Tiger with system mkbom and pax.
- In the development branch, check optional Tcl compiler flags before enabling
  them, so GCC 4.0 can build the bundled Tcl 9.
- The development branch keeps select/fdset polling for SDK curl headers predating 7.16.3.
  Local HTTP tests cover GET, HEAD, remote timestamps, HTTP errors, cancellation,
  and reusing handles after errors and cancellation.
- The development branch includes the timespec declaration explicitly for TCP timing, and initializes
  the kqueue descriptor before error cleanup.

Trace mode remains unavailable when the system lacks `EV_RECEIPT`, as detected
by configure. Restoring base does not make every individual port compatible
with Tiger.

This is a local compatibility branch. An unpatched upstream base update can
replace these changes; `port sync` updates the ports tree without updating base.

## Tests

The tests include compiler version blacklists without a PortGroup, Tiger and
Leopard Xcode/compiler selections, deployment-specific launchd plists, archive
metadata paths containing spaces, checksums, file operations, and Mach-O parsing.
A current bzip2 port has also been built, installed, activated, checked for
linking errors, and exercised with a compression/decompression round trip.

PackageMaker 2.1.1's `packagearchiver` helper fails on the validation machine
with both the restored legacy command and the existing MacPorts 2.10.2.
Tiger therefore uses the existing portable folder-package builder with system
mkbom and pax, avoiding that helper.
