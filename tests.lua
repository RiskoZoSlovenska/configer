local configer = require("configer")
local resolve = configer.resolve

configer.inject(_G)


---@diagnostic disable: undefined-global, need-check-nil
describe("configer", function()
	it("should be capable of injecting the keywords into an environment", function()
		local env = configer.inject({})

		assert.are.equal(NIL, env.NIL)
		assert.are.equal(SET, env.SET)
		assert.are.equal(UPDATE, env.UPDATE)
		assert.are.equal(DEFAULT, env.DEFAULT)

		assert.has.no.error(function() configer.inject(env) end)
	end)

	it("should not overwrite existing environment values when injecting", function()
		assert.has.error(function() configer.inject({ NIL = true }) end, "name conflict when injecting into environment: NIL")
		assert.has.error(function() configer.inject({ SET = true }) end, "name conflict when injecting into environment: SET")
		assert.has.error(function() configer.inject({ UPDATE = true }) end, "name conflict when injecting into environment: UPDATE")
		assert.has.error(function() configer.inject({ DEFAULT = true }) end, "name conflict when injecting into environment: DEFAULT")
	end)

	describe("NIL keyword", function()
		it("shouldn't be nil", function()
			assert.is.not_nil(NIL)
		end)

		it("should set default values to nil", function()
			assert.are.same({}, resolve({ a = 1 }, { a = NIL }))
		end)
	end)

	describe("UPDATE keyword", function()
		it("should update default values", function()
			assert.are.same(4, resolve(3, UPDATE (function(x) return x + 1 end)))
			assert.are.same(nil, resolve({}, UPDATE (function() return nil end)))
			assert.are.same({}, resolve(nil, UPDATE (function() return {} end)))
		end)

		it("should not actually modify the default table", function()
			local default = {}
			local resolved = resolve(default, UPDATE (function(t) t[1] = "hi" return 1 end))

			assert.are.same(1, resolved)
			assert.are.same({}, default)
		end)

		it("should copy its return values properly", function()
			local resolved = resolve(nil, UPDATE (function()
				local t1 = {}
				local t2 = { t1, t1 }
				t2[3] = t2

				return t2
			end))

			assert.are.equal(resolved[1], resolved[2])
			assert.are.equal(resolved, resolved[3])
			assert.are.not_equal(resolved, resolved[1])
		end)

		it("should pass extra arguments to the updater verbatim", function()
			local a, b = 3, {}
			local func = function(val, c, d)
				assert.are.equal(b, d)
				return val + c
			end

			assert.are.same({ a = 5 }, configer.resolve({ a = 2 }, { a = UPDATE(func, a, b) }))
		end)

		it("should pass the same number of extra arguments to the updater as it was given", function()
			configer.resolve(nil, UPDATE(function(_, ...)
				assert.are.same(5, select("#", ...))
			end, nil, nil, true, nil, nil))
		end)
	end)

	describe("SET keyword", function()
		it("should prevent tables from being merged", function()
			assert.are.same({ b = 2 }, resolve({ a = 1 }, SET { b = 2 }))
			assert.are.same({
				a = {
					b = 1
				},
				c = 3
			}, resolve({
				a = {
					a = 2
				},
				c = 3,
			}, {
				a = SET {
					b = 1,
				},
			}))
		end)

		it("should work on normal values, including nil", function()
			assert.are.same(resolve(nil, 3), resolve(nil, SET(3)))
			assert.are.same(resolve(3, NIL), resolve(3, SET(nil)))
		end)

		it("should copy tables properly", function()
			local t1 = {}
			local t2 = { t1, t1 }
			t2[3] = t2

			local resolved = resolve(nil, SET(t2))

			assert.are.equal(resolved[1], resolved[2])
			assert.are.equal(resolved, resolved[3])
			assert.are.not_equal(resolved, resolved[1])
		end)
	end)

	describe("DEFAULT keyword", function()
		it("should work when not indexed", function()
			assert.are.same({
				a = {
					a = 2
				},
			}, resolve({
				a = 2,
			}, {
				a = DEFAULT,
			}))
		end)

		it("should work when given a path", function()
			assert.are.same({
				b = {
					b = "3",
					c = { "4", "5" },
					[".\\"] = "6",
				},
				a = "3",
				c = "5",
				d = "6",
			}, resolve({
				a = {
					b = "3",
					c = { "4", "5" },
					[".\\"] = "6",
				},
			}, {
				b = DEFAULT.a,
				a = DEFAULT.a.b,
				c = DEFAULT.a.c[2],
				d = DEFAULT.a[".\\"],
			}))
		end)

		it("should error when given an invalid path", function()
			assert.has.error(function()
				resolve(3, DEFAULT.a.b)
			end, "invalid DEFAULT access: DEFAULT.a (trying to index a number)")
			assert.has.error(function()
				resolve({ a = "hi" }, { b = DEFAULT.a.c.d })
			end, "invalid DEFAULT access: DEFAULT.a.c (trying to index a string)")
		end)
	end)


	it("should resolve basic primitive configs", function()
		assert.are.same(2, resolve(3, 2))
		assert.are.same(4, resolve(3, UPDATE (function(x) return x + 1 end)))
		assert.are.same(nil, resolve(3, NIL))
		assert.are.same(3, resolve(3, nil))
	end)

	it("should resolve table configs", function()
		assert.are.same({
			hi = "there",
			a = "b",
			c = false,
			d = {
				e = "e2",
				test = {},
			},
			g = {
				quite = "uncool",
			},
			h = nil,
			i = {},
		}, resolve({
			a = "b",
			c = true,
			d = {
				e = {},
			},
			g = {
				pretty = "cool",
			},
			h = "yes",
			i = 2,
		}, {
			hi = "there",
			c = UPDATE (function(bool) return not bool end),
			d = {
				e = "e2",
				test = DEFAULT.d.e,
			},
			g = SET {
				quite = "uncool",
			},
			h = NIL,
			i = {},
		}))
	end)

	it("should allow a custom merger", function()
		local objs = {}
		local sharedTbl = {}

		local function newObj(isMerge)
			local obj = { sharedTbl, merged = isMerge }
			objs[obj] = true
			return obj
		end

		local function isObj(obj)
			return objs[obj] ~= nil
		end


		local def = {
			a = "idk",
			b = newObj(),
			c = newObj(),
			d = newObj(),
			e = newObj(),
		}

		local inpSetObj = newObj()
		local inp = {
			a = newObj(),
			b = newObj(),
			c = NIL,
			d = "yes",
			e = SET(inpSetObj),
		}

		local out = resolve(def, inp, {
			isObject = isObj,
			merger = function(new, old, justChecking)
				if justChecking then
					return isObj(new), nil
				elseif isObj(old) and isObj(new) then
					return true, newObj(true)
				elseif isObj(new) then
					return true, newObj()
				end
			end,
		})


		assert.are.same({
			a = { sharedTbl },
			b = { sharedTbl, merged = true },
			c = nil,
			d = "yes",
			e = { sharedTbl },
		}, out)
		assert.are.not_equal(out.a, inp.a)
		assert.are.not_equal(out.b, def.b)
		assert.are.not_equal(out.b, inp.b)
		assert.are.not_equal(out.e, def.e)
		assert.are.not_equal(out.e, inpSetObj)
		assert.is.truthy(isObj(out.a))
		assert.is.truthy(isObj(out.b))
		assert.is.truthy(isObj(out.e))
	end)

	it("should copy values properly in general", function()
		local t1_1 = {}
		local t1 = { t1_1 }

		local resolved = resolve(nil, t1)
		local resolvedNil = resolve(t1, nil)
		local resolvedSet = resolve(t1, SET(t1))
		local resolvedUpdate = resolve(t1, UPDATE(function(x) return x end))
		local resolvedDefault = resolve(t1, DEFAULT)
		local resolvedDoubleDefault = resolve({
			a = {},
		}, {
			b = DEFAULT.a,
			c = DEFAULT.a,
		})

		assert.are.not_equal(t1,   resolved, "normal")
		assert.are.not_equal(t1_1, resolved[1], "normal (child)")
		assert.are.not_equal(t1,   resolvedNil, "with nil")
		assert.are.not_equal(t1_1, resolvedNil[1], "with nil (child)")
		assert.are.not_equal(t1,   resolvedSet, "with SET")
		assert.are.not_equal(t1_1, resolvedSet[1], "with SET (child)")
		assert.are.not_equal(t1,   resolvedUpdate, "with UPDATE")
		assert.are.not_equal(t1_1, resolvedUpdate[1], "with UPDATE (child)")
		assert.are.not_equal(t1,   resolvedDefault, "with DEFAULT")
		assert.are.not_equal(t1_1, resolvedDefault[1], "with DEFAULT (child)")

		assert.are.not_equal(resolvedDoubleDefault.a, resolvedDoubleDefault.b)
		assert.are.not_equal(resolvedDoubleDefault.a, resolvedDoubleDefault.c)
		assert.are.not_equal(resolvedDoubleDefault.b, resolvedDoubleDefault.c)
	end)

	it("should error when tables contain duplicates", function()
		local t1 = {}
		local t2_1, t2_2, t2_3 = { t1 }, { t1 }, { [2] = t1 }
		local t3 = { t1, t1 }
		local t4 = {}
		t4[1] = t4

		assert.has.error(function() resolve(t3, nil) end, "repeated table in default config")
		assert.has.error(function() resolve(t4, nil) end, "repeated table in default config")
		assert.has.error(function() resolve(nil, t3) end, "repeated table in incoming config")
		assert.has.error(function() resolve(nil, t4) end, "repeated table in incoming config")
		assert.has.no.error(function() resolve(t1, t1) end)
		assert.has.no.error(function() resolve(t2_1, t2_2) end)
		assert.has.no.error(function() resolve(t2_1, t2_3) end)
	end)

	it("should not prevent keyword-created values from being GC'd", function()
		local tbl = setmetatable({
			[1] = {}, -- Control case
			[2] = SET({}),
			[3] = UPDATE(function() end),
			[4] = DEFAULT.value,
		}, { __mode = "v" })

		collectgarbage()
		collectgarbage()

		assert.is_nil(tbl[1], "control table was not GC'd")
		assert.is_nil(tbl[2], "SET-created value was not GC'd")
		assert.is_nil(tbl[3], "UPDATE-created value was not GC'd")
		assert.is_nil(tbl[4], "DEFAULT-created value was not GC'd")
	end)
end)
