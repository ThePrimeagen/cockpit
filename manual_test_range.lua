local ts = require("cockpit.treesitter.treesitter")
local geo = require("cockpit.geo")
local api = vim.api
local buf = vim.fn.bufnr("scratch/test.ts", true)
local contents = api.nvim_buf_get_lines(buf, 0, -1, false)
local scopes = ts.scopes(geo.Point:new(18, 1))
print(vim.inspect(scopes.range[1]))
