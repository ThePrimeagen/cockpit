local ts = require("cockpit.treesitter.treesitter")
local Point = require("cockpit.geo").Point
local llm = require("cockpit.llm")
local req = require("cockpit.req.req")

local M = {}

function M.cockpit_test()
    local cursor = Point:from_cursor()
    local scope = ts.scopes(cursor)
    local row, col = cursor:to_vim()
    local fimmed = llm.fim.fim(scope.range[1]:to_text(), row, col)
    req.complete(fimmed, function(data)
        print("complete:", llm.openai.get_first_content(data))
    end)
end

local dc = vim.api.nvim_del_user_command
function M.cockpit_refresh()
    for module_name in pairs(package.loaded) do
        if module_name:match("^cockpit") then
            package.loaded[module_name] = nil
        end
    end
    pcall(dc, "CockpitTest")
    pcall(dc, "CockpitRefresh")
    require("cockpit")
end

vim.api.nvim_create_user_command("CockpitTest", M.cockpit_test, {})
vim.api.nvim_create_user_command("CockpitRefresh", M.cockpit_refresh, {})

return M
