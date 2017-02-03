require ('rpc')
require ("parsers/ex_process")
require ("ex")

if rpc.mode == "tcpip" then
    slave, err = rpc.connect ("127.0.0.1", 12346)
    if ( ap_err == nil and sta_err== nil) then
        print ("connected")
    end
end

local cpusage_proc_str = slave.start_cpusage()
local cpusage_proc = parse_process ( cpusage_proc_str )

for i=1,5 do
    print ( "sleep" )
    ex.sleep(1)
end
print ("done")

local exit_code = slave.stop_cpusage( cpusage_proc['pid'] )
print ( exit_code )
ex.sleep(1)

local cpusage = slave.get_cpusage()
print ( "cpusage: " .. cpusage )

--[[
local file = io.open("/tmp/cpusage_dump", "r+")
local content = file:read("*all")

print (content)
--]]
