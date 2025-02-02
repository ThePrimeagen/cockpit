local ts = require("cockpit.treesitter.treesitter")

local M = {}

function M.cockpit_test()
    local scope = ts.get_smallest_scope()
    for i, v in ipairs(scope.range) do
        print("node:", scope.scope[i]:named(), scope.scope[i]:type())
        print(vim.inspect(v:to_text()))
        print("")
    end
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

