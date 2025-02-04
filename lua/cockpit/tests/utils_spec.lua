local utils = require("cockpit.utils")
local eq = assert.are.same

describe("utils", function()
    it("split", function()
        local text = "hello\r\nmy\r\nname\r\n\r\nis\r\nprime"
        local parts = utils.split(text, "\r\n")
        eq({"hello", "my", "name", "", "is", "prime"}, parts)
    end)
end)

