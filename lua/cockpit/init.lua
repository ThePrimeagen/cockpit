-- First, require the utility functions provided by nvim-treesitter
local ts_utils = require("nvim-treesitter.ts_utils")

-- Get the node at the current cursor position.
local node = ts_utils.get_node_at_cursor()

-- Traverse up the tree until we find a function node.
while node do
  local node_type = node:type()
  -- Depending on your language, you might need to check for different types,
  -- e.g., "function_declaration", "method_definition", or even "arrow_function".
  if node_type == "function_declaration" or node_type == "method_definition" then
    -- Optionally, use the Tree-sitter field API if available to get the function's name.
    local name_field = node:field("name")
    if name_field and name_field[1] then
      local func_name = ts_utils.get_node_text(name_field[1])[1]
      print("Current function: " .. func_name)
    else
      print("Inside an anonymous function or one without a 'name' field")
    end
    break
  end
  node = node:parent()
end

if not node then
  print("Not inside a function")
end
