#!/bin/bash
#if [ -z ${HOST+x} ]; then
if [ $# -lt 1 ]; then
    echo "install_remote HOST1 [HOST2] ... [HOSTn]"
else
    
    for HOST in "$@"; do 
        ping -c1 ${HOST} > /dev/null 2>&1
        if [ $? -gt 0 ]; then
            echo "host ${HOST} is not reachable"
        else
            echo "copy files to ${HOST}"

            scp bin/cpusage_single root@${HOST}:/usr/bin/cpusage_single
            scp bin/fetch_file.lua root@${HOST}:/usr/bin/fetch_file
            scp bin/runNode.lua root@${HOST}:/usr/bin/runNode
            scp bin/runControl.lua root@${HOST}:/usr/bin/runControl
            scp bin/runLogger.lua root@${HOST}:/usr/bin/runLogger
            scp bin/kill_remote.lua root@${HOST}:/usr/bin/kill_remote
            scp -r parsers/*.lua root@${HOST}:/usr/lib/lua
            scp -r *.lua root@${HOST}:/usr/lib/lua
       fi
    done
fi

# scp bin/packages/mips_24kc/minstrelm/minstrel-measurement_git-1_all.ipk root@{HOST}:/tmp
# ssh root@${HOST} opkg install /tmp/minstrel-measurement_git-1_all.ipk --force-reinstall

# tar sources
# scp
# ssh tar -x sources
