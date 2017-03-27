local poll = require 'posix.poll'
local stdio = require 'posix.stdio'
local unistd = require 'posix.unistd'
local posix = require 'posix'
local pprint = require 'pprint'
local ps = require ('posix.signal') --kill

local misc = require ('misc')

local pid, iperf_stdin, iperf_stdout = misc.spawn ( "/usr/bin/iperf", "-s", "-p", "12000" )
--local fd = stdio.fileno ( iperf_stdout )
--pprint ( unistd.read (fd, 2048) )
posix.sleep ( 5 )
ps.kill ( pid )
ps.kill ( pid )
lpc.wait ( pid )

local ms = 50
repeat
    local fd = stdio.fileno ( iperf_stdout )
    local r = poll.rpoll ( fd, ms) -- poll requires a file descriptor and not the handle
    if ( r == 0 ) then
        print ( "r==0" )
        --return false, nil
    elseif ( r == 1 ) then
        print ( "r==1" )
--        local content = iperf_stdout:read (180)
        local res = unistd.read (fd, 2048)
        if ( res ~= nil and res ~= "" ) then
            print ( res )
        else
            break
        end
        --return true, content
    else
        print ( "r==nil" )
        --return false, nil
    end
    posix.sleep(1)
until ( r == 0 )

iperf_stdin:close()
iperf_stdout:close()
