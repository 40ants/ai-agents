# Plan: Replace completions with llm-provider in 40ants-ai-agents

## Goal

Replace the `completions` library with a native LLM provider layer inside `40ants-ai-agents`. The new layer uses CLOS objects, YASON for JSON, event-emitter for hooks, and puts each provider in its own file.

## Key design decisions

- **CLOS objects** instead of alists for messages, tool definitions, and API payloads
- **YASON** for JSON serialization/parsing (replacing cl-json)
- **event-emitter** for lifecycle hooks — each provider inherits from `event-emitter:event-emitter` and does `emit` on events
- **`call-tool` generic function** with `:around` methods instead of `*tool-interceptor*`
- **One file per provider** in `src/llm-provider/`

## Current usage of completions

| File | What it uses |
|------|-------------|
| `libs/ai-agents/src/ai-agent.lisp` | `openai-completer`, `get-completion`, `while-collecting-tool-events`, `get-tool-events` |
| `src/tools/*.lisp` (4 files) | `defun-tool` |
| `src/session.lisp` | `prompt-token-count`, `completion-token-count` |
| `src/main.lisp` | `*tool-interceptor*`, `*tools*`, `*max-turns*`, `*max-cost-usd*`, `*cost-fn*`, `budget-exceeded`, `with-budget`, `budget-exceeded-message`, `::fn`, `::map-args-to-parameters` |
| `libs/completions/` | **will be deleted** |

## New file structure

```
libs/ai-agents/
  40ants-ai-agents.asd
  src/
    core.lisp
    vars.lisp
    generics.lisp
    message.lisp
    state.lisp
    ai-agent.lisp                     — update
    llm-provider.lisp                 — NEW
    tool.lisp                         — NEW
    llm-provider/
      openai.lisp                     — NEW
      anthropic.lisp                  — NEW
      ollama.lisp                     — NEW
      gemini.lisp                     — NEW

libs/completions/                     — DELETE
```

## File details

### 1. `src/tool.lisp` — Tool registry

Package: `40ants-ai-agents/tool`

```lisp
(defclass function-tool ()
  ((description :initarg :description :reader tool-description)
   (name :initarg :name :reader tool-name)
   (parameters :initarg :parameters :reader tool-parameters)
   (fn :initarg :fn :reader tool-fn)))
```

Simplified vs completions — safety levels, categories, permissions stay at codabrus level.

**Macro** (identical signature — no tool rewrites needed):
```lisp
(defmacro defun-tool (name args description &rest body) ...)
```

**Functions:**
- `*tools*` — hash table
- `invoke-tool (fn-name args)` — looks up tool, calls `(apply fn (map-args-to-parameters tool args))`
- `map-args-to-parameters (tool args)`
- `list-available-tools`, `get-tool-info`

### 2. `src/llm-provider.lisp` — Generic functions, base class, budget, utils

Package: `40ants-ai-agents/llm-provider`

**Base class:**
```lisp
(defclass llm-provider (event-emitter:event-emitter)
  ((model :initarg :model :reader provider-model)
   (tools :initarg :tools :initform nil :reader provider-tools)
   (prompt-token-count :initform 0 :accessor prompt-token-count)
   (completion-token-count :initform 0 :accessor completion-token-count)))
```

**Generic functions:**
- `get-completion (provider messages &key max-tokens streaming-callback response-format)` — main entry point
- `call-tool (provider tool-name args)` — calls `invoke-tool` + emit events
  - `:around` method allows intercepting/substituting execution (replaces `*tool-interceptor*`)
- `render-tool (provider tool)` — renders tool definition in provider's format
- `total-tokens-used (provider)`, `reset-token-counts (provider)`

**Default `call-tool` method:**
```lisp
(defmethod call-tool ((provider llm-provider) tool-name args)
  (let ((call-id (format nil "call_~A" (incf *call-id-counter*))))
    (emit :tool-call provider call-id tool-name args)
    (let ((result (invoke-tool tool-name args)))
      (emit :tool-result provider call-id result)
      (values result call-id))))
```

Codabrus adds `:around` method for audit-log:
```lisp
(defmethod call-tool :around ((provider ...) tool-name args)
  (log:debug "Tool ~A called" tool-name)
  (let ((result (call-next-method)))
    ;; write to audit-log
    result))
```

**Events** (emit on the provider):

| Event | Arguments | When |
|-------|-----------|------|
| `:text` | `chunk` | Text chunk during streaming |
| `:tool-call` | `call-id tool-name raw-args` | Before tool execution |
| `:tool-result` | `call-id result` | After tool execution |
| `:usage` | `tokens-in tokens-out` | After receiving usage from API |
| `:finish` | `stop-reason` | On response completion |

**Budget:**
- `*max-turns*`, `*max-cost-usd*`, `*cost-fn*`, `*turns-used*`, `*cost-used*`
- `budget-exceeded` condition
- `with-budget` macro
- `with-budget-guard (provider)` macro

**Multimedia (ported from completions):**
- `file-to-base64 (path)`
- `make-text-block (provider text)` — generic function
- `make-base64-block (provider block-type base64-data media-type)` — generic function
- `make-content-blocks (provider &rest blocks)` — generic function
- `media-type-from-path (path)`
- `make-file-block (provider path &optional block-type)`

**JSON utilities:**
- `%encode-json (object)` — YASON serialization
- `%parse-json (string)` — YASON parsing → plist
- `%make-json-output-stream ()` — YASON with correct settings

**HTTP utilities:**
- `safe-http-request (&rest args)` — ported from completions
- `convert-byte-array-to-utf8 (bytes)`

### 3. `src/llm-provider/openai.lisp` — OpenAI / DeepSeek

Package: `40ants-ai-agents/llm-provider/openai`

```lisp
(defclass openai-provider (llm-provider)
  ((endpoint :initarg :endpoint
             :initform "https://api.openai.com/v1/chat/completions")
   (api-key :initarg :api-key)))
```

**`get-completion` method:**
- Serialization: YASON (`with-output-to-string*` + `encode-alist`)
- Request format: `model`, `messages` (array), `max_tokens`, `tools` (if any)
- Streaming: SSE parsing — port `read-streamed-json-objects`, `detect-tool-calls-in-stream`, `accumulate-tool-calls`, but parse with YASON
- Tool-calling loop: detects `tool_calls` → calls `call-tool` → sends tool results → repeats
- Emit: `:text` on streaming, `:usage` on usage receipt, `:finish` on stop

DeepSeek is compatible with OpenAI API — one provider covers both.

**`render-tool` method:** generates plist `(:type "function" :function (:name ... :description ... :parameters ...))`

**Multimedia methods:** `make-text-block`, `make-base64-block` (image_url format)

### 4. `src/llm-provider/anthropic.lisp` — Anthropic / Claude

```lisp
(defclass anthropic-provider (llm-provider)
  ((endpoint :initarg :endpoint
             :initform "https://api.anthropic.com/v1/messages")
   (api-key :initarg :api-key)))
```

Key differences from OpenAI:
- `system` — separate block, not in messages
- Headers: `anthropic-version`, `anthropic-beta`
- Content blocks: `(:type "text" :text "...")` and `(:type "tool_use" :id ... :name ... :input ...)`
- Tool results: `(:type "tool_result" :tool_use_id ... :content ...)`
- Streaming: `read-anthropic-sse-stream` → YASON parsing
- `render-tool` method: `(:name ... :description ... :input_schema ...)`

### 5. `src/llm-provider/ollama.lisp`

```lisp
(defclass ollama-provider (llm-provider)
  ((endpoint :initarg :endpoint
             :initform "http://localhost:11434/api/chat")))
```

Format similar to OpenAI: `model`, `messages`, `tools`. Differences: `options` instead of `max_tokens`, `function-call` structure.

### 6. `src/llm-provider/gemini.lisp`

```lisp
(defclass gemini-provider (llm-provider)
  ((api-key :initarg :api-key)))
```

Most different format:
- Endpoint: `https://generativelanguage.googleapis.com/v1beta/models/{model}:{action}`
- `contents` instead of `messages`, roles: `user`/`model`
- `parts` instead of `content`
- `functionDeclarations` instead of `tools`
- API key in header `x-goog-api-key`

### 7. `src/ai-agent.lisp` — update

```lisp
(defun ai-agent (prompt &key tools (model "deepseek-chat") endpoint)
  (let ((provider (make-instance 'openai-provider
                                  :endpoint (or endpoint (%default-endpoint model))
                                  :api-key *api-key*
                                  :tools tools
                                  :model model)))
    (make-instance 'ai-agent :completer provider :prompt prompt :tools tools)))
```

```lisp
(defmethod process ((agent ai-agent) (state state))
  (let* ((messages ...)
         (provider (agent-completer agent))
         (response (get-completion provider messages :max-tokens 1000))
         (tool-events (get-tool-events provider)))
    (add-message state (make-response-message response tool-events))))
```

### 8. Changes in codabrus

| File | Change |
|------|--------|
| `src/tools/*.lisp` (4 files) | `(:import-from #:completions #:defun-tool)` → `(:import-from #:40ants-ai-agents/tool #:defun-tool)` |
| `src/session.lisp` | `completions:` → `40ants-ai-agents/llm-provider:` |
| `src/main.lisp` | Replace `*tool-interceptor*` with `on :tool-call` / `on :tool-result` on provider, or `:around` method on `call-tool`. `*max-turns*`, `budget-exceeded` from new package. |
| `libs/completions/` | Delete entirely |

### 9. Dependencies

In `40ants-ai-agents.asd`:
- Add `:depends-on ("event-emitter" ...)`
- Add all new files as package-inferred systems
- Remove dependency on `completions`

In `qlfile`: add `event-emitter` if not in Quicklisp.

## Implementation order

1. ✅ `src/tool.lisp` — tool registry (testable independently)
2. ✅ `src/llm-provider.lisp` — base class, generics, budget, JSON utils, HTTP, multimedia
3. ✅ `src/llm-provider/openai.lisp` — most used provider (DeepSeek)
4. ✅ Update `src/ai-agent.lisp` — switch to new provider
5. ✅ Update `codabrus/src/tools/*.lisp` — new import
6. ✅ Update `codabrus/src/session.lisp` — new import
7. ✅ Update `codabrus/src/main.lisp` — events instead of interceptor
8. ✅ `src/llm-provider/anthropic.lisp`
9. ✅ `src/llm-provider/ollama.lisp`
10. ✅ `src/llm-provider/gemini.lisp`
11. Tests
12. Delete `libs/completions/`

Steps 1–7 yield a working DeepSeek. Steps 8–10 add remaining providers.
