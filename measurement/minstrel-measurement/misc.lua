
require ('lfs')
require ('lpc')

Misc = {}

function table_size ( tbl )
    local count = 0
    for _ in pairs( tbl ) do count = count + 1 end
    return count
end

function table_tostring ( tbl, max_line_size )
    local count = 1
    local lines = {}
    lines [ count ] = ""
    for i, elem in ipairs ( tbl ) do
        local elem_str = tostring ( elem )
        if ( i ~= 1 ) then lines [ count ] = lines [ count ] .. ", " end
        if ( max_line_size ~= nil and ( ( string.len ( lines [ count ] ) + string.len ( elem_str ) ) >= max_line_size ) ) then
            count = count + 1
            lines [ count ] = ""
        end
        lines [ count ] = lines [ count ] .. elem
    end
    if ( count > 1 ) then
        local all = ""
        for i, line in ipairs ( lines ) do
            all = all .. line
            if ( i ~= table_size ( lines ) ) then
                all = all .. '\n'
            end
        end
        return all
    else
        return lines [ 1 ]
    end
end

Misc.write_table = function ( table, fname )
    if ( not isFile ( fname ) ) then
        local file = io.open ( fname, "w" )
        if ( file ~= nil ) then
            for i, j in ipairs ( table ) do
                if ( i ~= 1 ) then file:write (" ") end
                    file:write ( tostring ( j ) )
                end
                file:write("\n")
                file:close()
            end
        end
end

Misc.index_of = function ( value, table )
    for i, v in ipairs ( table ) do
        if ( v == value ) then return i end
    end
    return nil
end

Misc.key_of = function ( value, table )
    for k, v in pairs ( table ) do
        if ( v == value ) then return k end
    end
    return nil
end

Misc.Set = function ( list )
      local set = {}
      for _, l in ipairs ( list ) do set [ l ] = true end
      return set
end

Misc.Set_count = function ( list )
      local set = {}
      for _, l in ipairs ( list ) do
        local count = 1
        if ( set [ l ] ~= nil ) then
            count = set [ l ] + 1
        end
        set [ l ] = count
      end
      return set
end

function copy_map ( from )
    to = {}
    if ( from ~= nil ) then
        for key, data in pairs ( from ) do
            to [ key ] = data
        end
    end
    return to
end

function merge_map ( from, to )
    if ( from ~= nil and to ~= nil ) then
        for key, data in pairs ( from ) do
            to [ key ] = data
        end
    end
end

-- https://stackoverflow.com/questions/1426954/split-string-in-lua
function split(s, delimiter)
    local result = {};
    if ( s == nil or delimiter == nil ) then return result end
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result;
end


-- https://stackoverflow.com/questions/5303174/how-to-get-list-of-directories-in-lua
-- Lua implementation of PHP scandir function
function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    local pfile = popen('ls -a "'..directory..'"')
    for filename in pfile:lines() do
        i = i + 1
        t[i] = filename
    end
    pfile:close()
    return t
end


-- https://stackoverflow.com/questions/4990990/lua-check-if-a-file-exists

-- no function checks for errors.
-- you should check for them

function isFile ( name )
    if ( name == nil ) then
        io.stderr:write ( "Error: filename argument is not set\n" )
        return false 
    end
    if type ( name ) ~= "string" then 
        io.stderr:write ( "Error: filename argument should be a string\n" )
        return false 
    end
    if not isDir ( name ) then
        local exists = os.rename ( name, name )
        if ( exists ~= nil and exists == true ) then
            return true
        else 
            --io.stderr:write ( "Error: file doesn't exists " .. name .. "\n" )
            return false
        end
    end
    --io.stderr:write ( "Error: not a file but a directory " .. name .. "\n" )
    return false
end


function isFileOrDir(name)
    if type(name)~="string" then return false end
    return os.rename(name, name) and true or false
end


function isDir(name)
    if type(name)~="string" then return false end
    local cd = lfs.currentdir()
    local is = lfs.chdir(name) and true or false
    lfs.chdir(cd)
    return is
end

-- https://stackoverflow.com/questions/2282444/how-to-check-if-a-table-contains-an-element-in-lua
function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

function print_globals()
    for k, v in pairs(_G) do 
        if ( type (v) ~= "function" ) then
            print(k  .. " " .. ": " .. type(v)) 
        end
    end
end

function string.concat ( a, b )
    return a .. b
end

-- syncronize time (date MMDDhhmm[[CC]YY][.ss])
function set_date_core ( year, month, day, hour, min, second )
    local date = string.format ( "%02d", month )
                 .. string.format ( "%02d", day )
                 .. string.format ( "%02d", hour )
                 .. string.format ( "%02d", min )
                 .. string.format ( "%04d", year )
                 .. string.format ( "%02d", second )
    local date2, exit_code = Misc.execute ( "date", date )
    if ( exit_code ~= 0 ) then
        return nil, date
    else
        return date, nil
    end
end

-- syncronize time (date [YYYY.]MM.DD-hh:mm[:ss])
function set_date_bb ( year, month, day, hour, min, second )
    local date = string.format ( "%04d", year ) .. "."
                 .. string.format ( "%02d", month ) .. "."
                 .. string.format ( "%02d", day ) .. "-"
                 .. string.format ( "%02d", hour ) .. ":"
                 .. string.format ( "%02d", min ) .. ":"
                 .. string.format ( "%02d", second )
    local result, exit_code = Misc.execute ( "date", date )
    if ( exit_code ~= 0 ) then
        return nil, result
    else
        return result, nil
    end
end

function Misc.nanosleep( s )
  local ntime = os.clock() + s
  repeat until os.clock() > ntime
end

function Misc.execute ( ... )
    local pid, stdin, stdout = lpc.run ( ... )
    local exit_code = lpc.wait ( pid )
    stdin:close()
    if ( exit_code == 0 ) then
        local content = stdout:read ("*a")
        stdout:close()
        return content, exit_code
    else
        return nil, exit_code
    end
end

function Misc.spawn ( ... )
    return lpc.run ( ... )
end

return Misc
