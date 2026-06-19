# g4-agent

A native macOS chat agent for Gemma 4 12B. Runs locally on Apple Silicon — no
cloud, no API keys, no server.

## Quick Start

```sh
curl -fsSL https://raw.githubusercontent.com/mzbac/g4-agent/main/install.sh | sh
g4-agent
```

The installer downloads the `g4-agent` release binary and the supported Gemma 4
model plus multimodal projector into `~/.g4-agent/model` (~6.7 GiB total).
Subsequent runs use those cached files automatically.

To install a pinned release or use a custom binary directory:

```sh
curl -fsSL https://raw.githubusercontent.com/mzbac/g4-agent/main/install.sh \
  | sh -s -- --version 0.0.4

curl -fsSL https://raw.githubusercontent.com/mzbac/g4-agent/main/install.sh \
  | sh -s -- --install-dir "$HOME/bin"
```

To uninstall the binary, default model cache, and installer PATH entry:

```sh
curl -fsSL https://raw.githubusercontent.com/mzbac/g4-agent/main/uninstall.sh | sh
```

Starts interactive REPL mode. Type a prompt, press Enter, and the agent
responds.

---

## Usage

### Interactive chat (REPL)

```sh
./g4-agent
```

Type a prompt, press Enter, and the agent responds. It remembers the
conversation. Type `/help` for REPL commands, or Ctrl-D / `/exit` to quit.

### One-shot prompt

```sh
./g4-agent --prompt "Explain the Halting Problem in one paragraph."
```

Generates a single response and exits. Control length with `--max-tokens`:

```sh
./g4-agent --prompt "Hello" --max-tokens 100
```

### With images

```sh
./g4-agent --image photo.jpg --prompt "Describe this image."
```

Supports up to 16 images. In interactive mode, use `/image photo.jpg`.

### With video

```sh
./g4-agent --video clip.mp4 --prompt "Summarize this video."
```

Control frame sampling:

```sh
./g4-agent --video clip.mp4 --video-frames 8 --prompt "..."
./g4-agent --video clip.mp4 --video-start 5.0 --video-end 30.0 --prompt "..."
```

### With audio (WAV)

```sh
./g4-agent --audio recording.wav --prompt "Transcribe this."
```

### Custom model location

```sh
./g4-agent --model /path/to/model.gguf
./g4-agent --model /path/to/model.gguf --mmproj /path/to/mmproj.gguf
```

---

## CLI Flags

| Flag | Description |
|---|---|
| `--prompt <text>` | One-shot prompt (non-interactive) |
| `--max-tokens <n>` | Maximum tokens to generate |
| `--model <path>` | Path to model GGUF (default: `~/.g4-agent/model/gemma-4-12b-it-qat-q4_0.gguf`) |
| `--mmproj <path>` | Path to multimodal projector GGUF (default: `~/.g4-agent/model/mmproj-gemma-4-12b-it-qat-q4_0.gguf`) |
| `--session <dir>` | Session directory for conversation persistence |
| `--image <path>` | Attach an image (repeatable, up to 16) |
| `--video <path>` | Attach a video |
| `--video-frames <n>` | Frames per video |
| `--video-interval <s>` | Seconds between frames |
| `--video-start <s>` | Start time in seconds |
| `--video-end <s>` | End time in seconds |
| `--audio <path>` | Attach a WAV audio file |
| `--temperature <f>` | Sampling temperature (default from model) |
| `--top-k <n>` | Top-K sampling (default from model) |
| `--top-p <f>` | Nucleus / top-p sampling (default from model) |
| `--plan` | Read/search-only planning mode |
| `--build` | Full tool mode (default) |
| `--no-tools` | Disable tool use |
| `--show-thoughts` | Show hidden thought output |
| `--no-color` | Disable ANSI color output |
| `--light-theme` | Light terminal color scheme |
| `--reduced-motion` | Disable animated status lines |
| `--help`, `-h` | Show help |

---

## Interactive REPL Commands

Type these during an interactive session:

| Command | Description |
|---|---|
| `/help` | Show available commands |
| `/exit` | Quit |
| `/mode plan` | Switch to read/search-only planning mode |
| `/mode build` | Switch to full tool mode |
| `/tools on`, `/tools off` | Enable or disable tool execution |
| `/tool-limit N` | Set max tool calls per turn |
| `/thoughts on`, `/thoughts off` | Show or hide thought output |
| `/image <path>` | Attach an image to the conversation |
| `/video <path>` | Attach a video |
| `/audio <path>` | Attach a WAV audio file |
| `/media` | List attached media |
| `/media clear` | Remove all attached media |
| `/color on`, `/color off` | Toggle color output |
| `/theme light`, `/theme dark` | Switch color theme |
| `/motion on`, `/motion off` | Toggle animated status lines |
| `/compact` | Compact the conversation |

### Two-step workflow: plan then build

```
> /mode plan
> Write a Python script that downloads all images from a webpage.

[agent responds with a plan — no tools run]

> /approve

[agent executes the plan with tools enabled]
```

---

## Model

g4-agent runs **Gemma 4 12B Unified (QAT Q4_0 GGUF)** — a 12-billion
parameter dense model from Google with a 256K-token context window. The Q4_0
quantization keeps the model compact enough to run on Apple Silicon Macs with
Metal acceleration. The installer downloads weights from
`google/gemma-4-12B-it-qat-q4_0-gguf` on HuggingFace into
`~/.g4-agent/model`. Source-tree runs can also use `./model` when present, or
an explicit `--model` path.
