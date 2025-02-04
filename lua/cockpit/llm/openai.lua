local M = {}

--- @param data OpenAIResponse
function M.get_first_content(data)
    --- todo: extremely brittle...
    return data.choices[1].message.content
end

return M

