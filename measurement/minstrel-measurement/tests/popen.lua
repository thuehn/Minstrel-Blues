
--local file = io.popen ("while true; do ls; sleep 1; done", "r")
--for i=1,10 do 
--    print ( file:read("*l") )
--end
--file:close()

function os.capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

local result = os.capture("ls")
print ( result )

local exit_code = os.execute ( "ls" )

