local levels = require("cockpit.logger.level")
local M = {}

--- NOTE: if there is anymore additions to the config class as functions that operate over a config make the config into a class object and return the class

--- @class CockpitOptions
--- @field log_file_path string | nil
--- @field language_import_filter table<string, string[]> a list of strings that if exist within the LSP response for file import following will be ignored
--- @field log_level number | nil
--- @field save_queries boolean
--- @field save_queries_path string

--- @return CockpitOptions
function M.default()
    return {
        log_level = levels.DEBUG,
        log_file_path = "/tmp/cockpit",
        save_queries = false,
        save_queries_path = "/tmp/saved",
        language_import_filter = {
            go = {
                ".local/go",
            },
            typescript = {
                "node_modules",
            },
            javascript = {
                "node_modules",
            },
        },
    }
end

--- @param config CockpitOptions
--- @return string
function M.next_save_query_path(config)
    return string.format("%s.%d", config.save_queries_path, vim.uv.now())
end

--- @param config CockpitOptions
--- @param file_uri string
--- @param ft string
--- @return boolean
function M.import_filtered(config, file_uri, ft)
    local filters = config.language_import_filter[ft]
    if filters == nil then
        return false
    end
    for _, partial in ipairs(filters) do
        if string.find(file_uri, partial) then
            return false
        end
    end
    return true
end

return M
