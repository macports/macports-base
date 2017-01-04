[comment {
         ASCII diagram of the dependencies between the doctools v2 toc packages
         ======================================================================
}][example {
                                    ~~~~~~~~~~~ doctools::toc ~~~~~~~~~~~
                                   ~~                   |               ~~
                doctools::toc::export ~~~~~~~~~~~~~~~~~ | ~~~~~~~~~~~~~ doctools::toc::import
                        |                               |                       |
        +---------------+-------------------------+     |    +------------------+---------------+-----------------------+---------------+
        |               |                         |     |    |                  |               |                       |               |
doctools::config        =                         |     |    |                  =       doctools::include       doctools::config doctools::paths
                        |                         |     |    |                  |
                doctools::toc::export::<*>        |     |    |          doctools::toc::import::<*>
                        doctoc                    |     |    |                  doctoc, json
                        json                      |     |    |                  |           \\
                        html                      |     |    |          doctools::toc::parse \\
                        nroff                     |     |    |                  |             \\
                        wiki                      |     |    |  +---------------+              json
                        text                      |     |    |  |               |
                                                doctools::toc::structure        |
                                                                                |
                                                                        +-------+---------------+
                                                                        |                       |
          doctools::html  doctools::html::cssdefaults           doctools::tcl::parse    doctools::msgcat        
                |                                                                               |
          doctools::text  doctools::nroff::man_macros                                           =
                                                                                                |
                                                                                        doctools::msgcat::toc::<*>
                                                                                                c, en, de, fr
                                                                                                (fr == en for now)
        ~~      Interoperable objects, without actual package dependencies
        --      Package dependency, higher requires lower package
        =       Dynamic dependency through plugin system
        <*>     Multiple packages following the given form of naming.

}][comment {
        yaml                    export, import
        tmml                    export, import
        reStructured Text       export
        latex                   export

        list, desc - old, not needed under new system, replaced by the nested-list serialization
        null - old, not needed, deserialize doctoc alone provides validation of input.
}]
