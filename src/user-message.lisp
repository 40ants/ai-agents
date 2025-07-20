(uiop:define-package #:40ants-ai-agents/user-message
  (:use #:cl)
  (:import-from #:40ants-ai-agents/message
                #:message)
  (:export #:user-message
           #:user-message-text))
(in-package #:40ants-ai-agents/user-message)


(defclass user-message (message)
  ((text :initarg :text
         :type string
         :reader user-message-text)))


(defun user-message (text)
  (make-instance 'user-message
                 :text text))


(defmethod print-object ((obj user-message) stream)
  (print-unreadable-object (obj stream :type t)
    (format stream "~A"
            (user-message-text obj))))
