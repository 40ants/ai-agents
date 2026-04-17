(uiop:define-package #:40ants-ai-agents-tests/core
  (:use #:cl)
  (:import-from #:rove
                #:deftest
                #:ok
                #:ng
                #:testing))
(in-package #:40ants-ai-agents-tests/core)


(deftest test-json-round-trip ()
  (testing "hash-table round trip"
    (let* ((original (serapeum:dict "key" "value" "num" 42))
           (json (40ants-ai-agents/utils:json-encode original))
           (parsed (40ants-ai-agents/utils:json-parse json)))
      (ok (string= "value" (gethash "key" parsed)))
      (ok (= 42 (gethash "num" parsed)))))

  (testing "nested hash-table"
    (let* ((original (serapeum:dict "nested" (serapeum:dict "inner" t)))
           (json (40ants-ai-agents/utils:json-encode original))
           (parsed (40ants-ai-agents/utils:json-parse json)))
      (ok (gethash "inner" (gethash "nested" parsed)))))

  (testing "vector round trip"
    (let* ((original (vector 1 2 3))
           (json (40ants-ai-agents/utils:json-encode original))
           (parsed (40ants-ai-agents/utils:json-parse json)))
      (ok (= 3 (length parsed)))
      (ok (= 2 (aref parsed 1)))))

  (testing "null round trip"
    (let* ((original (serapeum:dict "x" :null))
           (json (40ants-ai-agents/utils:json-encode original))
           (parsed (40ants-ai-agents/utils:json-parse json)))
      (ok (eq :null (gethash "x" parsed))))))


(deftest test-tool-registry ()
  (testing "defun-tool registers tool"
    (40ants-ai-agents/tool:defun-tool test-add (("a" "number" "First") ("b" "number" "Second"))
      "Add two numbers"
      (format nil "~A" (+ (parse-integer a) (parse-integer b))))
    (ok (gethash "TEST-ADD" 40ants-ai-agents/tool:*tools*)))

  (testing "invoke-tool calls function"
    (let ((result (40ants-ai-agents/tool:invoke-tool "TEST-ADD"
                                                      (serapeum:dict "a" "3" "b" "4"))))
      (ok (string= "7" result))))

  (testing "invoke-tool unknown tool returns error"
    (let ((result (40ants-ai-agents/tool:invoke-tool "NONEXISTENT" (serapeum:dict))))
      (ok (search "Error" result))))

  (testing "render-tool produces correct structure"
    (let* ((tool (gethash "TEST-ADD" 40ants-ai-agents/tool:*tools*))
           (rendered (40ants-ai-agents/tool:render-tool tool))
           (fn (gethash "function" rendered)))
      (ok (string= "function" (gethash "type" rendered)))
      (ok (string= "TEST-ADD" (gethash "name" fn)))
      (ok (string= "Add two numbers" (gethash "description" fn)))
      (ok (gethash "parameters" fn))))

  (testing "list-available-tools includes registered tools"
    (ok (member "TEST-ADD" (40ants-ai-agents/tool:list-available-tools) :test #'string=)))

  (testing "get-tool-info returns info"
    (let ((info (40ants-ai-agents/tool:get-tool-info "TEST-ADD")))
      (ok info)
      (ok (string= "TEST-ADD" (getf info :name)))))

  (testing "map-args-to-parameters extracts in order"
    (let* ((tool (gethash "TEST-ADD" 40ants-ai-agents/tool:*tools*))
           (args (40ants-ai-agents/tool:map-args-to-parameters
                  tool (serapeum:dict "a" "1" "b" "2"))))
      (ok (string= "1" (first args)))
      (ok (string= "2" (second args))))))


(deftest test-provider-routing ()
  (testing "%provider-type returns correct keyword"
    (ok (eq :openai (40ants-ai-agents/ai-agent::%provider-type "deepseek-chat")))
    (ok (eq :openai (40ants-ai-agents/ai-agent::%provider-type "gpt-4")))
    (ok (eq :openai (40ants-ai-agents/ai-agent::%provider-type "o1-preview")))
    (ok (eq :openai (40ants-ai-agents/ai-agent::%provider-type "o3-mini")))
    (ok (eq :openai (40ants-ai-agents/ai-agent::%provider-type "o4-mini")))
    (ok (eq :anthropic (40ants-ai-agents/ai-agent::%provider-type "claude-3-opus")))
    (ok (eq :gemini (40ants-ai-agents/ai-agent::%provider-type "gemini-2.0-flash"))))


  (testing "%make-provider creates correct class"
    (let ((p1 (40ants-ai-agents/ai-agent::%make-provider "deepseek-chat" "key" nil nil)))
      (ok (typep p1 '40ants-ai-agents/llm-provider/openai::openai-provider)))
    (let ((p2 (40ants-ai-agents/ai-agent::%make-provider "claude-3-opus" "key" nil nil)))
      (ok (typep p2 '40ants-ai-agents/llm-provider/anthropic::anthropic-provider)))
    (let ((p3 (40ants-ai-agents/ai-agent::%make-provider "gemini-2.0-flash" "key" nil nil)))
      (ok (typep p3 '40ants-ai-agents/llm-provider/gemini::gemini-provider))))


  (testing "deepseek gets custom endpoint"
    (let ((p (40ants-ai-agents/ai-agent::%make-provider "deepseek-chat" "key" nil nil)))
      (ok (search "deepseek" (slot-value p '40ants-ai-agents/llm-provider/openai::endpoint))))))


(deftest test-budget ()
  (testing "with-budget isolates dynamic counters"
    (40ants-ai-agents/llm-provider::with-budget ()
      (setf 40ants-ai-agents/llm-provider::*turns-used* 5)
      (ok (= 5 40ants-ai-agents/llm-provider::*turns-used*)))
    (ok (= 0 40ants-ai-agents/llm-provider::*turns-used*)))

  (testing "total-tokens-used sums both"
    (let ((p (make-instance '40ants-ai-agents/llm-provider::llm-provider :model "test")))
      (setf (40ants-ai-agents/llm-provider::prompt-token-count p) 10)
      (setf (40ants-ai-agents/llm-provider::completion-token-count p) 20)
      (ok (= 30 (40ants-ai-agents/llm-provider::total-tokens-used p))))))


(deftest test-gemini-message-conversion ()
  (testing "convert-role maps correctly"
    (ok (string= "model" (40ants-ai-agents/llm-provider/gemini::convert-role "assistant")))
    (ok (string= "user" (40ants-ai-agents/llm-provider/gemini::convert-role "tool")))
    (ok (string= "user" (40ants-ai-agents/llm-provider/gemini::convert-role "user"))))

  (testing "convert-messages-to-contents splits system"
    (let ((msgs (list (40ants-ai-agents/llm-provider::make-message "system" "sys")
                      (40ants-ai-agents/llm-provider::make-message "user" "hello")
                      (40ants-ai-agents/llm-provider::make-message "assistant" "hi"))))
      (multiple-value-bind (contents sys-instr)
          (40ants-ai-agents/llm-provider/gemini::convert-messages-to-contents msgs)
        (ok sys-instr "system instruction extracted")
        (ok (= 2 (length contents)))
        (ok (string= "user" (gethash "role" (first contents))))
        (ok (string= "model" (gethash "role" (second contents))))))))


(deftest test-anthropic-payload ()
  (testing "extract-system splits messages"
    (let ((msgs (list (40ants-ai-agents/llm-provider::make-message "system" "sys prompt")
                      (40ants-ai-agents/llm-provider::make-message "user" "hello"))))
      (multiple-value-bind (system rest)
          (40ants-ai-agents/llm-provider/anthropic::extract-system msgs)
        (ok (string= "sys prompt" system))
        (ok (= 1 (length rest)))
        (ok (string= "user" (gethash "role" (first rest)))))))

  (testing "build-payload creates correct structure"
    (let* ((p (make-instance '40ants-ai-agents/llm-provider/anthropic::anthropic-provider
                             :model "claude-3-opus"
                             :api-key "test"))
           (msgs (list (40ants-ai-agents/llm-provider::make-message "user" "hello")))
           (payload (40ants-ai-agents/llm-provider/anthropic::build-payload p msgs 1024)))
      (ok (string= "claude-3-opus" (gethash "model" payload)))
      (ok (= 1024 (gethash "max_tokens" payload)))
      (ok (gethash "messages" payload)))))


(deftest test-openai-payload ()
  (testing "build-payload creates correct structure"
    (let* ((p (make-instance '40ants-ai-agents/llm-provider/openai::openai-provider
                             :model "gpt-4"
                             :api-key "test"))
           (msgs (list (40ants-ai-agents/llm-provider::make-message "user" "hello")))
           (payload (40ants-ai-agents/llm-provider/openai::build-payload p msgs nil)))
      (ok (string= "gpt-4" (gethash "model" payload)))
      (ok (gethash "messages" payload)))))