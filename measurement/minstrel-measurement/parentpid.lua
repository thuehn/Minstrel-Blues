
function parent_pid ( pid )
    local file = io.open("/proc/" .. pid .. "/status")

    repeat
        local line = file:read("*line")
        if (line ~= nil and string.sub(line,1,5) == "PPid:") then
            return tonumber(string.sub(line,6))
        end
    until not line
    file:close()
    return nil
end

