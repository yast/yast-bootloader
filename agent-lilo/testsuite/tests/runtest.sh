#!/bin/bash

unset Y2DEBUG
unset Y2DEBUGGER

grep sparc site.exp >/dev/null 2>&1
SPARC=$?

IN_FILE=${1%.*}".in"
test $SPARC = 0 && test -f ${1%.*}".sparc.in" && cp ${1%.*}".sparc.in" ${1%.*}".in"
test $SPARC = 0 && test -f ${1%.*}".sparc.out" && cp ${1%.*}".sparc.out" ${1%.*}".out"
rm -f "$IN_FILE.test" 2> /dev/null
cp $IN_FILE "$IN_FILE.test" 2> /dev/null

(./runag_liloconf -l - $1 >$2) 2>&1 | fgrep -v " <0> " | grep -v "^$" | sed 's/^....-..-.. ..:..:.. [^)]*) //g' > $3

cat "$IN_FILE.test" >> $2 2> /dev/null
