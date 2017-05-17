misc = require ('misc')    
posix = require ('posix')

--pid, stdin, stdout = misc.spawn ( "/bin/cat", "/dev/kmsg" )
pid, stdin, stdout = misc.spawn ( "/bin/dmesg" )
proc = { pid = pid, stdin = stdin, stdout = stdout }

posix.sleep ( 10 )

content = proc.stdout:read ( "*a" )
print ( content )
proc.stdin:close ()
proc.stdout:close ()

exit_code = lpc.wait ( proc.pid )
print ( exit_code )
