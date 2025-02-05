local config = require("cockpit.config")
local eq = assert.are.same

local file1 = "file:///home/theprimeagen/.local/go/src/sync/once.go"
local file2 = "file:///home/theprimeagen/a/b/c.go"
local file3 = "file:///home/node_modules/a/b/c.go"
describe("config", function()
    it("filter works", function()
        eq(false, config.import_filtered(config.default(), file1, "go"))
        eq(true, config.import_filtered(config.default(), file2, "go"))
        eq(true, config.import_filtered(config.default(), file2, "javascript"))
        eq(false, config.import_filtered(config.default(), file3, "javascript"))
        eq(false, config.import_filtered(config.default(), file3, "typescript"))
    end)
end)

