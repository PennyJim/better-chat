--MARK: Setup
local min, insert, unpack, concat, huge = math.min, table.insert, table.unpack, table.concat, math.huge
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

---@class Levenshtein.state_lookup : {[string]: int?}
---@field counter int

---@param state Levenshtein.state
---@param state_lookup Levenshtein.state_lookup
---@return int state_index
---@return boolean is_cached
local function find_lookup(state, state_lookup)
  local index = concat(state, ":")
  local state_id = state_lookup[index]

  if state_id then
    return state_id, true
  else
    local counter = state_lookup.counter + 1
    state_lookup.counter = counter
    state_lookup[index] = counter
    return counter, false
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
---@param state_lookup Levenshtein.state_lookup
---@param transitions Levenshtein.transition
---@param matches table<int,Levenshtein.match>
---@return integer
local function explore(self, state, state_lookup, transitions, matches)
  local state_index, is_cached = find_lookup(state, state_lookup) --somehow hash?
  if is_cached then return state_index end

  local cur_match_distance = is_match(self, state)
  if cur_match_distance then
    matches[state_index] = {self.string, cur_match_distance}
  end

  local next_chars = get_transitions(self, state)
  ---@type Levenshtein.state, int
  local next_state, next_index
  for _, character in pairs(next_chars) do
    next_state = step(self, state, character)
    next_index = explore(self, next_state, state_lookup, transitions, matches)
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

  explore(self, start(self), {counter=0}, transitions, matches)

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
---@return table<string,int> transitions
---@return Levenshtein.match[] matching
local function merge_explore(trees)
  ---@type Levenshtein.state_lookup
  local states_lookup = {counter=0}
  ---@type table<string,int>
  local transitions = {}
  ---@type table<int,Levenshtein.match>
  local matching = {}

  --Make the initial state
  ---@type Levenshtein.state, Levenshtein.state
  local state, next_state = {}, {}
  for index in pairs(trees) do
    state[index] = 1
  end

  ---@class Levenshtein.job : Levenshtein.transition
  ---@field [2] Levenshtein.state Current State
  ---@field [4] string Source path
  ---@type string
  local next_path = ""
  ---@type Levenshtein.job[]
  local jobs, num_jobs = {
    {0, state, 0, ""}
  }, 1
  local inext = ipairs(jobs)
  local job_index, current_job = inext(jobs, 0)


  --- Keep variable allocation out of the loop

  ---@type int, boolean
  local state_index, is_cached

  ---@type table<int,Levenshtein.match>, table<int,true>
  local possible_matches, next_characters = {}, {[any_character]=true}
  ---@type Levenshtein.tree, {[1]:string,[2]:int}
  local cur_tree, match
  local min_match, min_distance = nil, huge

  while current_job do
    state = current_job[2]
    state_index, is_cached = find_lookup(state, states_lookup)
    if is_cached then
      goto merge_continue --Merge Continue also adds the transition
    end

    -- Process each state
    for index, individual_state in pairs(state) do
      -- Skip and ignore invalid states
      if individual_state == -10 then goto individual_continue end

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

      ::individual_continue::
    end

  -- Choose the closest match
    for index, match in pairs(possible_matches) do
      if match[2] < min_distance then
        min_match, min_distance = match[1], match[2]
      end
    end
    if min_match then
      matching[state_index] = {min_match, min_distance}
    end

    next_path = current_job[4]..string.char(current_job[3])
    for next_character in pairs(next_characters) do
      next_state = merge_step(trees, state, next_character)
      num_jobs = num_jobs + 1
      jobs[num_jobs] = {state_index, next_state, next_character, next_path}
    end

    ::merge_continue::
    -- print("Job "..job_index..": "..current_job[4].."("..current_job[1]..") -> "..next_path.."("..state_index..")")
    io.stderr:write("\27[2k\rDone: "..(100*job_index/num_jobs).."%")

    local key = current_job[1]..":"..state_index
    if transitions[key] then
      transitions[key] = any_character
    else
      transitions[key] = current_job[3]
    end

    -- Remove job from list and get the next job
    jobs[job_index] = nil
    job_index, current_job = inext(jobs, job_index)

    if not current_job then
      print("Finished??")
    end

    -- Reset tables
    possible_matches, next_characters = {}, {[any_character]=true}
    min_match, min_distance = nil, huge
  end

  -- First transition is a dummy transition.
  transitions["0:1"] = nil

  return transitions, matching
end

---Merge an array of given trees into a single tree
---@param trees Levenshtein.tree[]
function automation.merge_trees(trees)

  -- collectgarbage("generational")
  local transitions, matching = merge_explore(trees)
  -- collectgarbage("incremental")

  ---@type Levenshtein.tree
  local new_tree = {
    matching = matching
  }
  ---@type int, int, int
  local colon, start, destination
  for transition, character in pairs(transitions) do
    colon = transition:find(":") --[[@as int]]
    start = tonumber(transition:sub(1, colon-1))--[[@as int]]
    destination = tonumber(transition:sub(colon+1))--[[@as int]]
    local node = new_tree[start] or {}
    new_tree[start] = node
    node[character] = destination
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
      insert(output, string.format('%s->%s[label="%s"]', start_node, end_node, string.char(character)))
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
    insert(output, string.format('%s[label="%s:%s"color="%s"style=filled]', state, match[1], match[2], colors[color]))
  end
  insert(output, "}")
  return concat(output, "\n")
end

-- local dynamic = automation.generate_tree("dynamic")
-- local dynamo = automation.generate_tree("dynamo")
-- local terrific = automation.generate_tree("terrific")

-- print(automation.to_graphviz("G", automation.merge_trees{
--   dynamic, dynamo, terrific
-- }))

return automation