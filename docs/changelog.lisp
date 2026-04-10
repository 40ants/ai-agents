(uiop:define-package #:40ants-ai-agents-docs/changelog
  (:use #:cl)
  (:import-from #:40ants-doc/changelog
                #:defchangelog))
(in-package #:40ants-ai-agents-docs/changelog)


(defchangelog (:ignore-words ("SLY"
                              "ASDF"
                              "REPL"
                              "HTTP"))
  (0.2.0 2026-04-10
         "* Exported 40ANTS-AI-AGENTS/AI-AGENT:AGENT-COMPLETER.")
  (0.1.0 2025-06-30
         "* Initial version."))
