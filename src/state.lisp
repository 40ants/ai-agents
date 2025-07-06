(uiop:define-package #:40ants-ai-agents/state
  (:use #:cl)
  (:import-from #:serapeum
                #:soft-list-of
                #:->)
  (:import-from #:40ants-ai-agents/message
                #:message)
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
