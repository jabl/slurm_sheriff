#!/bin/bash

# Copyright (C) 2016-2020  Janne Blomqvist
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


# Only report/kill processes belonging to UID's higher than this
UID_MIN=1000000

kill_rogues=0
# Command line option handling. Only -k (= kill rogue processes) is
# supported so far.
while getopts ":k" opt; do
    case $opt in
        k)
            kill_rogues=1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

# Annoyingly, squeue always exits with status 0, so we must explicitly
# check that stderr is empty before proceeding
sqerrf=$(mktemp)
userlist=$(/usr/bin/squeue -w $(hostname -s) -o%u -h -t R,S,CF,CG 2>$sqerrf |sort|uniq)
sqerr=$(<$sqerrf)
rm $sqerrf
if [[ -n "$sqerr" ]]; then
    echo "$sqerr"
    exit 1
fi

# All processes
while IFS='\n' read -r p
do
    IFS=' ' read -r -a psplit <<< "$p"
    pid="${psplit[0]}"
    uid="${psplit[1]}"
    usr="${psplit[2]}"
    cmd="${psplit[3]}"
    if [[ $uid -le $UID_MIN ]]; then
	continue
    fi
    # Is the user allowed here?
    if [[ $userlist != *"$usr"* ]]; then
	echo "$usr $cmd"
	if [[ $kill_rogues == 1 ]]; then
	    kill -9 $pid
	fi
    fi
done < <(ps -eopid,uid,user,cmd --noheader)
