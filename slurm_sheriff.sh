#!/bin/bash

#    Copyright (C) 2016  Janne Blomqvist
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.


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
userlist=$(/usr/bin/squeue -w $HOSTNAME -o%u -h -t R,S,CF,CG 2>$sqerrf |sort|uniq)
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
