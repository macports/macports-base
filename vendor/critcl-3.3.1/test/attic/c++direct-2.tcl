package require critcl 3.2

critcl::config language c++
critcl::clibraries -lstdc++

critcl::ccode {
    class A {
	int val;
    public:
	A() : val (123) {}
	int value() const { return val; }
        operator int() { return val; }
        int operator |(int o) { return val|o; }
        int operator &(int o) { return val&o; }
    };
}

critcl::c++command tst A {} {
    int value {}
    int {int {operator int}} {}
    int {or {operator |}} {int}
    int {and {operator &}} {int}
}

tst A
puts "tst = [A value]"
puts "tst = [A int]"
puts "tst = [A or 0xf]"
puts "tst = [A and 0xf]"
