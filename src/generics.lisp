(uiop:define-package #:40ants-ai-agents/generics
  (:use #:cl)
  (:export #:process
           #:add-message))
(in-package #:40ants-ai-agents/generics)


(defgeneric process (agent state)
  (:documentation "Processing state by the agent."))


(defgeneric add-message (state message)
  (:documentation "Adds a message to the state and returns the new state object."))
