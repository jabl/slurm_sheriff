#!/usr/bin/python
# -*- coding: utf-8 -*-
# vim: set fileencoding=utf-8

# Copyright (C) 2013-2014 Janne Blomqvist

# Find (and possibly kill) user processes running outside slurm
# control.

# Take the conservative approach of killing user processes on nodes
# where the user has no jobs running

# In order to use on your cluster, customize the is_user_id()
# function!

def is_user_id(uid):
    """Is this UID a user ID or a system user"""
    if uid > 1000000:
        return True
    return False

def users_with_jobs_on_this_node():
    """Return a set of UIDs with jobs running on this node"""
    import socket, subprocess
    hn = socket.gethostname()
    cmd = 'squeue -h -o "%U" -w ' + hn
    p = subprocess.Popen(cmd, shell=True, bufsize=-1, 
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    uids = set()
    for line in p.stdout:
        uids.add(int(line))
    p.stdout.close()
    for line in p.stderr:
        if line is not None:
            raise Exception("squeue command error")
    p.stderr.close()
    return uids

def outlaw_users_on_this_node(valid_uids):
    """Return a list of outlaw processes

    That is, user processes running outside control of the batch
    scheduler. Don't include processes by the user running this
    script.
    """
    import psi.process, os
    outlaws = []
    my_uid = os.getuid()
    for p in psi.process.ProcessTable().values():
        if p.ruid != my_uid and is_user_id(p.ruid) \
                and p.ruid not in valid_uids:
            outlaws.append(p)
    return outlaws

def show_outlaws(outlaws):
    """Pretty print outlaws"""
    import pwd
    if len(outlaws) > 0:
        print '     PID      USER      COMMAND'
    for o in outlaws:
        pw = pwd.getpwuid(o.ruid)
        print '%8i    %8s    %s' % (o.pid, pw.pw_name, o.command)

def kill_outlaws(outlaws):
    """Kill the outlaws"""
    import psi.process
    if len(outlaws) > 0:
        print 'Killing...'
    import signal, time
    for o in outlaws:
        o.kill(signal.SIGTERM)
    slept = False
    for o in outlaws:
        if not slept and o.exists():
            time.sleep(5)
            slept = True
        if o.exists():
            try:
                o.kill(signal.SIGKILL)
            except psi.process.NoSuchProcessError:
                pass

if __name__ == '__main__':
    from optparse import OptionParser

    valid_uids = users_with_jobs_on_this_node()
    outlaws = outlaw_users_on_this_node(valid_uids)

    usage = """%prog [options]

Find, and optionally kill, outlaw processes running outside slurm control."""
    parser = OptionParser(usage)
    parser.add_option('-k', '--kill', dest='kill', action='store_true',
                      help='Kill outlaw processes')
    (options, args) = parser.parse_args()
    show_outlaws(outlaws)
    if options.kill:
        kill_outlaws(outlaws)

