(uiop:define-package #:40ants-ai-agents-examples/openai
  (:use #:cl)
  (:import-from #:40ants-ai-agents/llm-provider/openai
                #:openai-provider)
  (:import-from #:40ants-ai-agents/llm-provider
                #:make-message
                #:get-completion))
(in-package #:40ants-ai-agents-examples/openai)


(defvar *api-key*
  (or (uiop:getenv "DEEPSEEK_API_TOKEN")
      (error "Set DEEPSEEK_API_TOKEN env var first")))

(defvar *provider*
  (make-instance 'openai-provider
                 :endpoint "https://api.deepseek.com/chat/completions"
                 :api-key *api-key*
                 :model "deepseek-chat"))


(defun simple-chat (prompt)
  "Send PROMPT to the LLM, return full response."
  (let ((messages (list (make-message "user" prompt))))
    (multiple-value-bind (text updated-messages)
        (get-completion *provider* messages :max-tokens 512)
      (terpri)
      (values text updated-messages))))


(defun stream-chat (prompt)
  "Send PROMPT to the LLM, print text chunks as they arrive, return full response."
  (let ((messages (list (make-message "user" prompt))))
    (multiple-value-bind (text updated-messages)
        (get-completion *provider* messages
                        :max-tokens 512
                        :streaming-callback (lambda (chunk)
                                              (write-string chunk)
                                              (force-output)))
      (terpri)
      (values text updated-messages))))


;; (stream-chat "Write a haiku about Common Lisp.")
