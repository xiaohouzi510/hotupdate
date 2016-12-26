local require = require
local print = print
module("one")
d_ms = require "ms"

local str = "hello world"
one_str = "copy"
local my = {}

local function this_tow()

end

local function upvalue()

end

function my.hello()

end

my.world = function()

end

function three()

end

function one()
	d_ms.d_tow.tow()
	upvalue()
	my.hello()
	my.world()
end