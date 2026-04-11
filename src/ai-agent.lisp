(uiop:define-package #:40ants-ai-agents/ai-agent
  (:use #:cl)
  (:import-from #:serapeum
                #:->
                #:soft-list-of)
  (:import-from #:completions)
  (:import-from #:40ants-ai-agents/vars
                #:*api-key*)
  (:import-from #:40ants-ai-agents/generics
                #:process)
  (:import-from #:40ants-ai-agents/state
                #:state-messages
                #:state)
  (:import-from #:40ants-ai-agents/ai-message
                #:ai-message-text
                #:ai-message)
  (:import-from #:40ants-ai-agents/user-message
                #:user-message-text
                #:user-message)
  (:export #:ai-agent
           #:agent-completer))
(in-package #:40ants-ai-agents/ai-agent)


(defclass ai-agent ()
  ((completer :initarg :completer
              :reader agent-completer)
   (prompt :initarg :prompt
           :initform ""
           :type string
           :reader %agent-prompt)
   (tools :initarg :tools
          :type (soft-list-of symbol)
          :initform nil
          :reader %agent-tools)))


(defun %default-endpoint (model)
  "Return the default API endpoint URL for MODEL.
   Known prefixes:
     deepseek-* -> https://api.deepseek.com/chat/completions
     gpt-*, o1-*, o3-*, o4-* -> https://api.openai.com/v1/chat/completions
     claude-* -> https://api.anthropic.com/v1/messages
   Everything else falls back to the OpenAI endpoint."
  (cond
    ((uiop:string-prefix-p "deepseek" model) "https://api.deepseek.com/chat/completions")
    ((uiop:string-prefix-p "gpt-"     model) "https://api.openai.com/v1/chat/completions")
    ((uiop:string-prefix-p "o1-"      model) "https://api.openai.com/v1/chat/completions")
    ((uiop:string-prefix-p "o3-"      model) "https://api.openai.com/v1/chat/completions")
    ((uiop:string-prefix-p "o4-"      model) "https://api.openai.com/v1/chat/completions")
    ((uiop:string-prefix-p "claude-"  model) "https://api.anthropic.com/v1/messages")
    (t "https://api.openai.com/v1/chat/completions")))


(-> ai-agent (string &key (:tools (soft-list-of symbol)) (:model string) (:endpoint (or string null)))
    (values ai-agent &optional))

(defun ai-agent (prompt &key tools (model "deepseek-chat") endpoint)
  "Create an AI agent with the given system PROMPT and optional TOOLS list.
   MODEL selects the LLM model (default: \"deepseek-chat\").
   ENDPOINT overrides the API URL; when nil the default for MODEL is used."
  (make-instance 'ai-agent
                 :completer (make-instance 'completions:openai-completer
                                           :endpoint (or endpoint
                                                         (%default-endpoint model))
                                           :api-key *api-key*
                                           :tools tools
                                           :model model)
                 :prompt prompt
                 :tools tools))


(defgeneric to-api-message (message)
  (:method ((message user-message))
    (list (cons :role "user")
          (cons :content (user-message-text message))))
  (:method ((message ai-message))
    (list (cons :role "assistant")
          (cons :content (ai-message-text message)))))


(defmethod process ((agent ai-agent) (state state))
  (let* ((messages (append
                    (list (list (cons :role "system")
                                (cons :content (%agent-prompt agent))))
                    (mapcar #'to-api-message
                            (reverse
                             (state-messages state)))))
         (response (completions:get-completion (agent-completer agent)
                                               messages
                                               ;; TODO: make this agent property
                                               :max-tokens 1000)))

    (40ants-ai-agents/generics:add-message state
                                           (ai-message response))))
