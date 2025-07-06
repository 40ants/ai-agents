#-asdf3.1 (error "40ants-ai-agents requires ASDF 3.1 because for lower versions pathname does not work for package-inferred systems.")
(defsystem "40ants-ai-agents"
  :description "A framework for building AI agent networks in Common Lisp."
  :author "Alexander Artemenko <svetlyak.40wt@gmail.com>"
  :license "Unlicense"
  :homepage "https://40ants.com/ai-agents/"
  :source-control (:git "https://github.com/40ants/ai-agents")
  :bug-tracker "https://github.com/40ants/ai-agents/issues"
  :class :40ants-asdf-system
  :defsystem-depends-on ("40ants-asdf-system")
  :pathname "src"
  :depends-on ("40ants-ai-agents/core"
               "40ants-ai-agents/ai-agent")
  :in-order-to ((test-op (test-op "40ants-ai-agents-tests"))))
