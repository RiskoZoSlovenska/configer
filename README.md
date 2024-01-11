# configer - A Configuration Merger for Lua

configer is small library for merging default and user-provided configs, allowing the user to only specify the things they want to change without having to copy the entire configuration.

For example, if some library uses a configuration that looks something like this:
```lua
{
	commands = {
		hello = {
			response = "Hello there!",
			color = "green",
		},
		goodbye = { ... },
		...
	},
	aliases = {
		hi = "hello",
		bye = "goodbye",
		...
	},
	cooldown = 5,
	...
}
```
and the user wants to change `commands.hello.response`, double the cooldown and rename `commands.goodbye` to `commands.farewell` without having to copy the entire configuration (which could be very long), they can just specify:
```lua
{
	commands = {
		hello = {
			response = "Greetings!",
		},
		goodbye = NIL,
		farewell = DEFAULT.commands.goodbye,
	},
	aliases = {
		bye = "farewell",
	},
	cooldown = UPDATE (function(old) return old * 2 end),
}
```



## Installation

Get it from [LuaRocks](https://luarocks.org/):

```
luarocks install configer
```

Needs Lua 5.2 or higher, but should also work under LuaJIT with compatibility options.



## Docs

configer can be required via
```lua
local configer = require("configer")
```
and contains the following functions and keywords as values.

### Functions

#### `configer.resolve(default, new, options)`

Takes a default configuration and a user-provided one and merges them. Normally, the operation is a simple deep merge --- values in `new` overwrite values in `default`, except if both the default value and the user value is a table, in which case they are recursively merged in the same manner --- but this behavior can be changed by the presence of [Keywords](#keywords).

This function does not modify `default` nor `new` and deepcopies any tables it uses from either source.

The `options` table may contain the following fields:
* `merger`: A function that can be used to copy or merge any custom objects that shouldn't be passed through configer's default copy function. The `merger` should take three values, `new`, `old` and `check`, and should return two values, `ok` and `res`. `new` is the **kept** *or* **incoming** value, `old` *may* be an existing value, and `check` is a boolean which is truthy if the function is being called only to determine if a certain value is an object or not (this information is used to prevent objects being checked for containing duplicate tables). If `ok` is truthy, configer takes `res` verbatim as the result of the merge; otherwise, the result of the merger is discarded and the value is copied/merged normally. As an example, a minimal merger function which just passes any custom objects through unaltered would look like this:
```lua
local function merger(new, old, _)
	return isCustomObject(new) or isCustomObject(old), new
end
```
A slightly more sophisticated a merger which also copies/merges objects will probably look like this:
```lua
local function merger(new, old, justChecking)
	local newIsCustom = isCustomObject(new)
	local oldIsCustom = isCustomObject(old)

	if justChecking then
		return newIsCustom or oldIsCustom, nil
	elseif newIsCustom and oldIsCustom then
		return true, mergeCustomObjects(new, old)
	elseif newIsCustom or oldIsCustom then
		return true, newIsCustom and copyCustomObject(new) or new
	end
end
```

#### `configer.inject(env)`

Injects the [Keywords](#keywords) into the provided environment, throwing an error if the environment already contains values under the same keys.

Returns `env`.


### Keywords

configer understands a set of keywords which dictate how user configurations are merged. Keywords are meant to be injected into the config loader environment by the library using configer. The only guarantees about values produced by keywords are that they are truthy and not primitive. Programs using configer should treat them as black boxes.

Keywords cannot be nested in any way. That is, they cannot be passed to `SET` or be returned from `UPDATE`.

#### `NIL`

Simply represents the `nil` value. Use this to remove values from the default config.

```lua
configer.resolve(
	{
		a = "b",
		c = "d",
	},
	{
		a = NIL,
	}
)
```
results in
```lua
{
	c = "d",
}
```

#### `UPDATE`

The `UPDATE` keyword takes a function and then uses it to modify the default value instead of blindly replacing it. Said function receives a deepcopy of the default value as the first argument and its return is used as the final value verbatim. Additional arguments may be supplied to the `UPDATE` keyword; they are passed directly to the function as additional arguments.

```lua
configer.resolve(
	{
		a = 40,
	},
	{
		a = UPDATE (function(x, n) return x + n end, 2),
	}
)
```
results in
```lua
{
	a = 42,
}
```

If the default value doesn't exist, such as when trying to merge a table value with a non-table one, the updater will receive `nil`.

#### `SET`

The `SET` keyword is meant to be used with tables to specify that the given table should completely overwrite the default value instead of being merged with it.

```lua
configer.resolve(
	{
		a = {
			b = "c",
		}
	},
	{
		a = SET {
			d = "e",
		}
	}
)
```
results in
```lua
{
	a = {
		d = "e",
	}
}
```

Note that `SET(nil)` is functionally identical to the `NIL` keyword.

#### `DEFAULT`

The `DEFAULT` keyword can be used to refer to members of the default configuration.

```lua
configer.resolve(
	{
		a = "3",
	},
	{
		b = DEFAULT.a,
	}
)
```
results in
```lua
{
	a = "3",
	b = "3",
}
```

Note that if the default value being referenced is a table, it will be deepcopied again. In other words, in the example above, if a table had been used instead of `"3"`, `result.a` and `result.b` would have different identities.


### Caveats, Exceptions and Limitations

* Metatables are never copied.
* Table keys are never copied.
* Every table in either config (default or user) must be unique. That is, using the same table object twice is not supported. This limitation doesn't apply to tables supplied to the `SET` keyword or returned via the `UPDATE` keyword. This is to avoid ambiguous cases such as the following:
```lua
local a = { b = "c" }

configer.resolve({
	a1 = a,
	a2 = a,
}, {
	a1 = {
		b = "c1",
	},
	a2 = {
		b = "c2",
	},
})
```



## Development

```
luarocks make && luarocks test
```
