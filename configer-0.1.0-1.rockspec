package = "configer"
version = "0.1.0-1"
source = {
   url = "git+https://github.com/RiskoZoSlovenska/configer",
}
description = {
   summary = "A configuration merger for Lua",
   detailed = "configer is small library for merging default and user-provided configs, allowing the user to only specify the things they want to change without having to copy the entire configuration.",
   homepage = "https://github.com/RiskoZoSlovenska/configer",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {
      configer = "configer.lua",
   },
}
