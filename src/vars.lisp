(uiop:define-package #:40ants-ai-agents/vars
  (:use #:cl)
  (:import-from #:serapeum
                #:defvar-unbound)
  (:export #:*api-key*))
(in-package #:40ants-ai-agents/vars)


(defvar-unbound *api-key*
  "Set this token to use AI.")
