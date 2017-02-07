local msg = ""

co = coroutine.create(
        function (fname)
            local file = io.open(fname, "r")
            while true do
                print ("read")
                local line = file:read("*l")
                if (line ~= nil) then
                    msg = line 
                end
                coroutine.yield()
            end
            file:close()
        end
    )

local fname = "/tmp/test"
while true do
    state = coroutine.resume(co, fname)
    print (tostring(state))
    print (msg)
end
