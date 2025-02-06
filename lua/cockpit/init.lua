local llm = require("cockpit.llm")
local logger = require("cockpit.logger.logger")
local config = require("cockpit.config")
local Pipeline = require("cockpit.pipeline")

local M = {}

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local del_autocmd = vim.api.nvim_del_autocmd
local cockpit_group = augroup("Cockpit", {})
local ids = {}

local vt = llm.display
local initialized = false
__Cockpit_global_id = 0

--- @param opts CockpitOptions
function M.setup(opts)
    if initialized then
        print("already called setup")
        logger:warn("everything has been setup already")
        return
    end

    initialized = true

    opts = vim.tbl_extend("force", config.default(), opts or {})
    logger:init(opts)
    logger:warn("cockpit#starting...")

    local editor_state = Pipeline:new(opts)

    --- @param arg TextChangedIEvent
    local function run_complete(arg)
        local state = { buffer = arg.buf }

        --- TODO: swap ok to an error and check for its lack of existence
        editor_state:run(state, function(ok, res)
            if not ok then
                logger:info("pipeline finished early")
            else
                logger:info("pipeline finished", "res", res)
            end
        end)
    end

    table.insert(
        ids,
        autocmd("BufLeave", {
            group = cockpit_group,
            pattern = "*",
            callback = function()
                vt:clear()
            end,
        })
    )

    table.insert(
        ids,
        autocmd("TextChangedI", {
            group = cockpit_group,
            pattern = "*",
            callback = vim.schedule_wrap(run_complete),
        })
    )

    table.insert(
        ids,
        autocmd("ModeChanged", {
            group = cockpit_group,
            pattern = "*",
            callback = function()
                vt:clear()
            end,
        })
    )

    __Cockpit_global_id = __Cockpit_global_id + 1
    local id = __Cockpit_global_id
    vim.on_key(function(_, key)
        if id ~= __Cockpit_global_id then
            error(
                "you should never see this unless you are deleting module caches..."
            )
        end
        editor_state:on_key(key)
    end, 0)
end

local dc = vim.api.nvim_del_user_command
function M.cockpit_refresh()
    vt:clear()

    for _, id in ipairs(ids) do
        del_autocmd(id)
    end
    ids = {}

    for module_name in pairs(package.loaded) do
        if module_name:match("^cockpit") then
            package.loaded[module_name] = nil
        end
    end
    pcall(dc, "CockpitTest")
    pcall(dc, "CockpitRefresh")
    require("cockpit")
    logger:warn("cockpit_refresh")
end

vim.api.nvim_create_user_command("CockpitTest", M.setup, {})
vim.api.nvim_create_user_command("CockpitRefresh", M.cockpit_refresh, {})

return M
