local utils = require("cockpit.utils")
local eq = assert.are.same

describe("utils", function()
    it("partial match", function()
        eq(true, utils.partial_match("foobarbaz", "arbaz buzz"))
        eq(true, utils.partial_match("foobarbaz", "arbaz"))
        eq(false, utils.partial_match("foobarbaz", "arbas"))
        eq(false, utils.partial_match("foobarbaz", "yrbas"))
    end)
end)

