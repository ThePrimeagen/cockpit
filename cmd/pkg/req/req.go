package req

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"time"
)

type Prompt struct {
    Prompt string `json:"prompt"`
}

type AiMessage struct {
    Role string `json:"role"`
    Content string `json:"content"`
}

type LlamaRequest struct {
    Messages []AiMessage `json:"messages"`
    CachePrompt bool `json:"cache_prompt"`
}

type LlamaChoiceMessage struct {
    Content string `json:"content"`
}

type LlamaChoiceResponse struct {
    FinishReason string `json:"finish_reason"`
    Index int `json:"index"`
    Message LlamaChoiceMessage `json:"message"`
}

type LlamaTimings struct {
    PromptMS float64 `json:"prompt_ms"`
    PredictedMS float64 `json:"predicted_ms"`
}

type LlamaResponse struct {
    Choices []LlamaChoiceResponse `json:"choices"`
    Timings LlamaTimings `json:"timings"`
}

func (l *LlamaResponse) Bytes() []byte {
    bytes, _ := json.Marshal(l)
    return bytes
}

func newPromptPayload(prompt string) []byte {
    data, _ := json.Marshal(&Prompt{
        Prompt: prompt,
    })
    return data
}

func request(url string, payload []byte) ([]byte, error) {
    ctx, _ := context.WithTimeout(context.Background(), time.Second*60)
    req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(payload))
	if err != nil {
        log.Fatalf("unable to make request object with context: %s\n", err)
	}

	// Set the necessary headers
	req.Header.Set("Content-Type", "application/json")

	// Send the request
	client := &http.Client{}
    resp, err := client.Do(req)
	if err != nil {
        log.Fatalf("unable to make client request: %s\n", err)
	}
	defer resp.Body.Close()

	// Check for a successful response
	if resp.StatusCode != http.StatusOK {
        log.Fatalf("bad status code: %d\n", resp.StatusCode)
	}

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
        log.Fatalf("unable to read the body data: %s\n", err)
	}

    return body, nil
}

func RequestLlama(prompt string) LlamaResponse {
    cnt, err := json.Marshal(LlamaRequest{
        CachePrompt: false,
        Messages: []AiMessage{
            {Role: "system", Content: "you need to complete the line of code provided.  only respond with one line of code no explanation"},
            {Role: "system", Content: "language=typescript"},
            {Role: "system", Content: `only finish single line.
<example>
<code>
if (
</code>
<location>
1, 5
</location>
</example>
<expected_response>
some_condition) {
</expected_response>
<reasoning>
the if statement needs to be completed.  notice we do not fill in the if condition
</reasoning>
`},
            {Role: "user", Content: prompt},
        },
    })
    if err != nil {
        log.Fatalf("unable to make request: %s\n", err)
    }

    bytes, err := request("http://localhost:8080/v1/chat/completions", cnt)
    if err != nil {
        log.Fatalf("bad request to llama chat completions", err)
    }

    log.Printf("response: %s\n", string(bytes))
    var response LlamaResponse
    if err = json.Unmarshal(bytes, &response); err != nil {
        log.Fatalf("unable to unmarshal llama response: %s", err)
    }

    return response
}

func ClientRequest(prompt string) (LlamaResponse, error) {
    payload := newPromptPayload(prompt)
    b, err := request("http://localhost:6969", payload)
    if err != nil {
        log.Fatalf("unable to make request: %s\n", err)
    }

    var res LlamaResponse
    err = json.Unmarshal(b, &res)

    return res, err
}
