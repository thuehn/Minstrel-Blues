
local argparse = require "argparse"
local ps = require ('posix.signal') --kill
local lpc = require ('lpc') -- wait
local conf = require ('Config') -- show_config_error


local parser = argparse ( "kill_remote", "Kill locally running process and wait for exit code to have a clean process table" )

parser:argument ( "pid", "process id to kill" )
parser:flag ( "-2 --INT", "Terminal interrupt signal (2)" )
parser:flag ( "-9 --KILL", "Kill (cannot be caught or ignored) (9)" )
parser:flag ( "--TERM", "Termination signal (15)" )
parser:flag ( "-3 --QUIT", "Terminal quit signal (3)" )
parser:option ( "-i --iteration", "calls kill n times", "1" )

local args = parser:parse ()

if ( args.pid == nil ) then
    conf.show_config_error ( parser, "pid", false )
    os.exit (1)
end

local signal
if ( args.INT == true ) then signal = ps.SIGINT
elseif ( args.KILL == true ) then signal = ps.SIGKILL
elseif ( args.TERM == true ) then signal = ps.SIGTERM
elseif ( args.QUIT == true ) then signal = ps.SIGQUIT
else signal = ps.SIGINT
end

for i = 1, tonumber ( args.iteration ) do
    ps.kill ( tonumber ( args.pid ), signal )
end

local exit_code = lpc.wait ( tonumber ( args.pid ) )
print ( exit_code )

os.exit (0)

