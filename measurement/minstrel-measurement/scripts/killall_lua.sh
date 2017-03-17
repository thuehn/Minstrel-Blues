#!/bin/bash
#if [ -z ${HOST+x} ]; then
if [ $# -lt 1 ]; then
    echo "killall_lua HOST1 [HOST2] ... [HOSTn]"
else
    
    for HOST in "$@"; do 
        ping -c1 ${HOST} > /dev/null 2>&1
        if [ $? -gt 0 ]; then
            echo "host ${HOST} is not reachable"
        else
            echo "killall lua on ${HOST}"
            ssh root@${HOST} killall lua
       fi
    done
fi
