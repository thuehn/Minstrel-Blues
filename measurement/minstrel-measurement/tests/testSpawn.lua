--require ("parsers/ex_process")
require ('spawn_pipe')

-- requires coreutils-date for n < 1 
function sleep(n)
  os.execute("sleep " .. tonumber(n))
end

-- os.execute can handle stdout only
print ( os.execute ( "ls" ) )

-- io.popen has no wait (and no process id)
local file = io.popen ( "ls", "r" )
print ( file:read("*a") )
file:close()

-- tcpdump prints connection info to stderr
-- - access to stderr desired
-- - in case: redirect stderr to stdout?

-- nixio has not process execution at all
-- - info() current process id
-- - list() ps list
-- - signal() send signal

file = io.popen ( "for I in 1 2 3 4 5 6 7 8 9 10; do date; sleep 1; done" )
file:setvbuf( "line" ) -- block until full line is ready
print ( io.type (file) )
while file do
    if file then
        line = file:read("*l")
        if not line then
            print ( "done" )
            file:close()
            file = nil
        end
        print("Got from process:", line)
    else
        print ( "closed fd" )
    end
end
-- no pid to kill ( create lua script with get_pid and kill this )

-- lua lpc (wraps spawned process into coroutine)
-- stdin, stderr, pid, wait but no stderr
-- https://github.com/LuaDist/lpc
os.exit(1)

-- ls
local p_ls = spawn_pipe("ls")
p_ls['proc']:wait()
print ( "stdout: " .. p_ls['out'] )
repeat
    c = p_ls['out']:read("*line")
    if (c ~= nil) then print (c) end
until (c == nil)
local s = "" .. p_ls['proc']:__tostring()
print (s)

-- ping
local p_ping = spawn_pipe("ping", "-c1", "127.0.0.1")
p_ping['proc']:wait()
repeat
    c = p_ping['out']:read("*line")
    if (c ~= nil) then print (c) end
until (c == nil)

-- echo "abc" | cat
--local echo, cat = spawn_pipe2({"echo", "abc"}, {"cat"})
--echo['proc']:wait()
--echo['out']:close()
--cat['in']:close()
--cat['proc']:wait()
--repeat
--    c = cat['out']:read("*line")
--    if (c ~= nil) then print (c) end
--until (c == nil)



-- tests

--local process = parse_process ( "process (22465, running)" )
--print (assert(process["pid"] == 22465))
--print (assert(process["is_running"] == true))
