
misc = require ('misc')
local argparse = require "argparse"

local parser = argparse("fetch_file", "dump file continuously to stdout")
parser:argument("filename", "Filename to fetch.")
parser:flag ("-l --line", "Read line by line", false )
parser:flag ("-b --binary", "Read binary file", false )
parser:option ("-i --interval", "Number of nanoseconds between reads", "500000000" )
parser:option ("-d --dump_to_file", "Dump all content to another file" )
local args = parser:parse()

-- fixme: -l or -b, exclude -lb

local nanoseconds = 1/1e9
local interval_num = tonumber ( args.interval )
local mode = "r"
if (args.binary) then
    mode = mode .. "b"
end

local fname = args.filename or ""
--fname = string.gsub ( fname, ":", "\\:" )

-- note: line reads can result in broken lines
while ( true ) do
    if ( isFile ( fname ) == false ) then 
        io.stderr:write ( "Error: Not a File: " .. fname .. "\n")
        os.exit ( 1 ) 
    end
    local file = io.open ( fname, mode )
    if ( file == nil ) then 
        io.stderr:write ( "Error: Open file failed: " .. fname .. ", mode: " .. mode .. "\n" )
        os.exit ( 1 )
    end

    local output_file
    if ( args.dump_to_file ~= nil ) then
        local output_mode = "a"
        if ( args.binary ) then
            output_mode = output_mode .. "b"
        end
        output_file = io.open ( args.dump_to_file, output_mode )
        if ( output_file == nil ) then
            io.stderr:write ( "Error: Open file failed: " .. args.dump_to_file .. ", mode: " .. output_mode .. "\n" )
            os.exit ( 1 )
        end
    end

    if ( args.line ) then
        local line = file:read ("*l")
        if ( line ~= nil ) then
            if ( args.dump_to_file == nil ) then
                print ( line )
            else
                if ( output_file ~= nil ) then
                    output_file:write ( line )
                end
            end
        end
    else
        local content = file:read ("*a")
        if (content ~= nil) then
            print ( content )
        else
            if ( output_file ~= nil ) then
                output_file:write ( content )
            end
        end
    end
    if ( output_file ~= nil ) then
        output_file:close ()
    end
    file:close ()
    misc.nanosleep ( interval_num * nanoseconds ) -- sleep for 500000 µs
end
