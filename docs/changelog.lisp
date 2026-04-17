(uiop:define-package #:40ants-ai-agents-docs/changelog
  (:use #:cl)
  (:import-from #:40ants-doc/changelog
                #:defchangelog))
(in-package #:40ants-ai-agents-docs/changelog)


(defchangelog (:ignore-words ("SLY"
                              "ASDF"
                              "REPL"
                              "OpenAI"
                              "HTTP"))
  (0.5.0 2026-04-17
         "* Replaced the `completions` library with a native LLM provider layer inside 40ants-ai-agents.
          * New package `40ants-ai-agents/tool` — standalone tool registry with `defun-tool` macro, `invoke-tool`, `map-args-to-parameters`, `render-tool`.
          * New package `40ants-ai-agents/llm-provider` — CLOS base class `llm-provider` (inherits `event-emitter`), generic functions `get-completion`, `call-tool`, `render-tool-for-api`, budget macros `with-budget`/`with-budget-guard`, multimedia helpers, JSON (YASON) and HTTP utilities.
          * New package `40ants-ai-agents/llm-provider/openai` — `openai-provider` class implementing OpenAI/DeepSeek-compatible API with SSE streaming, tool-calling loop, and token tracking. Uses YASON instead of cl-json.
          * `call-tool` emits `:tool-call` and `:tool-result` events on the provider, replacing the old `*tool-interceptor*` pattern. Clients add `:around` methods or `event-emitter:on` listeners.
          * Budget system (`*max-turns*`, `*max-cost-usd*`, `budget-exceeded`) moved from completions to `40ants-ai-agents/llm-provider`.
          * Codabrus tools now import `defun-tool` from `40ants-ai-agents/tool` instead of `completions`.
           * Codabrus session/main use `event-emitter` listeners instead of `*tool-interceptor*` for audit logging.")
  (0.6.0 2026-04-17
         "* Added `anthropic-provider` (40ants-ai-agents/llm-provider/anthropic) — Anthropic/Claude API with SSE streaming, tool-use content blocks, system-prompt extraction.
          * Added `ollama-provider` (40ants-ai-agents/llm-provider/ollama) — Ollama local API (`/api/chat`) with streaming, tool calling, no auth required.
          * Added `gemini-provider` (40ants-ai-agents/llm-provider/gemini) — Google Gemini API with `generateContent`/`streamGenerateContent`, `functionDeclarations`, `functionCall`/`functionResponse` parts.
          * `ai-agent` now auto-routes to the correct provider class based on model name prefix: `deepseek-*`/`gpt-*`/`o1-*`/`o3-*`/`o4-*` → OpenAI, `claude-*` → Anthropic, `gemini-*` → Gemini, others → OpenAI.")
  (0.4.0 2026-04-11)
  (0.3.0 2026-04-11
         "* Added :MODEL keyword argument to 40ANTS-AI-AGENTS/AI-AGENT:AI-AGENT function to allow per-call model override.
          * Added :ENDPOINT keyword argument to 40ANTS-AI-AGENTS/AI-AGENT:AI-AGENT.
          * Default endpoint is now derived from the model name: `deepseek-*` uses `DeepSeek`, `gpt-*/o1-*/o3-*/o4-*` use `OpenAI`, `claude-*` uses `Anthropic`, others fall back to `OpenAI`.")
  (0.2.0 2026-04-10
         "* Exported 40ANTS-AI-AGENTS/AI-AGENT:AGENT-COMPLETER.")
  (0.1.0 2025-06-30
         "* Initial version."))
