(uiop:define-package #:40ants-ai-agents/ai-agent
  (:use #:cl)
  (:import-from #:serapeum
                #:->
                #:soft-list-of
                #:dict)
  (:import-from #:40ants-ai-agents/vars
                #:*api-key*)
  (:import-from #:40ants-ai-agents/generics
                #:process)
  (:import-from #:40ants-ai-agents/state
                #:state-messages
                #:state)
  (:import-from #:40ants-ai-agents/llm-provider
                #:get-completion
                #:call-tool
                #:prompt-token-count
                #:completion-token-count)
  (:import-from #:40ants-ai-agents/llm-provider/openai
                #:openai-provider)
  (:export #:ai-agent
           #:agent-completer
           #:to-api-messages
           #:make-response-message))
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
  "Return the default API endpoint URL for MODEL."
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
  "Create an AI agent with the given system PROMPT and optional TOOLS list."
  (make-instance 'ai-agent
                 :completer (make-instance 'openai-provider
                                           :endpoint (or endpoint
                                                         (%default-endpoint model))
                                           :api-key *api-key*
                                           :tools tools
                                           :model model)
                 :prompt prompt
                 :tools tools))


(defgeneric to-api-messages (message)
  (:documentation "Convert a message to a list of API-format hash-tables.
Codabrus defines methods on its message class in src/message.lisp."))


(defgeneric make-response-message (response tool-events)
  (:documentation "Build a response message from the LLM RESPONSE text and TOOL-EVENTS list.
Codabrus defines a method on its message class in src/message.lisp."))


(defmethod process ((agent ai-agent) (state state))
  (let* ((messages (append
                    (list (dict "role" "system"
                                "content" (%agent-prompt agent)))
                    (mapcan #'to-api-messages
                            (reverse (state-messages state)))))
         (response (get-completion (agent-completer agent)
                                   messages
                                   :max-tokens 1000)))
    (40ants-ai-agents/generics:add-message state
                                           (make-response-message response nil))))
