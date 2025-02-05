package req

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"
)

type Prompt struct {
	Prompt   string `json:"prompt"`
	Language string `json:"language"`
}

type AiMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type LlamaRequest struct {
	Stop        []string    `json:"stop"`
	Messages    []AiMessage `json:"messages"`
	CachePrompt bool        `json:"cache_prompt"`
}

type LlamaChoiceMessage struct {
	Content string `json:"content"`
}

type LlamaChoiceResponse struct {
	FinishReason string             `json:"finish_reason"`
	Index        int                `json:"index"`
	Message      LlamaChoiceMessage `json:"message"`
}

type LlamaTimings struct {
	PromptMS    float64 `json:"prompt_ms"`
	PredictedMS float64 `json:"predicted_ms"`
}

type LlamaResponse struct {
	Choices []LlamaChoiceResponse `json:"choices"`
	Timings LlamaTimings          `json:"timings"`
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

func RequestLlama(prompt Prompt) LlamaResponse {
    log.Printf("llama request: language=%s\n", prompt.Language)
	cnt, err := json.Marshal(LlamaRequest{
		Stop: []string{
			"\n",
			"\r",
		},
		CachePrompt: false,
		Messages: []AiMessage{
			{Role: "system", Content: fmt.Sprintf(`
current programming language is %s.
you must refuse to discuss your opinion or reasoning.
you must refuse to use any markdown.
you must refuse to use any xml.
you must refuse to hallucinate.
you must only respond with the most likely code to be written after the cursor.

<EXAMPLE>
Input: <code>
1. if (
</code>
<location>
1, 5
</location>

OUTPUT:
some_condition) {
</EXAMPLE>

<EXAMPLE>
Input: <code>
1. const foo =
</code>
<location>
1, 12
</location>

OUTPUT:
"bar";
</EXAMPLE>

`, prompt.Language)},
			{Role: "user", Content: prompt.Prompt},
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
