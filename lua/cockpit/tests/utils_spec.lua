local utils = require("cockpit.utils")
local eq = assert.are.same

describe("utils", function()
    it("partial match", function()
        local ok, idx = utils.partial_match("foobarbaz", "arbaz buzz")
        eq(true, ok)
        eq(6, idx)

        ok, idx = utils.partial_match("foobarbaz", "arbaz")
        eq(true, ok)
        eq(5, idx)

        ok, idx = utils.partial_match("foobarbaz", "arbas")
        eq(false, ok)

        ok, idx = utils.partial_match("foobarbaz", "yrbas")
        eq(false, ok)

        local response = "return i;"
        ok, idx = utils.partial_match("            ret", response)
        eq(true, ok)
        eq("urn i;", response:sub(idx))
    end)
end)

