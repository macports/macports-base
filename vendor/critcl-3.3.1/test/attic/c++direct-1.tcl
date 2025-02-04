package require critcl 3.2

critcl::config language c++
critcl::clibraries -lstdc++

namespace eval testing {
    critcl::ccode {
	class Counter {
	    public:
		Counter(int startValue=0);
		Counter operator++();
		void set( int newValue);
		void reset();
		int value() const;
	    private:
		int count;
		int resetValue;
	};

	Counter::Counter(int startValue) : count(startValue),
			resetValue(startValue) {}
	Counter Counter::operator++() {
	    count++;
	}

	void Counter::set(int newValue) {
	    count=newValue;
	}

	void Counter::reset() {
	    count=resetValue;
	}

	int Counter::value() const {
	    return count;
	}
    }

    critcl::c++command counter Counter { {} {int start_value} } {
	void set {int new_value}
	void reset {}
        void {incr operator++} {}
	int value {}
    }

}

if 1 {
	testing::counter p 10
	puts "Initial Counter:  [p value]"
	p incr
	p incr
	p incr
	puts "Counter after 3 increments: [p value]"
	p set 20
	puts "Counter after set to 20: [p value]"
	p reset
	puts "Counter after reset: [p value]"

	testing::counter d
	puts "Initial Counter:  [d value]"
	d incr
	d incr
	d incr
	puts "Counter after 3 increments: [d value]"
	d set 20
	puts "Counter after set to 20: [d value]"
	d reset
	puts "Counter after reset: [d value]"
}
