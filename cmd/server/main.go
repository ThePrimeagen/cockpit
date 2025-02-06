package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"

	"theprimeagen.tv/cmd/pkg/req"
)

type LlamaConfig struct {
    Temp float64 `json:"temp"`
    Prio int `json:"prio"`
    Threads int `json:"threads"`
    NGL int `json:"ngl"`
    NP int `json:"np"`
    FlashAttention bool `json:"fashAttention"`
}

type ServerConfig struct {
    Model string `json:"model"`
    Config LlamaConfig `json:"config"`
    CountPerGPU int `json:"countPerGPU"`
    GPUs int `json:"gpus"`
    LlamaServer string `json:"llamaServer"`
    Port int `json:"port"`
}

func (s *LlamaConfig) args(model string, port int) []string {
    out := []string{
        "--temp=0",
        "--prio", fmt.Sprintf("%d", s.Prio),
        "--threads", fmt.Sprintf("%d", s.Threads),
        "-ngl", fmt.Sprintf("%d", s.NGL),
        "-np", fmt.Sprintf("%d", s.NP),
        "--port", fmt.Sprintf("%d", port),
        "--model", model,
    }

    if s.FlashAttention {
        out = append(out, "--flash-attn")
    }
    return out
}

func defaultConfig() *ServerConfig {
    return &ServerConfig{
        Model: "",
        CountPerGPU: 1,
        GPUs: 6,
        Port: 8080,
        Config: LlamaConfig{
            Temp: 0.0,
            Prio: 2,
            Threads: 8,
            NGL: 999,
            NP: 4,
        },
        LlamaServer: "/home/prime/llama.cpp/build/bin/llama-server",
    }
}

func getConfigFromFile(path string) *ServerConfig {
    if !strings.HasSuffix(path, "json") {
        return nil
    }

    contents, err := os.ReadFile(path)
    if err != nil {
        return nil
    }

    var config ServerConfig
    err = json.Unmarshal(contents, &config)
    if err != nil {
        return nil
    }
    return &config
}

func getConfig() *ServerConfig {
    if len(os.Args) < 2 {
        panic("please provide path to config or model")
    }

    configOrModel := os.Args[1]
    config := getConfigFromFile(configOrModel)

    if config != nil {
        return config
    }

    config = defaultConfig()
    config.Model = configOrModel
    return config
}

func launchLlamas(config *ServerConfig) ([]exec.Cmd, []int, error) {

    out := []exec.Cmd{}
    ports := []int{}
    port := config.Port
    for gpuCounter := range config.GPUs {
        for range config.CountPerGPU {
            args := config.Config.args(config.Model, port)
            ports = append(ports, port)
            port++

            fmt.Printf("starting: %s %+v\n", config.LlamaServer, args)

            cmd := exec.Cmd {
                Path: config.LlamaServer,
                Args: args,
                Env: []string{
                    fmt.Sprintf("CUDA_VISIBLE_DEVICES=%d", gpuCounter),
                },
            }
            err := cmd.Start()
            if err != nil {
                return out, ports, err
            }

            out = append(out, cmd)
        }
    }

    return out, ports, nil
}

func main() {
    cmds, _, err := launchLlamas(getConfig())
    if err != nil {
        log.Fatalf("error while launching llamas: %s\n", err)
    }
    defer func() {
        for _, cmd := range cmds {
            cmd.Process.Kill()
        }
    }()

    for _, cmd := range cmds {
        go func() {
            err := cmd.Wait()
            if err != nil {
                log.Fatalf("called wait and got an error: %s", err)
            }
        }()
    }

    //id := 0
    http.Handle("/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        body, err := io.ReadAll(r.Body)
        if err != nil {
            log.Fatalf("Unable to read body: %s", err)
            w.Write([]byte("{}"))
            return
        }

        var cr req.Prompt
        err = json.Unmarshal(body, &cr)
        if err != nil {
            log.Fatalf("YOU GOT AN ERROR DUMMY BECAUSE YOU DUMB: %s\n", err)
        }

        //id++
        //p := ports[id % len(ports)]
        //url := fmt.Sprintf("http://localhost:%d/v1/chat/completions", p)
        url := "http://localhost:8080/v1/chat/completions"

        data := req.RequestLlama(url, cr)
        w.Write(data.Bytes())
    }))

    log.Fatal(http.ListenAndServe(":42069", nil))
}

