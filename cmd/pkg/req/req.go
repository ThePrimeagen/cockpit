package req

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"
)

// lama


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

func EmptyLlamaResponse() LlamaResponse {
    return LlamaResponse{
        Choices: []LlamaChoiceResponse{},
        Timings: LlamaTimings{
            PromptMS: 0,
            PredictedMS: 0,
        },
    }
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
	ctx, _ := context.WithTimeout(context.Background(), time.Second*2)
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(payload))
	if err != nil {
        return nil, fmt.Errorf("unable to make request object with context: %s\n", err)
	}

	// Set the necessary headers
	req.Header.Set("Content-Type", "application/json")

	// Send the request
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
        return nil, fmt.Errorf("unable to make client request: %s\n", err)

	}
	defer resp.Body.Close()

	// Check for a successful response
	if resp.StatusCode != http.StatusOK {
        return nil, fmt.Errorf("bad status code: %d\n", resp.StatusCode)
	}

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
        return nil, fmt.Errorf("unable to read the body data: %s\n", err)
	}

	return body, nil
}

var id = 0
func RequestLlama(url string, prompt Prompt) LlamaResponse {
	cnt, err := json.Marshal(LlamaRequest{
		CachePrompt: false,
		Messages: []AiMessage{
			{Role: "system", Content: fmt.Sprintf(`
current programming language is %s.
you are a senior software engineer.
you are great at completing code.
you are handed a file with a location.
included is all the context that the file relies on that is special to the project.
you must work as quickly as you can to only respond with code that will complete the line in question.
you must never respond with reasoning, only code.
`, prompt.Language)},
			{Role: "user", Content: prompt.Prompt},
		},
	})
	if err != nil {
        log.Printf("error marshaling the request data: %s\n", err)
        return EmptyLlamaResponse()
	}

    log.Printf("subrequest to %s\n", url)
	bytes, err := request(url, cnt)
	if err != nil {
        log.Printf("error with querying the model: %s\n", err)
        return EmptyLlamaResponse()
	}

	var response LlamaResponse
	if err = json.Unmarshal(bytes, &response); err != nil {
        log.Printf("unable to decode LlamaResponse: %s\n", err)
        return EmptyLlamaResponse()
	}
    msg := response.Choices[0].Message.Content
    if strings.HasPrefix(msg, "```") {
        response.Choices[0].Message.Content = msg[1:len(msg) - 1]
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
