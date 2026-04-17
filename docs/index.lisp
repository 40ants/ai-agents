(uiop:define-package #:40ants-ai-agents-docs/index
  (:use #:cl)
  (:import-from #:pythonic-string-reader
                #:pythonic-string-syntax)
  #+quicklisp
  (:import-from #:quicklisp)
  (:import-from #:named-readtables
                #:in-readtable)
  (:import-from #:40ants-doc
                #:defsection
                #:defsection-copy)
  (:import-from #:40ants-ai-agents-docs/changelog
                #:@changelog)
  (:import-from #:docs-config
                #:docs-config)
  (:import-from #:40ants-doc/autodoc
                #:defautodoc)
  (:export #:@index
           #:@readme
           #:@changelog))
(in-package #:40ants-ai-agents-docs/index)

(in-readtable pythonic-string-syntax)


(defmethod docs-config ((system (eql (asdf:find-system "40ants-ai-agents-docs"))))
  ;; 40ANTS-DOC-THEME-40ANTS system will bring
  ;; as dependency a full 40ANTS-DOC but we don't want
  ;; unnecessary dependencies here:
  #+quicklisp
  (ql:quickload "40ants-doc-theme-40ants")
  #-quicklisp
  (asdf:load-system "40ants-doc-theme-40ants")
  
  (list :theme
        (find-symbol "40ANTS-THEME"
                     (find-package "40ANTS-DOC-THEME-40ANTS")))
  )


(defsection @index (:title "40ants-ai-agents - A framework for building AI agent networks in Common Lisp."
                    :ignore-words ("JSON"
                                   "LLM"
                                   "AI"
                                   "HTTP"
                                   "TODO"
                                   "Unlicense"
                                   "REPL"
                                   "ASDF:PACKAGE-INFERRED-SYSTEM"
                                   "ASDF"
                                   "40A"
                                   "API"
                                   "URL"
                                   "URI"
                                   "RPC"
                                   "GIT"))
  (40ants-ai-agents system)
  "
[![](https://github-actions.40ants.com/40ants/ai-agents/matrix.svg?only=ci.run-tests)](https://github.com/40ants/ai-agents/actions)

![Quicklisp](http://quickdocs.org/badge/40ants-ai-agents.svg)
"
  (@installation section)
  (@usage section)
  (@api section))


(defsection-copy @readme @index)


(defsection @installation (:title "Installation")
  """
You can install this library from Quicklisp, but you want to receive updates quickly, then install it from Ultralisp.org:

```
(ql-dist:install-dist "http://dist.ultralisp.org/"
                      :prompt nil)
(ql:quickload :40ants-ai-agents)
```
""")


(defsection @usage (:title "Usage")
  """
## Defining tools

Use `defun-tool` from `40ants-ai-agents/tool` to create tools the LLM can call:

```
(40ants-ai-agents/tool:defun-tool search-lisp-library
    ((query string \"A partial name of lisp library to search\"))
  \"Searches for lisp libraries matching QUERY.\"
  (with-output-to-string (s)
    (loop for system in (ql:system-apropos-list query)
          do (format s \"~~A~~%\" system))))
```

Each arg is a `(name type description)` triple. The tool is registered in a global
registry and referenced by symbol name in the agent's tool list.

## Creating an agent

```
(let ((agent (40ants-ai-agents/ai-agent:ai-agent
              \"You are a helpful assistant.\"
              :tools '(search-lisp-library)
              :model \"deepseek-chat\")))
  (40ants-ai-agents/generics:process agent state))
```

The model name determines the provider automatically:
- `deepseek-*`, `gpt-*`, `o1-*`, `o3-*`, `o4-*` → OpenAI-compatible
- `claude-*` → Anthropic
- `gemini-*` → Google Gemini
- others → OpenAI (default)

## Providers

Each provider is a CLOS class inheriting from `llm-provider`:

| Provider | Class | Package |
|---|---|---|
| OpenAI / DeepSeek | `openai-provider` | `40ants-ai-agents/llm-provider/openai` |
| Anthropic / Claude | `anthropic-provider` | `40ants-ai-agents/llm-provider/anthropic` |
| Google Gemini | `gemini-provider` | `40ants-ai-agents/llm-provider/gemini` |
| Ollama (local) | `ollama-provider` | `40ants-ai-agents/llm-provider/ollama` |

All providers support SSE streaming via `:streaming-callback` and automatic
tool-call loops.

## Event hooks

Providers inherit from `event-emitter`. Listen for tool events:

```
(event-emitter:on provider :tool-call
  (lambda (call-id fn-name raw-args)
    (format t \"[CALL] ~~A ~~A~~%\" fn-name raw-args)))

(event-emitter:on provider :tool-result
  (lambda (call-id result)
    (format t \"[RESULT] ~~A~~%\" result)))
```

## Budget control

```
(let ((40ants-ai-agents/llm-provider:*max-turns* 10)
      (40ants-ai-agents/llm-provider:*max-cost-usd* 0.50d0))
  ...)
```

Signals `budget-exceeded` when limits are reached.

## Examples

See the `examples/` directory:

- `openai-streaming.lisp` — streaming chat with DeepSeek
- `tools.lisp` — tool definition and multi-agent pipeline
""")


(defautodoc @api (:system "40ants-ai-agents"))
