(uiop:define-package #:40ants-ai-agents/ai-message
  (:use #:cl)
  (:import-from #:40ants-ai-agents/message
                #:message)
  (:export #:ai-message-text
           #:ai-message))
(in-package #:40ants-ai-agents/ai-message)


(defclass ai-message (message)
  ((text :initarg :text
         :type string
         :reader ai-message-text)))


(defun ai-message (text)
  (make-instance 'ai-message
                 :text text))
