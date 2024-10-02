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

--MARK: Single Tree

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

---MARK: Multi-Tree

---@param trees Levenshtein.tree[]
---@param cur_state Levenshtein.state
---@param character int
---@return table<int,int> new_state
local function merge_step(trees, cur_state, character)
  ---@type table<int,int>
  local new_states = {}
  ---@type table<int,int>, int?
  local individual_steps, individual_state
  for index, cur_state in pairs(cur_state) do
    -- If the state is invalid, set it and skip
    if cur_state == -10 then
      new_states[index] = -10
      goto continue
    end

    -- Increment the state
    individual_steps = trees[index][cur_state]
    individual_state = individual_steps[character]
    -- Default to `any_character` if the given character does not have a transition
    if not individual_state then individual_state = individual_steps[any_character] end
    -- And only use the new state if it's not looping
    if individual_state ~= cur_state then
      new_states[index] = individual_state
    else
      new_states[index] = -10
    end

    ::continue::
  end
  return new_states
end

---@param trees Levenshtein.tree[]
---@param state Levenshtein.state
---@param state_list table<int,Levenshtein.state>
---@param states_lookup Levenshtein.state_lookup.base
---@param transitions Levenshtein.transition[]
---@param matching table<int,Levenshtein.match>
local function merge_explore(trees, state, state_list, states_lookup, transitions, matching)
  -- Cache the state
  local state_index = find_lookup(state, states_lookup)
  if state_list[state_index] then return state_index end
  state_list[state_index] = state

  --- Keep variable allocation out of the loop
  ---@type table<int,Levenshtein.match>, table<int,true>
  local possible_matches, next_characters = {}, {[any_character]=true}
  ---@type Levenshtein.tree, {[1]:string,[2]:int}
  local cur_tree, match

  for index, individual_state in pairs(state) do
    -- Skip and ignore invalid states
    if individual_state == -10 then goto continue end

    cur_tree = trees[index]
    -- Check if it now matches
    match = cur_tree.matching[individual_state]
    if match then
      possible_matches[index] = match
    end

    -- Record all possible steps forward
    for character in pairs(cur_tree[individual_state]) do
      next_characters[character] = true
    end

    ::continue::
  end

  -- Choose the closest match
  local min_match, min_distance = nil, math.huge
  for index, match in pairs(possible_matches) do
    if match[2] < min_distance then
      min_match, min_distance = match[1], match[2]
    end
  end
  if min_match then
    matching[state_index] = {min_match, min_distance}
  end

  ---@type Levenshtein.state, int
  local next_state, next_state_index
  for next_character in pairs(next_characters) do
    next_state = merge_step(trees, state, next_character)
    next_state_index = merge_explore(trees, next_state, state_list, states_lookup, transitions, matching)
    insert(transitions, {state_index, next_state_index, next_character})
  end

  return state_index
end

---Merge an array of given trees into a single tree
---@param trees Levenshtein.tree[]
function automation.merge_trees(trees)

  ---For exploring
  ---@type table<int,Levenshtein.match>, Levenshtein.transition[]
  local matching, transitions = {}, {}

  --Make the new initial state
  ---@type Levenshtein.state
  local initial_state = {}
  for index in pairs(trees) do
    initial_state[index] = 1
  end

  merge_explore(trees, initial_state, {}, {counter=0}, transitions, matching)

  ---@type Levenshtein.tree
  local new_tree = {
    -- length = #input,
    matching = matching
  }
  for _, transition in pairs(transitions) do
    local node = new_tree[transition[1]] or {}
    new_tree[transition[1]] = node
    node[transition[3]] = transition[2]
  end
  return new_tree
end

--MARK: Debug visualizer

---@param graph_name string
---@param tree Levenshtein.tree
function automation.to_graphviz(graph_name, tree)
  local output = {'digraph "'..graph_name..'" {'}

  for start_node, transition in pairs(tree) do
    if type(start_node) ~= "number" then goto continue end

    for character, end_node in pairs(transition) do
      insert(output, string.format('%s -> %s [label=" %s "]', start_node, end_node, string.char(character)))
    end

    ::continue::
  end

  ---@type table<string,int>
  result_to_color = {}
  colors = {
    "#00ff00",
    "#0000ff",
    "#ff0000",
    "#ff00ff",
    "#ffff00",
    "#00ffff",
  }
  last_used_color = 0

  for state, match in pairs(tree.matching) do
    local color = result_to_color[match[1]]
    if not color then
      last_used_color = last_used_color + 1
      result_to_color[match[1]] = last_used_color
      color = last_used_color
    end
    insert(output, string.format('%s [label="%s:%s" color="%s" style=filled]', state, match[1], match[2], colors[color]))
  end
  insert(output, "}")
  return table.concat(output, "\n")
end

return automation