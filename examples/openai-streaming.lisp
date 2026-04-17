;;; OpenAI streaming example.
;;;
;;; Load from the REPL:
;;;   (load "libs/ai-agents/examples/openai-streaming.lisp")
;;;
;;; Or evaluate forms one by one.
;;; Requires DEEPSEEK_API_TOKEN in env or secrets.json.

(uiop:define-package #:openai-streaming-example
  (:use #:cl))
(in-package #:openai-streaming-example)


(ql:quickload "40ants-ai-agents/llm-provider/openai")

;; --- Config ---

(defvar *api-key*
  (or (uiop:getenv "DEEPSEEK_API_TOKEN")
      (error "Set DEEPSEEK_API_TOKEN env var first")))

(defvar *provider*
  (make-instance '40ants-ai-agents/llm-provider/openai:openai-provider
                 :endpoint "https://api.deepseek.com/chat/completions"
                 :api-key *api-key*
                 :model "deepseek-chat"))

;; --- Simple streaming call ---

(defun simple-chat (prompt)
  "Send PROMPT to the LLM, print text chunks as they arrive, return full response."
  (let ((messages (list (40ants-ai-agents/llm-provider:make-message "user" prompt))))
    (multiple-value-bind (text updated-messages)
        (40ants-ai-agents/llm-provider:get-completion
         *provider*
         messages
         :max-tokens 512)
      (terpri)
      (values text updated-messages))))


(defun stream-chat (prompt)
  "Send PROMPT to the LLM, print text chunks as they arrive, return full response."
  (let ((messages (list (40ants-ai-agents/llm-provider:make-message "user" prompt))))
    (multiple-value-bind (text updated-messages)
        (40ants-ai-agents/llm-provider:get-completion
         *provider*
         messages
         :max-tokens 512
         :streaming-callback (lambda (chunk)
                               (write-string chunk)
                               (force-output)))
      (terpri)
      (values text updated-messages))))

;; --- Try it ---

;; (stream-chat "Write a haiku about Common Lisp.")
