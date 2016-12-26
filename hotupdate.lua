-------------------------------------------------------------------------------------------------------------
-- Project: MobileGame
-- Modle  : GS
-- Title  : 热更新一个module
-- Author : huang
-------------------------------------------------------------------------------------------------------------
-- History:
--          2016.12.15----Create
-------------------------------------------------------------------------------------------------------------

local package = package
local io 	  = io
local type    = type
local debug   = debug
local _G 	  = _G
local pcall   = pcall
local setmetatable = setmetatable
local pairs   = pairs
local ipairs  = ipairs
local next    = next
local require = require
local math    = math
local string  = string
local table   = table
local getfenv = getfenv
local loadstring = loadstring
local tostring   = tostring
local print 	 = print
local os 		 = os
local assert 	 = assert
local unpack 	 = unpack

module(...)

visited 	= {}
change_funs = {}
protect 	= {}
module_env  = false

--初始化全局成员
function init_global()
	protect[setmetatable] = true
	protect[pairs] 		  = true
	protect[ipairs] 	  = true
	protect[next] 		  = true
	protect[require] 	  = true
	protect[getfenv()] 	  = true
	protect[math] 		  = true
	protect[string] 	  = true
	protect[table] 		  = true
	protect[getfenv]      = true
	protect[loadstring]   = true
end

init_global()

--获取模块所有路径
function make_path(module_name)
	local result_full_file = {}
	local lua_path = package.path
	local is_windows = string.find(lua_path,"\\")
	if is_windows then
		module_name = string.gsub(module_name,"%.","\\")
	else
		module_name = string.gsub(module_name,"%.","/")
	end
	for w in string.gmatch(lua_path,"[^;]+") do
		local str = string.gsub(w,"%?",module_name)
		table.insert(result_full_file,str)
	end

	return result_full_file
end

--将.lua文件转换成str
function load_string(module_name)
	local result_full_file = make_path(module_name)
	local success = false
	for _,v in pairs(result_full_file) do
		local ok = pcall(io.input,v)
		if ok then
			success = true
			break
		end
	end
	if not success then
		print("read file "..module_name.." faild")
		return
	end
	local new_code = io.read("*all")
	local new_fun = loadstring(new_code)
	io.input():close()
	local ok,new_module = pcall(new_fun,module_name)
	if not ok then
		print(module_name.." syntax error")
		return
	end

	return new_module
end

--设置为require操作后所有设置的地方value
function set_require_value(module_name,value)
	local names = {}
	for w in string.gmatch(module_name,"[^.]+") do
		table.insert(names,w)
	end
	set_table_value(_G,value,unpack(names))
	package.loaded[module_name] = value
end

--设置table为value
function set_table_value(mod,value,name,next_name,...)
	if not mod or not name then
		print("set_table_value param error",mod,name,next_name,...)
		return
	end
	if not next_name then
		mod[name] = value
		return
	end
	set_table_value(mod[name],value,next_name,...)
end

--替换一个模块中所有fun
function replace_old(old_module,new_module,module_name)
	if not old_module or not new_module then
		print("old_module or new_module is nil name is "..module_name)
		return
	end
	local old_type = type(old_module)
	local new_type = type(new_module)
	if old_type == new_type then
		if new_type == "table" then
			update_tables_all_fun(old_module,new_module,module_name)
		elseif new_type == "function" then
			update_one_fun(old_module,new_module,module_name)
		end
	end
end

--替换一个table中所有fun
function update_tables_all_fun(old_table,new_table,module_name)
	if protect[old_table] or protect[new_table] then
		return
	end
	local signature = tostring(old_table)..tostring(new_table)
	if visited[signature] then
		return
	end
	visited[signature] = true
	for new_name,new_value in pairs(new_table) do
		local old_value = old_table[new_name]
		if old_value then
			local old_type = type(new_value)
			local new_type = type(old_value)
			if old_type == new_type then
				if new_type == "function" then
					update_one_fun(old_value,new_value,new_name,old_table)
				elseif new_type == "table" then
					update_tables_all_fun(old_value,new_value,new_name)
				end
			end
		elseif type(new_value) == "function" then
			if module_env and pcall(debug.setfenv,new_value,module_env) then
				old_table[new_name] = new_value
				local i = 1
				while true do
					local new_name,new_v = debug.getupvalue(new_value,i)
					if not new_name then
						break
					end
					print("--------------",new_name,new_v)
					i = i + 1
				end
				new_value()
			end
		end
	end
end

--记录要更新的函数
function update_one_fun(old_fun,new_fun,fun_name,old_table)
	if protect[old_fun] or protect[new_fun] then
		return
	end

	if old_fun == new_fun then
		return
	end

	local signature = tostring(old_fun)..tostring(new_fun)
	if visited[signature] then
		return
	end
	visited[signature] = true
	if pcall(debug.setfenv, new_fun, getfenv(old_fun)) then
		update_upvalue(old_fun,new_fun,fun_name)
		change_funs[old_fun] = {old_fun,new_fun,fun_name,old_table}
	else
		print("setfenv error",old_fun,new_fun,fun_name,old_table)
	end
end

--更新一个函数中所有上值
function update_upvalue(old_fun,new_fun,fun_name)
	local i = 1
	local old_upvalues = {}
	while true do
		local name,value = debug.getupvalue(old_fun,i)
		if not name then
			break
		end
		i = i + 1
		old_upvalues[name] = value
	end
	i = 1
	while true do
		local new_name,new_value = debug.getupvalue(new_fun,i)
		if not new_name then
			break
		end
		local old_value = old_upvalues[new_name]
		if old_value then
			if type(old_value) ~= type(new_value) then
				debug.setupvalue(new_fun,i,old_value)
			elseif type(old_value) == "function" then
				update_one_fun(old_value,new_value,new_name)
			elseif type(old_value) == "table" then
				update_tables_all_fun(old_value,new_value,new_name)
			else
				debug.setupvalue(new_fun,i,old_value)
			end
		end
		i = i + 1
	end
end

--更新所有关联的fun
function update_relation_fun()
	local cur_visited = {}
	cur_visited[getfenv()] = true
	local function f(t)
		if (type(t) ~= "function" and type(t) ~= "table") or cur_visited[t] or protect[t] then
			return
		end
		cur_visited[t] = true
		if type(t) == "function" then
			local i = 1
		    while true do
				local name, value = debug.getupvalue(t, i)
				if not name then
					break
				end
				if type(value) == "function" then
					local data = change_funs[value]
					if data then
						debug.setupvalue(t,i,data[2])
					end
				end
				i = i + 1
				f(value)
			end
		elseif type(t) == "table" then
			f(debug.getmetatable(t))
			local changeIndexs = {}
			for k,v in pairs(t) do
				f(k)
				f(v)
				if type(v) == "function" then
					local data = change_funs[v]
					if data then
						t[k] = data[2]
					end
				end
				if type(k) == "function" then
					local data = change_funs[k]
					if data then
						table.insert(changeIndexs,k)
					end
				end
			end
			for _,value in ipairs(changeIndexs) do
				local funcs = change_funs[value]
				t[funcs[2]] = t[funcs[1]]
				t[funcs[1]] = nil
			end
		end
	end

	f(_G)
	f(debug.getregistry())
end

--设置旧模块的evn
function set_old_evn(mod)
	module_env = false
	local mod_type = type(mod)
	if mod_type == "function" then
		module_env = getfenv(mod)
	elseif mod_type == "table" then
		for k,v in pairs(mod) do
			if type(v) == "function" then
				module_env = getfenv(v)
				if not module_env then
					break
				end
			end
		end
	end
end

-----------------------------------------------------------
--成员函数 : update_file 			热更新一个module
--参数 	   : module_name 			模块名
--返回值   : 无
--备注     : 更新奥义模块 			ms.d_hotupdate.update_file("modules.upanishad_mgr.upanishad_mgr")
-----------------------------------------------------------
function update_file(module_name)
	if not module_name then
		print("param error",module_name)
		return
	end
	local old_module = package.loaded[module_name]
	if not old_module then
		print("old module not exists "..module_name)
		return
	end

	set_require_value(module_name,nil)
	set_old_evn(old_module)
	load_string(module_name)
	local new_module = package.loaded[module_name]
	set_require_value(module_name,old_module)

	if not new_module then
		print("new_module is nil",module_name)
		return
	end

	if old_module == new_module then
		print("old_module save with new_module",module_name)
		return
	end

	visited 	= {}
	change_funs = {}
	replace_old(old_module,new_module,module_name)
	update_relation_fun()
end