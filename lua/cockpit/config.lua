local M = {}

--- @return CockpitOptions
function M.default()
    return {
        language_import_filter = {
            go = {
                ".local/go",
            },
            typescript = {
                "node_modules",
            },
            javascript = {
                "node_modules",
            }
        }
    }
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
