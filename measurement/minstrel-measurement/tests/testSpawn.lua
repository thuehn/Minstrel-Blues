
-- requires coreutils-date for n < 1 
function sleep(n)
  os.execute("sleep " .. tonumber(n))
end

-- os.execute can handle stdout only
-- and has no pipe
local exit_code = os.execute ( "ls" )

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

-- spawn_pipe from lua ex proposal satisfys all requirements but has several memory corruptions
-- in spawn function
