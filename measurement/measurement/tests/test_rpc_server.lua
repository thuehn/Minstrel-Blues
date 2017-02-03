require ('rpc')

handle 
    = rpc.listen (3, 0);
while 1 do
  if rpc.peek (handle) then
    rpc.dispatch (handle)
  else
    -- do other junk
  end
end
