local ts = require("cockpit.treesitter.treesitter")
local utils = require("cockpit.utils")
local ts_utils = require("nvim-treesitter.ts_utils")

local M = {}

function M.cockpit_test()
    print("help?")
    local scope = ts.capture_scope()
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

vim.api.nvim_create_user_command(
    "CockpitTest",
    M.cockpit_test,
    {}
)

vim.api.nvim_create_user_command(
    "CockpitRefresh",
    M.cockpit_refresh,
    {}
)

return M

