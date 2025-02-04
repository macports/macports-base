package require critcl 3.2

critcl::config language c++
critcl::clibraries -lstdc++

critcl::ccode {
    class A {
      int value;
    public:
      A() : value (123) {}
      operator int() const { return value; }
    };
}

critcl::cproc tryplus {} int {
	A var;
	return var;
}

puts "tryplus = [tryplus]"
