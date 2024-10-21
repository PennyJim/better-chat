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
  ---@type int, int
  local state_index, next_state = 1, 1
  ---@type table<int,int>
  local current_state
  for _, character in pairs{input:byte(1, -1)} do
    current_state = tree[state_index]
    next_state = current_state[character]
    if not next_state then
      next_state = current_state[any_character]
    end

    if next_state == state_index then
      break
    end

    state_index = next_state
  end

  return tree.matching[state_index]
end

---MARK: Multi-Tree

-- ---@param trees Levenshtein.tree[]
-- ---@param cur_state Levenshtein.state
-- ---@param character int
-- ---@return table<int,int> new_state
-- local function merge_step(trees, cur_state, character)
--   ---@type table<int,int>
--   local new_states = {}
--   ---@type table<int,int>, int?
--   local individual_steps, individual_state
--   for index, cur_state in pairs(cur_state) do
--     -- If the state is invalid, set it and skip
--     if cur_state == -10 then
--       new_states[index] = -10
--       goto continue
--     end

--     -- Increment the state
--     individual_steps = trees[index][cur_state]
--     individual_state = individual_steps[character]
--     -- Default to `any_character` if the given character does not have a transition
--     if not individual_state then individual_state = individual_steps[any_character] end
--     -- And only use the new state if it's not looping
--     if individual_state ~= cur_state then
--       new_states[index] = individual_state
--     else
--       new_states[index] = -10
--     end

--     ::continue::
--   end
--   return new_states
-- end

-- ---@param trees Levenshtein.tree[]
-- ---@return table<string,int> transitions
-- ---@return Levenshtein.match[] matching
-- local function merge_explore(trees)
--   ---@type Levenshtein.state_lookup
--   local states_lookup = {counter=0}
--   ---@type table<string,int>
--   local transitions = {}
--   ---@type table<int,Levenshtein.match>
--   local matching = {}

--   --Make the initial state
--   ---@type Levenshtein.state, Levenshtein.state
--   local state, next_state = {}, {}
--   for index in pairs(trees) do
--     state[index] = 1
--   end

--   ---@class Levenshtein.job : Levenshtein.transition
--   ---@field [2] Levenshtein.state Current State
--   ---@field [4] string Source path
--   ---@type string
--   local next_path = ""
--   ---@type Levenshtein.job[]
--   local jobs, num_jobs = {
--     {0, state, 0, ""}
--   }, 1
--   local inext = ipairs(jobs)
--   local job_index, current_job = inext(jobs, 0)


--   --- Keep variable allocation out of the loop

--   ---@type int, boolean
--   local state_index, is_cached

--   ---@type table<int,Levenshtein.match>, table<int,true>
--   local possible_matches, next_characters = {}, {[any_character]=true}
--   ---@type Levenshtein.tree, {[1]:string,[2]:int}
--   local cur_tree, match
--   local min_match, min_distance = nil, huge

--   local last_printed_percentage = -1000

--   while current_job do
--     state = current_job[2]
--     state_index, is_cached = find_lookup(state, states_lookup)
--     if is_cached then
--       goto merge_continue --Merge Continue also adds the transition
--     end

--     -- Process each state
--     for index, individual_state in pairs(state) do
--       -- Skip and ignore invalid states
--       if individual_state == -10 then goto individual_continue end

--       cur_tree = trees[index]
--       -- Check if it now matches
--       match = cur_tree.matching[individual_state]
--       if match then
--         possible_matches[index] = match
--       end

--       -- Record all possible steps forward
--       for character in pairs(cur_tree[individual_state]) do
--         next_characters[character] = true
--       end

--       ::individual_continue::
--     end

--   -- Choose the closest match
--     for index, match in pairs(possible_matches) do
--       if match[2] < min_distance then
--         min_match, min_distance = match[1], match[2]
--       end
--     end
--     if min_match then
--       matching[state_index] = {min_match, min_distance}
--     end

--     next_path = current_job[4]..string.char(current_job[3])
--     for next_character in pairs(next_characters) do
--       next_state = merge_step(trees, state, next_character)
--       num_jobs = num_jobs + 1
--       jobs[num_jobs] = {state_index, next_state, next_character, next_path}
--     end

--     ::merge_continue::
--     -- print("Job "..job_index..": "..current_job[4].."("..current_job[1]..") -> "..next_path.."("..state_index..")")
--     if (job_index - last_printed_percentage) >= 1000 then
--       last_printed_percentage = job_index
--       -- For testing:
--       -- io.write("\27[2k\rDone: "..(100*job_index/num_jobs).."%")
--     end

--     local key = current_job[1]..":"..state_index
--     if transitions[key] then
--       transitions[key] = any_character
--     else
--       transitions[key] = current_job[3]
--     end

--     -- Remove job from list and get the next job
--     jobs[job_index] = nil
--     job_index, current_job = inext(jobs, job_index)

--     -- Reset tables
--     possible_matches, next_characters = {}, {[any_character]=true}
--     min_match, min_distance = nil, huge
--   end

--   -- Exit the line we've been rewriting with io.write
--   print("")
--   -- First transition is a dummy transition.
--   transitions["0:1"] = nil

--   return transitions, matching
-- end

-- ---Merge an array of given trees into a single tree
-- ---@param trees Levenshtein.tree[]
-- function automation.merge_trees(trees)

--   -- collectgarbage("generational")
--   local transitions, matching = merge_explore(trees)
--   -- collectgarbage("incremental")

--   ---@type Levenshtein.tree
--   local new_tree = {
--     matching = matching
--   }
--   ---@type int, int, int
--   local colon, start, destination
--   for transition, character in pairs(transitions) do
--     colon = transition:find(":") --[[@as int]]
--     start = tonumber(transition:sub(1, colon-1))--[[@as int]]
--     destination = tonumber(transition:sub(colon+1))--[[@as int]]
--     local node = new_tree[start] or {}
--     new_tree[start] = node
--     node[character] = destination
--   end
--   return new_tree
-- end

--MARK: Debug visualizer

---@param file_path string
---@param tree Levenshtein.tree
function automation.to_graphviz(file_path, tree)
---@diagnostic disable-next-line: undefined-global, no-unknown
  if not io then
    error("This function is used for testing. Do not call within factorio")
  else
---@diagnostic disable-next-line: no-unknown
    io = io
  end
---@diagnostic disable-next-line: no-unknown
  local file = io.open(file_path, "w")
  file:write("digraph G {\n")

  for start_node, transition in pairs(tree) do
    if type(start_node) ~= "number" then goto continue end

    for character, end_node in pairs(transition) do
      file:write(string.format('%s->%s[label="%s"]\n', start_node, end_node, string.char(character)))
    end

    ::continue::
  end

  ---@type table<string,int>
  result_to_color = {}
  ---@type string[]
  colors = {
    "aliceblue", 	"antiquewhite", 	"antiquewhite1", 	"antiquewhite2", 	"antiquewhite3",
    "antiquewhite4", 	"aqua", 	"aquamarine", 	"aquamarine1", 	"aquamarine2",
    "aquamarine3", 	"aquamarine4", 	"azure", 	"azure1", 	"azure2",
    "azure3", 	"azure4", 	"beige", 	"bisque", 	"bisque1",
    "bisque2", 	"bisque3", 	"bisque4", 	"black", 	"blanchedalmond",
    "blue", 	"blue1", 	"blue2", 	"blue3", 	"blue4",
    "blueviolet", 	"brown", 	"brown1", 	"brown2", 	"brown3",
    "brown4", 	"burlywood", 	"burlywood1", 	"burlywood2", 	"burlywood3",
    "burlywood4", 	"cadetblue", 	"cadetblue1", 	"cadetblue2", 	"cadetblue3",
    "cadetblue4", 	"chartreuse", 	"chartreuse1", 	"chartreuse2", 	"chartreuse3",
    "chartreuse4", 	"chocolate", 	"chocolate1", 	"chocolate2", 	"chocolate3",
    "chocolate4", 	"coral", 	"coral1", 	"coral2", 	"coral3",
    "coral4", 	"cornflowerblue", 	"cornsilk", 	"cornsilk1", 	"cornsilk2",
    "cornsilk3", 	"cornsilk4", 	"crimson", 	"cyan", 	"cyan1",
    "cyan2", 	"cyan3", 	"cyan4", 	"darkblue", 	"darkcyan",
    "darkgoldenrod", 	"darkgoldenrod1", 	"darkgoldenrod2", 	"darkgoldenrod3", 	"darkgoldenrod4",
    "darkgray", 	"darkgreen", 	"darkgrey", 	"darkkhaki", 	"darkmagenta",
    "darkolivegreen", 	"darkolivegreen1", 	"darkolivegreen2", 	"darkolivegreen3", 	"darkolivegreen4",
    "darkorange", 	"darkorange1", 	"darkorange2", 	"darkorange3", 	"darkorange4",
    "darkorchid", 	"darkorchid1", 	"darkorchid2", 	"darkorchid3", 	"darkorchid4",
    "darkred", 	"darksalmon", 	"darkseagreen", 	"darkseagreen1", 	"darkseagreen2",
    "darkseagreen3", 	"darkseagreen4", 	"darkslateblue", 	"darkslategray", 	"darkslategray1",
    "darkslategray2", 	"darkslategray3", 	"darkslategray4", 	"darkslategrey", 	"darkturquoise",
    "darkviolet", 	"deeppink", 	"deeppink1", 	"deeppink2", 	"deeppink3",
    "deeppink4", 	"deepskyblue", 	"deepskyblue1", 	"deepskyblue2", 	"deepskyblue3",
    "deepskyblue4", 	"dimgray", 	"dimgrey", 	"dodgerblue", 	"dodgerblue1",
    "dodgerblue2", 	"dodgerblue3", 	"dodgerblue4", 	"firebrick", 	"firebrick1",
    "firebrick2", 	"firebrick3", 	"firebrick4", 	"floralwhite", 	"forestgreen",
    "fuchsia", 	"gainsboro", 	"ghostwhite", 	"gold", 	"gold1",
    "gold2", 	"gold3", 	"gold4", 	"goldenrod", 	"goldenrod1",
    "goldenrod2", 	"goldenrod3", 	"goldenrod4", 	"gray",
    "honeydew", 	"honeydew1",
    "honeydew2", 	"honeydew3", 	"honeydew4", 	"hotpink", 	"hotpink1",
    "hotpink2", 	"hotpink3", 	"hotpink4", 	"indianred", 	"indianred1",
    "indianred2", 	"indianred3", 	"indianred4", 	"indigo", 	"invis",
    "ivory", 	"ivory1", 	"ivory2", 	"ivory3", 	"ivory4",
    "khaki", 	"khaki1", 	"khaki2", 	"khaki3", 	"khaki4",
    "lavender", 	"lavenderblush", 	"lavenderblush1", 	"lavenderblush2", 	"lavenderblush3",
    "lavenderblush4", 	"lawngreen", 	"lemonchiffon", 	"lemonchiffon1", 	"lemonchiffon2",
    "lemonchiffon3", 	"lemonchiffon4", 	"lightblue", 	"lightblue1", 	"lightblue2",
    "lightblue3", 	"lightblue4", 	"lightcoral", 	"lightcyan", 	"lightcyan1",
    "lightcyan2", 	"lightcyan3", 	"lightcyan4", 	"lightgoldenrod", 	"lightgoldenrod1",
    "lightgoldenrod2", 	"lightgoldenrod3", 	"lightgoldenrod4", 	"lightgoldenrodyellow", 	"lightgray",
    "lightgreen", 	"lightgrey", 	"lightpink", 	"lightpink1", 	"lightpink2",
    "lightpink3", 	"lightpink4", 	"lightsalmon", 	"lightsalmon1", 	"lightsalmon2",
    "lightsalmon3", 	"lightsalmon4", 	"lightseagreen", 	"lightskyblue", 	"lightskyblue1",
    "lightskyblue2", 	"lightskyblue3", 	"lightskyblue4", 	"lightslateblue", 	"lightslategray",
    "lightslategrey", 	"lightsteelblue", 	"lightsteelblue1", 	"lightsteelblue2", 	"lightsteelblue3",
    "lightsteelblue4", 	"lightyellow", 	"lightyellow1", 	"lightyellow2", 	"lightyellow3",
    "lightyellow4", 	"lime", 	"limegreen", 	"linen", 	"magenta",
    "magenta1", 	"magenta2", 	"magenta3", 	"magenta4", 	"maroon",
    "maroon1", 	"maroon2", 	"maroon3", 	"maroon4", 	"mediumaquamarine",
    "mediumblue", 	"mediumorchid", 	"mediumorchid1", 	"mediumorchid2", 	"mediumorchid3",
    "mediumorchid4", 	"mediumpurple", 	"mediumpurple1", 	"mediumpurple2", 	"mediumpurple3",
    "mediumpurple4", 	"mediumseagreen", 	"mediumslateblue", 	"mediumspringgreen", 	"mediumturquoise",
    "mediumvioletred", 	"midnightblue", 	"mintcream", 	"mistyrose", 	"mistyrose1",
    "mistyrose2", 	"mistyrose3", 	"mistyrose4", 	"moccasin", 	"navajowhite",
    "navajowhite1", 	"navajowhite2", 	"navajowhite3", 	"navajowhite4", 	"navy",
    "navyblue", 	"none", 	"oldlace", 	"olive", 	"olivedrab",
    "olivedrab1", 	"olivedrab2", 	"olivedrab3", 	"olivedrab4", 	"orange",
    "orange1", 	"orange2", 	"orange3", 	"orange4", 	"orangered",
    "orangered1", 	"orangered2", 	"orangered3", 	"orangered4", 	"orchid",
    "orchid1", 	"orchid2", 	"orchid3", 	"orchid4", 	"palegoldenrod",
    "palegreen", 	"palegreen1", 	"palegreen2", 	"palegreen3", 	"palegreen4",
    "paleturquoise", 	"paleturquoise1", 	"paleturquoise2", 	"paleturquoise3", 	"paleturquoise4",
    "palevioletred", 	"palevioletred1", 	"palevioletred2", 	"palevioletred3", 	"palevioletred4",
    "papayawhip", 	"peachpuff", 	"peachpuff1", 	"peachpuff2", 	"peachpuff3",
    "peachpuff4", 	"peru", 	"pink", 	"pink1", 	"pink2",
    "pink3", 	"pink4", 	"plum", 	"plum1", 	"plum2",
    "plum3", 	"plum4", 	"powderblue", 	"purple", 	"purple1",
    "purple2", 	"purple3", 	"purple4", 	"rebeccapurple", 	"red",
    "red1", 	"red2", 	"red3", 	"red4", 	"rosybrown",
    "rosybrown1", 	"rosybrown2", 	"rosybrown3", 	"rosybrown4", 	"royalblue",
    "royalblue1", 	"royalblue2", 	"royalblue3", 	"royalblue4", 	"saddlebrown",
    "salmon", 	"salmon1", 	"salmon2", 	"salmon3", 	"salmon4",
    "sandybrown", 	"seagreen", 	"seagreen1", 	"seagreen2", 	"seagreen3",
    "seagreen4", 	"seashell", 	"seashell1", 	"seashell2", 	"seashell3",
    "seashell4", 	"sienna", 	"sienna1", 	"sienna2", 	"sienna3",
    "sienna4", 	"silver", 	"skyblue", 	"skyblue1", 	"skyblue2",
    "skyblue3", 	"skyblue4", 	"slateblue", 	"slateblue1", 	"slateblue2",
    "slateblue3", 	"slateblue4", 	"slategray", 	"slategray1", 	"slategray2",
    "slategray3", 	"slategray4", 	"slategrey", 	"snow", 	"snow1",
    "snow2", 	"snow3", 	"snow4", 	"springgreen", 	"springgreen1",
    "springgreen2", 	"springgreen3", 	"springgreen4", 	"steelblue", 	"steelblue1",
    "steelblue2", 	"steelblue3", 	"steelblue4", 	"tan", 	"tan1",
    "tan2", 	"tan3", 	"tan4", 	"teal", 	"thistle",
    "thistle1", 	"thistle2", 	"thistle3", 	"thistle4", 	"tomato",
    "tomato1", 	"tomato2", 	"tomato3", 	"tomato4", 	"transparent",
    "turquoise", 	"turquoise1", 	"turquoise2", 	"turquoise3", 	"turquoise4",
    "violet", 	"violetred", 	"violetred1", 	"violetred2", 	"violetred3",
    "violetred4", 	"webgray", 	"webgreen", 	"webgrey", 	"webmaroon",
    "webpurple", 	"wheat", 	"wheat1", 	"wheat2", 	"wheat3",
    "wheat4", 	"white", 	"whitesmoke", 	"x11gray", 	"x11green",
    "x11grey", 	"x11maroon", 	"x11purple", 	"yellow", 	"yellow1",
    "yellow2", 	"yellow3", 	"yellow4", 	"yellowgreen",
  }
  last_used_color = 0

  for state, match in pairs(tree.matching) do
    local color = result_to_color[match[1]]
    if not color then
      last_used_color = last_used_color + 1
      if not colors[last_used_color--[[@as int]]] then
        last_used_color = 1
      end
      result_to_color[match[1]] = last_used_color
      color = last_used_color
    end
    file:write(string.format('%s[label="%s:%s"color="%s"style=filled]\n', state, match[1], match[2], colors[color]))
  end
  file:write("}")
  file:close()
end

-- local dynamic = automation.generate_tree("dynamic")
-- local dynamo = automation.generate_tree("dynamo")
-- local terrific = automation.generate_tree("terrific")

-- print(automation.to_graphviz("G", automation.merge_trees{
--   dynamic, dynamo, terrific
-- }))

return automation