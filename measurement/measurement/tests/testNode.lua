require ('Node')

local iface = NetIF:create("AP ctrl", "lo0" , "127.0.0.1", nil)
node = Node:create("TestNode", iface, iface)
print (node:__tostring())
