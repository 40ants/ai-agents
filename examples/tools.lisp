(uiop:define-package #:40ants-ai-agents-examples/tools
  (:use #:cl)
  (:import-from #:40ants-ai-agents/tool
                #:defun-tool)
  (:import-from #:40ants-ai-agents/ai-agent
                #:ai-agent)
  (:import-from #:40ants-ai-agents/generics
                #:process)
  (:import-from #:40ants-ai-agents/state
                #:state)
  (:import-from #:40ants-ai-agents/user-message
                #:user-message)
  (:import-from #:40ants-ai-agents/vars
                #:*api-key*))
(in-package #:40ants-ai-agents-examples/tools)


(defun-tool install-lisp-library ((name string "A name of lisp library to install"))
  "Installs a given lisp library using QL:QUICKLOAD function."
  (ql:quickload name)
  (format nil "Done, ~A was installed." name))


(defun-tool search-lisp-library ((query string "A partial name of lisp library to search"))
  "Searches for lisp libraries matching QUERY using QL:SYSTEM-APROPOS-LIST."
  (with-output-to-string (s)
    (loop for system in (ql:system-apropos-list query)
          do (format s "~A~%" system))))


(defun test-agent (text)
  "Run a single-turn agent with tool access. Requires DEEPSEEK_API_TOKEN env var."
  (let* ((*api-key* (or (uiop:getenv "DEEPSEEK_API_TOKEN")
                        (error "Set DEEPSEEK_API_TOKEN env var")))
         (agent (ai-agent "You MUST answer only on questions about Lisp programming language. If user is asking about unrelated theme, tell him you are consulting only about Lisp programming language. ALWAYS be as concise as possible."
                          :tools '(search-lisp-library install-lisp-library)))
         (state (state (list (user-message text)))))
    (process agent state)))


(defun test-agent-chain (post-theme)
  "Two-agent pipeline: planner → writer. Requires DEEPSEEK_API_TOKEN env var."
  (let* ((*api-key* (or (uiop:getenv "DEEPSEEK_API_TOKEN")
                        (error "Set DEEPSEEK_API_TOKEN env var")))
         (planner (ai-agent "Ты техноблоггер, ведущий Telegram канал про стартапы и программирование на Common Lisp. Составь план поста на заданную тему. План должен иметь от трех до пяти пунктов."))
         (writer (ai-agent "Ты техноблоггер, ведущий Telegram канал про стартапы и программирование на Common Lisp. Пройди по каждому пункту плана, и напиши соответствующую секцию поста в блог."))
         (state (state (list (user-message post-theme))))
         (state-with-plan (process planner state)))
    (process writer state-with-plan)))


;; (test-agent "How to install Serapeum library?")
;; (test-agent-chain "Почему CL лучше Python для AI")
