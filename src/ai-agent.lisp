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
  (:import-from #:40ants-ai-agents/llm-provider/anthropic
                 #:anthropic-provider)
  (:import-from #:40ants-ai-agents/llm-provider/ollama
                 #:ollama-provider)
  (:import-from #:40ants-ai-agents/llm-provider/gemini
                 #:gemini-provider)
  (:import-from #:40ants-ai-agents/user-message
                #:make-text-response-message
                #:user-message
                #:user-message-text
                #:text-response
                #:text-response-text)
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


(defun %provider-type (model)
  "Return a keyword identifying the provider family for MODEL."
  (cond
    ((uiop:string-prefix-p "deepseek" model) :openai)
    ((uiop:string-prefix-p "gpt-"     model) :openai)
    ((uiop:string-prefix-p "o1-"      model) :openai)
    ((uiop:string-prefix-p "o3-"      model) :openai)
    ((uiop:string-prefix-p "o4-"      model) :openai)
    ((uiop:string-prefix-p "claude-"  model) :anthropic)
    ((uiop:string-prefix-p "gemini-"  model) :gemini)
    (t :openai)))


(defun %default-endpoint (model)
  "Return the default API endpoint URL for MODEL."
  (ecase (%provider-type model)
    (:openai    "https://api.openai.com/v1/chat/completions")
    (:anthropic "https://api.anthropic.com/v1/messages")
    (:gemini    nil)
    (:ollama    "http://localhost:11434/api/chat")))


(defun %make-provider (model api-key tools endpoint)
  "Construct the appropriate provider class for MODEL."
  (ecase (%provider-type model)
    (:openai    (make-instance 'openai-provider
                               :endpoint (or endpoint
                                             (if (uiop:string-prefix-p "deepseek" model)
                                                 "https://api.deepseek.com/chat/completions"
                                                 "https://api.openai.com/v1/chat/completions"))
                               :api-key api-key
                               :tools tools
                               :model model))
    (:anthropic (make-instance 'anthropic-provider
                               :endpoint (or endpoint "https://api.anthropic.com/v1/messages")
                               :api-key api-key
                               :tools tools
                               :model model))
    (:gemini    (make-instance 'gemini-provider
                               :api-key api-key
                               :tools tools
                               :model model))
    (:ollama    (make-instance 'ollama-provider
                               :endpoint (or endpoint "http://localhost:11434/api/chat")
                               :tools tools
                               :model model))))


(-> ai-agent (string &key (:tools (soft-list-of symbol)) (:model string) (:endpoint (or string null)))
    (values ai-agent &optional))

(defun ai-agent (prompt &key tools (model "deepseek-chat") endpoint)
  "Create an AI agent with the given system PROMPT and optional TOOLS list."
  (make-instance 'ai-agent
                 :completer (%make-provider model *api-key* tools endpoint)
                 :prompt prompt
                 :tools tools))


(defgeneric to-api-messages (message)
  (:documentation "Convert a message to a list of API-format hash-tables.
Codabrus defines methods on its message class in src/message.lisp."))


(defmethod to-api-messages ((msg user-message))
  (list (dict "role" "user"
              "content" (user-message-text msg))))


(defmethod to-api-messages ((msg text-response))
  (list (dict "role" "assistant"
              "content" (text-response-text msg))))


(defgeneric make-response-message (response tool-events)
  (:documentation "Build a response message from the LLM RESPONSE text and TOOL-EVENTS list.
Codabrus defines a method on its message class in src/message.lisp."))


(defmethod make-response-message (response tool-events)
  (declare (ignore tool-events))
  (make-text-response-message response))


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
