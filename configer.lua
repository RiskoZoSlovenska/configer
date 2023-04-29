local function verifySubtablesAreUnique(tbl, merger, seen)
	seen = seen or {}

	if type(tbl) ~= "table" or (merger and merger(tbl, nil, true)) then
		return true
	elseif seen[tbl] then
		return false
	end

	seen[tbl] = true

	for _, v in pairs(tbl) do
		if not verifySubtablesAreUnique(v, merger, seen) then
			return false
		end
	end

	return true
end

local function deepcopy(tbl, merger, seen)
	if merger then
		local ok, copied = merger(tbl, nil)
		if ok then
			return copied
		end
	end

	if type(tbl) ~= "table" then
		return tbl
	end

	seen = seen or {}

	local new = {}
	seen[tbl] = new

	for k, v in pairs(tbl) do
		new[k] = seen[v] or deepcopy(v, merger, seen)
	end

	return new
end


local WEAK_META = { __mode = "k" }

local sets = setmetatable({}, WEAK_META)
local updates = setmetatable({}, WEAK_META)
local defaults = setmetatable({}, WEAK_META)

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

local UPDATE = function(updater, ...)
	return make(updates, {
		updater = updater,
		n = select("#", ...),
		...
	})
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
		local t = type(cur)
		if t ~= "table" then
			local pathString = "DEFAULT." .. table.concat(path, ".", 1, i)
			error(string.format("invalid DEFAULT access: %s (trying to index a %s)", pathString, t), level + 1)
		end
		cur = cur[key]
	end

	return cur
end

local function _resolve(default, new, merger, topDefault, level)
	-- NIL
	if new == NIL then
		return nil
	end

	-- SET
	local value = sets[new]
	if value ~= nil then
		return deepcopy(value, merger)
	end

	-- DEFAULT
	local path = defaults[new]
	if path then
		return deepcopy(retrieve(topDefault, path, level + 1), merger)
	end

	-- UPDATE
	local payload = updates[new]
	if payload then
		return payload.updater(deepcopy(default, merger), table.unpack(payload, 1, payload.n))
	end

	-- Merge
	if merger then
		local ok, merged = merger(new, default)
		if ok then
			return merged
		end
	end

	if type(new) == "table" and type(default) == "table" then
		local merged = {}

		-- Copy over all the values we're not merging
		for k, v in pairs(default) do
			if new[k] == nil then
				merged[k] = deepcopy(v, merger)
			end
		end

		-- Merge the remaining values
		for k, v in pairs(new) do
			merged[k] = _resolve(default[k], v, merger, topDefault, level + 1)
		end

		return merged

	-- Override
	elseif new ~= nil then
		return deepcopy(new, merger)

	-- Keep default
	else
		return deepcopy(default, merger)
	end
end

local function resolve(default, new, options)
	local merger = options and options.merger or nil

	if not verifySubtablesAreUnique(default, merger) then
		error("repeated table in default config", 2)
	elseif not verifySubtablesAreUnique(new, merger) then
		error("repeated table in incoming config", 2)
	end

	return _resolve(default, new, merger, default, 2)
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
