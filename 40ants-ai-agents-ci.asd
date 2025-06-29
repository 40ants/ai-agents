(defsystem "40ants-ai-agents-ci"
  :author "Alexander Artemenko <svetlyak.40wt@gmail.com>"
  :license "Unlicense"
  :homepage "https://40ants.com/ai-agents/"
  :class :package-inferred-system
  :description "Provides CI settings for 40ants-ai-agents."
  :source-control (:git "https://github.com/40ants/ai-agents")
  :bug-tracker "https://github.com/40ants/ai-agents/issues"
  :pathname "src"
  :depends-on ("40ants-ci"
               "40ants-ai-agents-ci/ci"))
