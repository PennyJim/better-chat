--MARK: Setup
local min, insert, unpack = math.min, table.insert, table.unpack
local any_character = (":"):byte()

---@class Levenshtein.state : {[int]:int}

---@class Levenshtein.self
---@field string string
---@field max_cost int

---@param string string
---@param n int
---@return Levenshtein.self
local function __init__(string, n)
  return {
    string = string,
    max_cost = n
  }
end

---@param self Levenshtein.self
---@return Levenshtein.state
local function start(self)
  local state = {}
  for cost = 1, #self.string+1, 1 do
    insert(state, cost-1)
  end
  return state
end

--MARK: Internal functions

---@param self Levenshtein.self
---@param state Levenshtein.state
---@param character int
local function step(self, state, character)
  local cost, string, max = 0, self.string, self.max_cost+1
  local new_state = {min(state[1]+1, max)}
  for index = 1, #state-1, 1 do
    cost = string:byte(index) == character and 0 or 1
    insert(new_state, min(
      new_state[index]+1,
      state[index+1]+1,
      state[index]+cost,
      max
    ))
  end
  return new_state
end

---@param self Levenshtein.self
---@param state Levenshtein.state
---@return int? distance how far it is from the match if it is one
local function is_match(self, state)
  local distance = state[#state]
  if distance <= self.max_cost then
    return distance
  end
end

---@param self Levenshtein.self
---@param state Levenshtein.state
---@return int? distance how far it is from the match if it can
local function can_match(self, state)
  local smallest = min(unpack(state))
  if smallest <= self.max_cost then
    return smallest
  end
end

---@param self Levenshtein.self
---@param state Levenshtein.state
---@return int[]
local function get_transitions(self, state)
  local string, max_cost = self.string, self.max_cost
  local set, cost = {}, 0
  ---@type {[int]:true}
  local chars, char = {}, 0
  insert(set, 1,  any_character)
  for i = 1, #string, 1 do
    if state[i] <= max_cost then
      char = string:byte(i)
      if not chars[char] then
        chars[char] = true
        insert(set, string:byte(i))
      end
    end
  end
  return set
end

-- ---@type {[int]:Levenshtein.state}, int
-- local states, counter = {}, 0
-- ---@type {[1]:int,[2]:int,[3]:int}[]
-- local transitions = {}
-- ---@type {[int]:int}, {[int]:string}
-- local match_distance, match_value = {}, {}

---@class Levenshtein.state_lookup.base : Levenshtein.state_lookup
---@field counter int
---@class Levenshtein.state_lookup : {[uint]: Levenshtein.state_lookup}
---@field state int?

---@param state Levenshtein.state
---@param state_lookup Levenshtein.state_lookup.base
---@return int
local function find_lookup(state, state_lookup)
  ---@type Levenshtein.state_lookup, Levenshtein.state_lookup?
  local cur_table, next_table = state_lookup, nil
  for _, state_value in pairs(state) do
    next_table = cur_table[state_value]--[[@as Levenshtein.state_lookup?]] or {}
    cur_table[state_value] = next_table

    cur_table = next_table
  end

  local state_id = cur_table.state
  if state_id then
    return state_id
  else
    local counter = state_lookup.counter + 1
    state_lookup.counter = counter
    cur_table.state = counter
    return counter
  end
end

---@class Levenshtein.transition
---@field [1] int The initial state
---@field [2] int The next state
---@field [3] int The byte value of the character

---@class Levenshtein.match
---@field [1] string The matching value
---@field [2] int The distance to the match

---@param self Levenshtein.self
---@param state Levenshtein.state
---@param states Levenshtein.state[]
---@param state_lookup Levenshtein.state_lookup.base
---@param transitions Levenshtein.transition
---@param matches table<int,Levenshtein.match>
---@return integer
local function explore(self, state, states, state_lookup, transitions, matches)
  local state_index = find_lookup(state, state_lookup) --somehow hash?
  if states[state_index] then return state_index end
  states[state_index] = state

  local cur_match_distance = is_match(self, state)
  if cur_match_distance then
    matches[state_index] = {self.string, cur_match_distance}
  end

  local next_chars = get_transitions(self, state)
  ---@type Levenshtein.state, int
  local next_state, next_index
  for _, character in pairs(next_chars) do
    next_state = step(self, state, character)
    next_index = explore(self, next_state, states, state_lookup, transitions, matches)
    insert(transitions, {state_index, next_index, character})
  end
  return state_index
end

--MARK: External functions

---@class Levenshtein
local automation = {}

---@class Levenshtein.tree : {[int]:table<int,int>}
---@field matching table<int,Levenshtein.match>

---Add values to the tree, the keys of a table
---@param input string
---@return Levenshtein.tree
function automation.generate_tree(input)
  local self = __init__(input, 2)
  ---@type Levenshtein.transition[], table<int,Levenshtein.match>
  local transitions, matches = {}, {}

  explore(self, start(self), {}, {counter=0}, transitions, matches)

  ---@type Levenshtein.tree
  local tree = {
    matching = matches
  }
  for _, transition in pairs(transitions) do
    local node = tree[transition[1]] or {}
    tree[transition[1]] = node
    node[transition[3]] = transition[2]
  end
  return tree
end

---Get which string in the tree the input is closest to
---@param input string
---@param tree Levenshtein.tree
---@return Levenshtein.match?
---@nodiscard
function automation.match(input, tree)
  local state_index = 1
  for _, character in pairs{input:byte()} do
    state_index = tree[state_index][character]

    if not state_index then
      return
    end
  end

  return tree.matching[state_index]
end











local words = {
  "woof",
  "Another string",
  "For more testing",
  "Because I need lots of words",
  "construction_robot",
  "wood",
}

local mispelling = {
  "wof",
  "woof",
  "wppf",
  "Anotherstring",
  "another strings",
  "becuase I need lots of words",
  "because I need lots if words",
  "bcause I need ltos of words",
  "construction_rbot",
  "construction_bot",
  "constuction_rbot",
  "construction_robots",
  "wood",
  "Woog",
  "wod",
  "wppd",

}

for _, word in pairs(mispelling) do
  local tree = automation.generate_tree(word)
  local min_distance, cur_word = math.huge, nil
  for _, query in pairs(words) do
    if #query + 3 >= tree.length
    or #query - 3 <= tree.length then
      local distance = automation.match(query, tree)
      if distance and distance < min_distance then
        min_distance = distance
        cur_word = query
      end
    end
  end

  print(min_distance, word, "->", cur_word)
end


-- local tree = convert_to_tree()

-- print(automation.find("wand", tree))
-- print(automation.find("wood", tree))

-- print(automation.find("wand", tree))
-- print(automation.find("wood", tree))
-- print(automation.find("woog", tree))
-- print(automation.find("another sure", tree))
-- print(automation.find("fer more testing", tree))
-- print(automation.find("MORE", tree))
-- print(automation.find("Because I kind of assume that to be untrue...", tree))

-- table.sort(transitions, function (a, b)
--   if a[1] ~= b[1] then return a[1] < b[1] end
--   if a[3] ~= b[3] then return a[3] < b[3] end
--   return a[2] < b[2]
-- end)

-- for index, transition in pairs(transitions) do
--   while table.compare(transition, transitions[index+1] or {}) do
--     table.remove(transitions, index+1)
--   end
-- end

-- print("digraph G {")
-- for _, transition in pairs(transitions) do
--   print(string.format('%s -> %s [label=" %s "]', transition[1]-1, transition[2]-1, transition[3]))
-- end
-- for _, match in pairs(match_distance) do
--   print(string.format('%s [style=filled]', match-1))
-- end
-- print("}")


return automation