--- @class TSNode
--- @field start fun(self: TSNode): number, number, number
--- @field end_ fun(self: TSNode): number, number, number
--- @field named fun(self: TSNode): boolean
--- @field type fun(self: TSNode): string
--- @field range fun(self: TSNode): number, number, number, number

--- @class TCPSocket
--- @field close fun(self: TCPSocket)
--- @field connect fun(self: TCPSocket, addr: string, port: number, cb: fun(e: unknown))
--- @field is_closing fun(self: TCPSocket): boolean
--- @field write fun(self: TCPSocket, msg: string)
--- @field read_start fun(self: TCPSocket, cb: fun(err: unknown, data: string))

--- @class OpenAIMessage
--- @field content string

--- @class OpenAITimings
--- @field predicted_ms number
--- @field prompt_ms number

--- @class OpenAIChoices
--- @field finish_reason "stop"
--- @field index number
--- @field message OpenAIMessage

--- @class OpenAIResponse
--- @field choices OpenAIChoices[]
--- @field timings OpenAITimings

--- @class TextChangedIEvent
--- @field buf number
--- @field file string

--- @class LspPosition
--- @field character number
--- @field line number

--- @class LspRange
--- @field start LspPosition
--- @field end LspPosition

--- @class LspDefinitionResult
--- @field range LspRange
--- @field uri string
