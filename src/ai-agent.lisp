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
  (:export #:ai-agent))
(in-package #:40ants-ai-agents/ai-agent)


(defclass ai-agent ()
  ((completer :initarg :completer
              :reader %agent-completer)
   (prompt :initarg :prompt
           :initform ""
           :type string
           :reader %agent-prompt)
   (tools :initarg :tools
          :type (soft-list-of symbol)
          :initform nil
          :reader %agent-tools)))


(-> ai-agent (string &key (:tools (soft-list-of symbol)))
    (values ai-agent &optional))

(defun ai-agent (prompt &key tools)
  (make-instance 'ai-agent
                 :completer (make-instance 'completions:openai-completer
                                           :endpoint "https://api.deepseek.com/chat/completions"
                                           :api-key *api-key*
                                           :tools tools
                                           :model "deepseek-chat")
                 :prompt prompt
                 :tools tools))


(defgeneric to-api-message (message)
  (:method ((message user-message))
    (list (cons :role "user")
          (cons :content (user-message-text message))))
  (:method ((message ai-message))
    (list (cons :role "ai")
          (cons :content (ai-message-text message)))))


(defmethod process ((agent ai-agent) (state state))
  (let* ((messages (append
                    (list (list (cons :role "system")
                                (cons :content (%agent-prompt agent))))
                    (mapcar #'to-api-message
                            (reverse
                             (state-messages state)))))
         (response (completions:get-completion (%agent-completer agent)
                                               messages
                                               :max-tokens 100)))
    (values response)))
