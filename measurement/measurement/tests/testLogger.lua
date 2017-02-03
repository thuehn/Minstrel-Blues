-- test locally running logging node
-- see Logger.lua

require ('rpc')

local port = 12347
local addr = "127.0.0.1"

if rpc.mode ~= "tcpip" then
    print ( "Err: tcp/ip supported only" )
    os.exit(1)
end

function connect_logger ()
    logger, err = rpc.connect (addr, port)
    return logger, err
end

status, logger, err = pcall ( connect_logger )
if (status == false) then
    print ("Err: no logger at address: " .. addr .. " on port: " .. port)
    os.exit(1)
end

logger.send_info("me","hello")
logger.send_info("Test", "Service Test")
logger.send_error("Test", "Service Test")
logger.send_warning("Test", "Service Test")

rpc.close ( logger )
