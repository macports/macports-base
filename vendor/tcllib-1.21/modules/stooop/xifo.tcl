# The lifo and fifo classes (for the stooop object oriented extension)
#
# Copyright (c) 2002 by Jean-Luc Fontaine <jfontain@free.fr>.
# This code may be distributed under the same terms as Tcl.
#
# $Id: xifo.tcl,v 1.4 2004/07/19 19:12:45 jfontain Exp $


# Here is a sample FIFO/LIFO implementation with stooop.
# Sample test code is at the bottom of this file.


# Uncomment the following lines for the bottom sample code to work:
# package require stooop
# namespace import stooop::*


::stooop::class xifo {

    proc xifo {this size} {
        set ($this,size) $size
        empty $this
    }

    proc ~xifo {this} {
        variable ${this}data
        catch {unset ${this}data}
    }

    proc in {this data} {
        variable ${this}data
        tidyUp $this
        if {[array size ${this}data] >= $($this,size)} {
            unset ${this}data($($this,first))
            incr ($this,first)
        }
        set ${this}data([incr ($this,last)]) $data
    }

    proc tidyUp {this} {                       ;# warning: for internal use only
        variable ${this}data
        catch {
            unset ${this}data($($this,unset))
            unset ($this,unset)
        }
    }

    proc empty {this} {
        variable ${this}data
        catch {unset ${this}data}
        catch {unset ($this,unset)}
        set ($this,first) 0
        set ($this,last) -1
    }

    proc isEmpty {this} {
        return [expr {$($this,last) < $($this,first)}]
    }

    ::stooop::virtual proc out {this}

    ::stooop::virtual proc data {this}
}


::stooop::class lifo {

    proc lifo {this {size 2147483647}} xifo {$size} {}

    proc ~lifo {this} {}

    proc out {this} {
        xifo::tidyUp $this
        if {[array size xifo::${this}data] == 0} {
            error "lifo $this out error, empty"
        }
        # delay unsetting popped data to improve performance by avoiding a data
        # copy:
        set xifo::($this,unset) $xifo::($this,last)
        incr xifo::($this,last) -1
        return [set xifo::${this}data($xifo::($this,unset))]
    }

    proc data {this} {
        set list {}
        set first $xifo::($this,first)
        for {set index $xifo::($this,last)} {$index >= $first} {incr index -1} {
            lappend list [set xifo::${this}data($index)]
        }
        return $list
    }

}


::stooop::class fifo {

    proc fifo {this {size 2147483647}} xifo {$size} {}

    proc ~fifo {this} {}

    proc out {this} {
        xifo::tidyUp $this
        if {[array size xifo::${this}data] == 0} {
            error "fifo $this out error, empty"
        }
        # delay unsetting popped data to improve performance by avoiding a data
        # copy:
        set xifo::($this,unset) $xifo::($this,first)
        incr xifo::($this,first)
        return [set xifo::${this}data($xifo::($this,unset))]
    }

    proc data {this} {
        set list {}
        set last $xifo::($this,last)
        for {set index $xifo::($this,first)} {$index <= $last} {incr index} {
            lappend list [set xifo::${this}data($index)]
        }
        return $list
    }

}


# Here are a few lines of sample code:
#    proc exercise {id} {
#        for {set u 0} {$u < 10} {incr u} {
#            xifo::in $id $u
#        }
#        puts [xifo::out $id]
#        puts [xifo::data $id]
#        xifo::in $id $u
#        xifo::in $id [incr u]
#        puts [xifo::data $id]
#    }
#    set id [stooop::new lifo 10]
#    exercise $id
#    stooop::delete $id
#    set id [stooop::new fifo 10]
#    exercise $id
#    stooop::delete $id
