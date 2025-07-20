(uiop:define-package #:40ants-ai-agents/state
  (:use #:cl)
  (:import-from #:serapeum
                #:soft-list-of
                #:->)
  (:import-from #:40ants-ai-agents/message
                #:message)
  (:import-from #:40ants-ai-agents/generics
                #:add-message)
  (:export #:state
           #:state-messages))
(in-package #:40ants-ai-agents/state)


(defclass state ()
  ((messages :initarg :messages
             :initform nil
             :reader state-messages)))


(-> state ((soft-list-of message))
    (values state &optional))

(defun state (messages)
  (make-instance 'state
                 :messages messages))


(defmethod add-message ((state state) message)
  (state (list* message
                (state-messages state))))
