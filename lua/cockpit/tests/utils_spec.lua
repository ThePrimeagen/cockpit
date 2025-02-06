local utils = require("cockpit.utils")
local eq = assert.are.same

describe("utils", function()
    it("partial match", function()
        eq("rue) {", utils.partial_match("if (", "if (t", "true) {"))
        eq(") {", utils.partial_match("if (", "if (true", "true) {"))
        eq("", utils.partial_match("if (", "if (true) {", "true) {"))
        eq(nil, utils.partial_match("if (", "if ", "true) {"))
        eq(nil, utils.partial_match("if (", "if (f", "true) {"))
        eq(nil, utils.partial_match("if (", "if [", "true) {"))
    end)
end)

