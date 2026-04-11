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
  (0.4.0 2026-04-11)
  (0.3.0 2026-04-11
         "* Added :MODEL keyword argument to 40ANTS-AI-AGENTS/AI-AGENT:AI-AGENT function to allow per-call model override.
          * Added :ENDPOINT keyword argument to 40ANTS-AI-AGENTS/AI-AGENT:AI-AGENT.
          * Default endpoint is now derived from the model name: `deepseek-*` uses `DeepSeek`, `gpt-*/o1-*/o3-*/o4-*` use `OpenAI`, `claude-*` uses `Anthropic`, others fall back to `OpenAI`.")
  (0.2.0 2026-04-10
         "* Exported 40ANTS-AI-AGENTS/AI-AGENT:AGENT-COMPLETER.")
  (0.1.0 2025-06-30
         "* Initial version."))
