(defsystem "40ants-ai-agents-tests"
  :author "Alexander Artemenko <svetlyak.40wt@gmail.com>"
  :license "Unlicense"
  :homepage "https://40ants.com/ai-agents/"
  :class :package-inferred-system
  :description "Provides tests for 40ants-ai-agents."
  :source-control (:git "https://github.com/40ants/ai-agents")
  :bug-tracker "https://github.com/40ants/ai-agents/issues"
  :pathname "t"
  :depends-on ("40ants-ai-agents-tests/core")
  :perform (test-op (op c)
                    (unless (symbol-call :rove :run c)
                      (error "Tests failed"))))
