-- This file creates a logging node 
-- and binds the message passing functions
-- to a RPC interface for network wide access

-- FIXME: when typed ^C into stdin the next operation gets the interrupt
-- when typed ^C^C into stdin the lua interpreter is interrupted


require ('LogNode')
require ('rpc')
local argparse = require "argparse"

local parser = argparse("Logger", "Run a minimalistic RPC enabled message logging node")

parser:argument("filename", "Filename for logging.")
parser:option ("--port", "RPC port", "12347" )
parser:flag ("--use_stdout", "Log to stdout additionally", false )

local args = parser:parse()
lognode = LogNode:create("Logger", args.filename, args.use_stdout )
lognode:send_info ( lognode.name, lognode:__tostring())

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
    lognode:send_info ( lognode.name, "Start Logging via RPC" )
    lognode:send_info ( lognode.name, "" )
    rpc.server(args.port);
else
    lognode:send_info ( lognode.name, "Err: tcp/ip supported only" )
end
