#!/bin/ksh
for log in $(ls ~/p[1-3]dpa0[1-4]_default-log*); do 
	print  ": $log";
	sed -n 'H; /Domain configuration has been saved/h; ${g;p;}' $log | ~/datapower/dp_grep.pl $1 $2 | grep FROM | awk '{print $(NF)}' | sort | uniq -c | sort -n; 
	done

