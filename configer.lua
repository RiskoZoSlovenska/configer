local function verifySubtablesAreUnique(tbl, seen)
	seen = seen or {}

	if type(tbl) ~= "table" then
		return true
	elseif seen[tbl] then
		return false
	end

	seen[tbl] = true

	for _, v in pairs(tbl) do
		if not verifySubtablesAreUnique(v, seen) then
			return false
		end
	end

	return true
end

local function deepcopy(tbl, seen)
	if type(tbl) ~= "table" then
		return tbl
	end

	seen = seen or {}

	local new = {}
	seen[tbl] = new

	for k, v in pairs(tbl) do
		new[k] = seen[v] or deepcopy(v, seen)
	end

	return new
end


local sets = {}
local updates = {}
local defaults = {}

local NIL = {}

local function make(category, value)
	local key = {}
	category[key] = value
	return key
end

local SET = function(value)
	if value == nil then
		return NIL
	else
		return make(sets, value)
	end
end

local UPDATE = function(updater)
	return make(updates, updater)
end

local defaultMeta; defaultMeta = {
	__index = function(self, key)
		local oldPath = defaults[self]
		local newPath = deepcopy(oldPath)
		table.insert(newPath, key)

		local new = setmetatable({}, defaultMeta)
		defaults[new] = newPath

		return new
	end
}

local DEFAULT = setmetatable({}, defaultMeta)
defaults[DEFAULT] = {}


local function retrieve(value, path, level)
	local cur = value

	for i, key in ipairs(path) do
		if type(cur) ~= "table" then
			local pathName = "DEFAULT." .. table.concat(path, ".", 1, i)
			error("attempt to access index of non-table default value: " .. pathName, level + 1)
		end
		cur = cur[key]
	end

	return cur
end

local function _resolve(default, new, topDefault, level)
	-- NIL
	if new == NIL then
		return nil
	end

	-- SET
	local value = sets[new]
	if value ~= nil then
		return deepcopy(value)
	end

	-- DEFAULT
	local path = defaults[new]
	if path then
		return deepcopy(retrieve(topDefault, path, level + 1))
	end

	-- UPDATE
	local updater = updates[new]
	if updater then
		return updater(deepcopy(default))
	end

	-- Merge
	if type(new) == "table" and type(default) == "table" then
		local merged = deepcopy(default)

		for k, v in pairs(new) do
			merged[k] = _resolve(merged[k], v, topDefault, level + 1)
		end

		return merged

	-- Override
	elseif new ~= nil then
		return deepcopy(new)

	-- Keep default
	else
		return deepcopy(default)
	end
end

local function resolve(default, new)
	if not verifySubtablesAreUnique(default) then
		error("repeated table in default config", 2)
	elseif not verifySubtablesAreUnique(new) then
		error("repeated table in incoming config", 2)
	end

	return _resolve(default, new, default, 2)
end


local function injectOne(name, value, env)
	if env[name] ~= nil and env[name] ~= value then
		error("name conflict when injecting into environment: " .. name, 3)
	else
		env[name] = value
	end
end

local function inject(env)
	injectOne("NIL", NIL, env)
	injectOne("SET", SET, env)
	injectOne("UPDATE", UPDATE, env)
	injectOne("DEFAULT", DEFAULT, env)
	return env
end


return {
	resolve = resolve,
	inject = inject,

	NIL = NIL,
	SET = SET,
	UPDATE = UPDATE,
	DEFAULT = DEFAULT,
}
