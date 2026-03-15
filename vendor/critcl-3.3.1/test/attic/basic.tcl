package require critcl 3.2

critcl::cproc add {int x int y} int {
    return x + y;
}

critcl::cproc cube {int x} int {
    return x * x * x;
}

puts stderr "add 1 + 2 = [add 1 2]"
puts stderr "cube 2 = [cube 2]"
