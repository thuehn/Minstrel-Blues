require ("functional")
require ("ex")
require ("parsers/ex_process")
require ('spawn_pipe')

-- ls
local p_ls = spawn_pipe("ls")
repeat
    c = p_ls['out']:read("*line")
    if (c ~= nil) then print (c) end
until (c == nil)
p_ls['proc']:wait()
local s = "" .. p_ls['proc']:__tostring()
print (s)

-- ping
local p_ping = spawn_pipe("ping", "-c1", "127.0.0.1")
repeat
    c = p_ping['out']:read("*line")
    if (c ~= nil) then print (c) end
until (c == nil)
p_ping['proc']:wait()

-- echo "abc" | cat
local echo, cat = spawn_pipe2({"echo", "abc"}, {"cat"})
echo['proc']:wait()
echo['out']:close()
cat['in']:close()
cat['proc']:wait()
repeat
    c = cat['out']:read("*line")
    if (c ~= nil) then print (c) end
until (c == nil)



-- tests

local process = parse_process ( "process (22465, running)" )
print (assert(process["pid"] == 22465))
print (assert(process["is_running"] == true))
