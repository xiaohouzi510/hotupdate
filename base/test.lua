local print   = print
local table   = table
local package = package
local os 	  = os

module(...)
t = {}
local a = 0
b = 0

function init()
	for i=1,10 do
		table.insert(t,i)
	end
end

function hello()
	print(a)
end

function func()
	b = b + 1
	a = a + 1
end