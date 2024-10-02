local default_shortcodes = require("better-chat/runtime/default_shortcodes")
local twemoji_shortcodes = require("twemoji-in-factorio/assets/shortcodes/joypixels") --[[@as table<string,string>]]
local automation = require("better-chat/runtime/levenshtein_automation")
local insert, time, start = table.insert, os.time--[[@as fun():int]], 0


print("Making default trees..."); start = time()
---@type Levenshtein.tree[]
local default_trees = {}
for code in pairs(default_shortcodes) do
	insert(default_trees, automation.generate_tree(code))
end
print(string.format("Done in %ss", time()-start))

print("Merging default trees into one..."); start = time()
local default_tree = automation.merge_trees(default_trees)
print(string.format("Done in %ss", time()-start))
default_trees = nil
collectgarbage()
print(automation.to_graphviz("default", default_tree))


print("Making twemoji trees..."); start = time()
local twemoji_trees = {}
for code in pairs(twemoji_shortcodes) do
	insert(twemoji_trees, automation.generate_tree(code))
end
print(string.format("Done in %ss", time()-start))

print("Merging twemoji trees into one..."); start = time()
local twemoji_tree = automation.merge_trees(twemoji_trees)
print(string.format("Done in %ss", time()-start))
twemoji_trees = nil
collectgarbage()
print(automation.to_graphviz("twemoji", default_tree))

print("Merging both"); start = time()
local tree = automation.merge_trees{default_tree, twemoji_tree}
print(string.format("Done in %ss", time()-start))
default_tree, twemoji_tree = nil, nil
collectgarbage()
print(automation.to_graphviz("both", tree))

---Whether the string is closer than min_distance
---
---TODO: use [Levenshtein Automation](https://en.wikipedia.org/wiki/Levenshtein_automaton)
---@param strY string
---@param strX string
---@param max_cost int
---@return boolean is_closer
---@return int? distance is returned when it is closer
local function closer_test(strY, strX, max_cost)
  local lenY, lenX = #strY, #strX
  ---@type table<int,table<int, int>>
  local matrix, cost = {}, 0

  local len_difference = math.abs(lenY - lenX)
  if (len_difference > max_cost) then
    return false
  end

  -- initialise the base matrix values
  for y = 1, lenY+1, 1 do
    matrix[y] = {}
    matrix[y][1] = y
  end
  for x = 1, lenX+1, 1 do
    matrix[1][x] = x
  end

  local min, unpack = math.min, table.unpack
  -- actual Levenshtein algorithm
  for y = 1, lenY, 1 do
    for x = 1, lenX, 1 do
      if (strY:byte(y) == strX:byte(x)) then
        cost = 0
      else
        cost = 1
      end

      matrix[y+1][x+1] = min(
        matrix[y][x+1] + 1,
        matrix[y+1][x] + 1,
        matrix[y][x] + cost
      )
    end

    if y >= max_cost then
      cost = min(unpack(matrix[y]))
      if cost > max_cost then
        return false
      end
    end
  end

  cost = matrix[lenY+1][lenX+1]
  if cost >= max_cost then
    return false
  else
    return true, cost
  end
end

---Use the levenshtein algorithm to find the closest
---shortcode to the text given
---@param given_code string
---@return string?
local function Levenshtein_shortcodes(given_code)
  ---@type string[]|string?, int
  local closest, closest_distance = nil, 3
  ---@type boolean, int?
  local is_closer, closer_distance = false, nil

  for _, dictionary in pairs({default_shortcodes, twemoji_shortcodes}) do
    for shortcode, replacement in pairs(dictionary) do
      is_closer, closer_distance = closer_test(given_code, shortcode, closest_distance)
      if is_closer then
        ---@cast closer_distance int
        if closer_distance == 0 then
          return type(replacement) == "string" and replacement or replacement[1]
        end
        closest = replacement
        closest_distance = closer_distance
      end
    end
  end

  return type(closest) == "table" and closest[1] or closest --[[@as string?]]
end

local test_values = {
	"construction_robot",
	"construction_bot",
}

local result = nil
print("Trying automation..."); start = time()
for _, value in pairs(test_values) do
	print(value.."...", automation.match(value, tree))
end
print(string.format("Done in %ss", time()-start))
print("Trying brute force..."); start = time()
for _, value in pairs(test_values) do
	print(value.."...", Levenshtein_shortcodes(value))
end
print(string.format("Done in %ss", time()-start))