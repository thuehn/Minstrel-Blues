require 'posix.poll'
require 'posix.stdio'

fh = io.open "/proc/version"
fd = posix.stdio.fileno ( fh )
while true do
  r = posix.poll.rpoll ( fd, 500) -- poll requires a file descriptor and not the handle
  print ( r )
  if r == 0 then
    print 'timeout'
  elseif r == 1 then
    print ( fh:read () )
  else
    print "finish!"
    break
  end
end
