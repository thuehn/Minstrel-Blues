
require ('lfs')
require ('spawn_pipe')

function table_size ( tbl )
    local count = 0
    for _ in pairs( tbl ) do count = count + 1 end
    return count
end

function table_tostring ( tbl )
    local str = ""
    for i, elem in ipairs ( tbl ) do
        if ( i ~= 1 ) then str = str .. ", " end
        str = str .. elem
    end
    return str
end

function copy_map ( from )
    to = {}
    for key, data in pairs ( from ) do
        to [ key ] = data
    end
    return to
end

-- https://stackoverflow.com/questions/1426954/split-string-in-lua
function split(s, delimiter)
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
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
            io.stderr:write ( "Error: file doesn't exists " .. name .. "\n" )
            return false
        end
    end
    io.stderr:write ( "Error: not a file but a directory " .. name .. "\n" )
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
    local proc = spawn_pipe ( "date", date )
    local exit_code = proc['proc']:wait()
    local err = nil
    if ( exit_code ~= 0 ) then
        err = proc ['err']:read("*l")
    end
    local date = proc['out']:read("*l")
    close_proc_pipes ( proc )
    return date, err
end

-- syncronize time (date [YYYY.]MM.DD-hh:mm[:ss])
function set_date_bb ( year, month, day, hour, min, second )
    local date = string.format ( "%04d", year ) .. "."
                 .. string.format ( "%02d", month ) .. "."
                 .. string.format ( "%02d", day ) .. "-"
                 .. string.format ( "%02d", hour ) .. ":"
                 .. string.format ( "%02d", min ) .. ":"
                 .. string.format ( "%02d", second )
    local proc = spawn_pipe ( "date", date )
    local exit_code = proc['proc']:wait()
    local err = nil
    if ( exit_code ~= 0 ) then
        err = proc ['err']:read("*l")
    end
    local date = proc['out']:read("*l")
    close_proc_pipes ( proc )
    return date, err
end
