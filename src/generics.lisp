(uiop:define-package #:40ants-ai-agents/generics
  (:use #:cl)
  (:export #:process))
(in-package #:40ants-ai-agents/generics)


(defgeneric process (agent state)
  (:documentation "Processing state by the agent."))
