local lpc = require 'lpc'
local poll = require 'posix.poll'
local pprint = require 'pprint'
local stdio = require 'posix.stdio'
local posix = require 'posix'

-- pprint ( poll )

-- You could easily scrap the coroutine and just loop
-- over all your background tasks. (sic)

local pid, procout, procin = lpc.run("sh", "-c", "for i in 0 1 2 3 4 5 6 7 8 9; do date; sleep 1; done 2>&1")
print ( pid )

while (true) do

	local status = poll.rpoll ( stdio.fileno( procin ), 100 )
	
	if status == 0 then
		-- wait
	    posix.sleep (1)	
	elseif status == 1 then
		-- read a line, process is done if empty
		local line = procin:read ( "*l" )
		if not line then
			break
		end
        print ( line )
	else
		-- failed; die
		error( "Aiiieeee! Error" )
		break
	end

end
