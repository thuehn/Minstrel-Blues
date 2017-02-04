-- This file creates a logging node 
-- and binds the message passing functions
-- to a RPC interface for network wide access

-- FIXME: when typed ^C into stdin the next operation gets the interrupt
-- when typed ^C^C into stdin the lua interpreter is interrupted


require ('LogNode')
require ('rpc')
local argparse = require "argparse"

local parser = argparse("Logger", "Run a minimalistic RPC enabled message logging node")

parser:option ("--port", "RPC port", "12347" )

local args = parser:parse()
lognode = LogNode:create("Logger", "/tmp/minstrel_measurement.log")
print (lognode:__tostring())

-- shortcut to logger instance to simplify access
function send_info ( from, msg ) lognode:send_info ( from, msg) end

-- shortcut to logger instance to simplify access
function send_warning ( from, msg ) lognode:send_warning ( from, msg) end

-- shortcut to logger instance to simplify access
function send_error ( from, msg) lognode:send_error ( from, msg ) end

-- shortcut to logger instance to simplify access
function set_cut () lognode:set_cut () end

-- make all functions available via RPC
if rpc.mode == "tcpip" then
    print ("Start Logging via RPC")
    rpc.server(args.port);
else
    print ( "Err: tcp/ip supported only" )
end
