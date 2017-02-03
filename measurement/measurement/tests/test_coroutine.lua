local msg = ""

co = coroutine.create(
        function ()
            local file = io.open("/tmp/test", "r")
            while true do
                local line = file:read("*l")
                if (line ~= nil) then
                    msg = line 
                end
                coroutine.yield()
            end
        end
    )

while true do
    coroutine.resume(co)
    print (msg)
end
