package = "luarpc"
version = "scm-1"
source = {
   url = "git://github.com/jsnyder/luarpc.git"
}
description = {
   summary = "Remote Procedure Call library for Lua",
   detailed = [[
      Allows one to make remote procedure calls to another Lua state by treating a local handle as an alias for the global table of the other state.
   ]],
   homepage = "http://github.com/jsnyder/luarpc",
   license = "Lua License"
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      rpc = {
         sources = {
            "luarpc.c",
            "luarpc_socket.c",
         },
         incdirs = {
            "."
         },
         defines = { 
            "LUARPC_STANDALONE",
            "BUILD_RPC",
            "LUARPC_ENABLE_SOCKET"
         }
      }
   }
}
