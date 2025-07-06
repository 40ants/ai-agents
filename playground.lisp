(uiop:define-package #:40ants-ai-agents/playground
  (:use #:cl)
  (:import-from #:40ants-ai-agents/ai-agent
                #:ai-agent)
  (:import-from #:40ants-ai-agents/generics
                #:process)
  (:import-from #:40ants-ai-agents/state
                #:state)
  (:import-from #:40ants-ai-agents/user-message
                #:user-message))
(in-package #:40ants-ai-agents/playground)


(defparameter *api-key* nil)


(completions:defun-tool install-lisp-library ((name string "A name of lisp library to install"))
  "Installs a given lisp library using QL:QUICKLOAD function."
  (ql:quickload name)
  (format nil "Done, ~A was installed."
          name))


(completions:defun-tool search-lisp-library ((query string "A partial name of lisp library to search"))
  "Installs a given lisp library using QL:QUICKLOAD function."
  (with-output-to-string (s)
    (loop for system in (ql:system-apropos-list query)
          do (format s "~A~%"
                     system))))


(defun test-ai (text)
  (let* ((completer (make-instance 'completions:openai-completer
                                   :endpoint "https://api.deepseek.com/chat/completions"
                                   :api-key *api-key*
                                   :tools '(search-lisp-library install-lisp-library)
                                   :model "deepseek-chat"))
         ;; (prompt "Hello! How are you doing?")
         )
    (completions:get-completion completer
                                text
                                ;; prompt
                                :max-tokens 100
                                ;; :streaming-callback (lambda (text)
                                ;;                       (format *standard-output* "~A~%"
                                ;;                               text)
                                ;;                       (finish-output *standard-output*))
                                )))


(defun test-agent (text)
  (let* ((40ants-ai-agents/vars:*api-key* (uiop:getenv "API_KEY"))
         (agent (ai-agent "You MUST answer only on questions about Python programming language. If user is asking about unrelated theme, tell him you are consulting only about Python programming language. ALWAYS be as consise as possible."))
         (state (state (list (user-message text))))
         (response (process agent state)))
    response))


(test-agent "How long a python could be?")
