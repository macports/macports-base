[example {
    package require calculator

    lassign $argv input
    set channel [open $input r]

    set parser [calculator]
    set ast [$parser parse $channel]
    $parser destroy
    close $channel

    ... now process the returned abstract syntax tree ...
}]
