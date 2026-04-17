(uiop:define-package #:40ants-ai-agents/llm-provider/anthropic
  (:use #:cl)
  (:import-from #:40ants-ai-agents/llm-provider
                #:llm-provider
                #:provider-model
                #:provider-tools
                #:prompt-token-count
                #:completion-token-count
                #:get-completion
                #:call-tool
                #:render-tool-for-api
                #:render-tools-payload
                #:exec-tool-calls
                #:make-message
                #:with-budget
                #:with-budget-guard
                #:json-encode
                #:json-parse
                #:safe-http-request
                #:convert-byte-array-to-utf8)
  (:import-from #:40ants-ai-agents/tool
                #:render-tool
                #:tool-name
                #:tool-description
                #:tool-parameters
                #:%param-name->string
                #:%param-type->string)
  (:import-from #:alexandria #:when-let)
  (:import-from #:serapeum #:dict #:take #:drop #:append1)
  (:export #:anthropic-provider))
(in-package #:40ants-ai-agents/llm-provider/anthropic)


(defvar *debug-stream* nil)
(defvar *read-timeout* 120)
(defvar *anthropic-version* "2023-06-01")


(defclass anthropic-provider (llm-provider)
  ((endpoint :initarg :endpoint
             :initform "https://api.anthropic.com/v1/messages")
   (api-key :initarg :api-key)))


(defmethod render-tool-for-api ((provider anthropic-provider) tool)
  (with-slots ((name tool-name) (desc tool-description) (params tool-parameters))
      tool
    (let ((result (dict "name" name
                        "description" desc)))
      (when params
        (setf (gethash "input_schema" result)
              (dict "type" "object"
                    "properties"
                    (apply #'dict
                           (loop for p in params
                                 append (list (%param-name->string (first p))
                                              (dict "type" (%param-type->string (second p))
                                                    "description" (third p)))))
                    "required" (mapcar (lambda (p) (%param-name->string (first p))) params))))
      result)))


(defmethod make-base64-block ((provider anthropic-provider) block-type base64-data media-type)
  (dict "type" "image"
        "source" (dict "type" "base64"
                       "media_type" media-type
                       "data" base64-data)))


;;; Payload

(defun build-payload (provider messages max-tokens)
  (let ((result (dict "model" (provider-model provider)
                      "max_tokens" max-tokens
                      "messages" (coerce messages 'vector)))
        (tools-vec (when (provider-tools provider)
                     (coerce (render-tools-payload provider (provider-tools provider)) 'vector))))
    (when tools-vec
      (setf (gethash "tools" result) tools-vec))
    result))


(defun extract-system (messages)
  "Split messages into (values system-prompt rest-messages).
First message with role=system is extracted."
  (let ((system nil)
        (rest nil))
    (dolist (m messages)
      (if (and (null system)
               (string= (gethash "role" m) "system"))
          (setf system (gethash "content" m))
          (push m rest)))
    (values system (nreverse rest))))


(defun build-payload-with-system (provider messages max-tokens)
  (multiple-value-bind (system rest-messages)
      (extract-system messages)
    (let ((payload (build-payload provider rest-messages max-tokens)))
      (when system
        (setf (gethash "system" payload) system))
      payload)))


;;; Streaming

(defun read-anthropic-sse-stream (stream streaming-callback)
  "Read Anthropic SSE events. Collect tool_use blocks and text deltas.
Return (values text tool-use-blocks usage)."
  (let ((text-parts nil)
        (tool-use-blocks nil)
        (current-tool nil)
        (usage nil))
    (flet ((flush-current-tool ()
             (when current-tool
               (push current-tool tool-use-blocks)
               (setf current-tool nil))))
      (loop for line = (read-line stream nil 'eof)
            when *debug-stream*
              do (format *debug-stream* "~&anthropic line: ~A~%" line)
            until (eq line 'eof)
            when (and (> (length line) 6)
                      (or (string= "event:" (take 7 line))
                          (string= "data: " (take 6 line))))
              do (let ((data-start (if (string= "data: " (take 6 line)) 5 -1)))
                   (when (and (>= data-start 0)
                              (> (length line) (1+ data-start)))
                     (let* ((json (json-parse (subseq line (1+ data-start))))
                            (event-type (gethash "type" json)))
                       (cond
                         ((string= event-type "content_block_delta")
                          (let ((delta (gethash "delta" json)))
                            (cond
                              ((string= (gethash "type" delta) "text_delta")
                               (let ((text (gethash "text" delta)))
                                 (push text text-parts)
                                 (when streaming-callback
                                   (funcall streaming-callback text))))
                              ((string= (gethash "type" delta) "input_json_delta")
                               (when current-tool
                                 (let ((partial (gethash "partial_json" delta)))
                                   (setf (getf current-tool :input-json)
                                         (concatenate 'string
                                                      (getf current-tool :input-json)
                                                      partial))))))))
                         ((string= event-type "content_block_start")
                          (let* ((block (gethash "content_block" json))
                                 (block-type (gethash "type" block)))
                            (cond
                              ((string= block-type "tool_use")
                               (setf current-tool
                                     (list :id (gethash "id" block)
                                           :name (gethash "name" block)
                                           :input-json "")))
                              ((string= block-type "text")
                               nil))))
                         ((string= event-type "content_block_stop")
                          (flush-current-tool))
                         ((string= event-type "message_delta")
                          (let ((delta (gethash "delta" json))
                                (msg-usage (gethash "usage" json)))
                            (declare (ignore delta))
                            (when msg-usage
                              (setf usage msg-usage))))
                         ((string= event-type "message_start")
                          (let* ((msg (gethash "message" json))
                                 (msg-usage (gethash "usage" msg)))
                            (when msg-usage
                              (setf usage msg-usage))))))))))
    (values (apply #'concatenate 'string (nreverse text-parts))
            (nreverse tool-use-blocks)
            usage)))


;;; Tool execution

(defun exec-anthropic-tool-calls (provider tool-blocks)
  "Execute tool calls from Anthropic content blocks."
  (loop for block in tool-blocks
        for call-id = (getf block :id)
        for fn-name = (getf block :name)
        for raw-input = (getf block :input-json)
        for args = (if (and raw-input (string/= raw-input ""))
                       (json-parse raw-input)
                       (dict))
        collect (multiple-value-bind (result _cid)
                    (call-tool provider fn-name args)
                  (declare (ignore _cid))
                  (dict "role" "user"
                        "content" (vector
                                   (dict "type" "tool_result"
                                         "tool_use_id" call-id
                                         "content" result))))))


(defun make-anthropic-tool-response (tool-blocks)
  "Build assistant message with tool_use content blocks."
  (dict "role" "assistant"
        "content" (coerce
                   (loop for block in tool-blocks
                         collect (dict "type" "tool_use"
                                       "id" (getf block :id)
                                       "name" (getf block :name)
                                       "input" (let ((raw (getf block :input-json)))
                                                 (if (and raw (string/= raw ""))
                                                     (json-parse raw)
                                                     (dict)))))
                   'vector)))


;;; Main loop

(defun anthropic-streaming-loop (provider endpoint headers messages max-tokens streaming-callback)
  (let* ((content (json-encode (build-payload-with-system provider messages max-tokens)))
         (stream (safe-http-request endpoint
                                    :read-timeout *read-timeout*
                                    :content content
                                    :headers headers
                                    :want-stream t)))
    (unwind-protect
         (multiple-value-bind (text tool-blocks usage)
             (with-budget-guard (provider)
               (read-anthropic-sse-stream stream streaming-callback))
           (when usage
             (when-let ((in (gethash "input_tokens" usage)))
               (incf (prompt-token-count provider) in))
             (when-let ((out (gethash "output_tokens" usage)))
               (incf (completion-token-count provider) out)))
           (if tool-blocks
               (let* ((assistant-msg (make-anthropic-tool-response tool-blocks))
                      (tool-answers (exec-anthropic-tool-calls provider tool-blocks)))
                 (anthropic-streaming-loop
                  provider endpoint headers
                  (append messages (list assistant-msg) tool-answers)
                  max-tokens streaming-callback))
               (values text
                       (append1 messages (make-message "assistant" text)))))
      (close stream))))


(defun anthropic-non-streaming-loop (provider endpoint headers messages max-tokens)
  (let* ((content (json-encode (build-payload-with-system provider messages max-tokens)))
         (result (with-budget-guard (provider)
                   (let* ((ba (safe-http-request endpoint
                                                 :read-timeout *read-timeout*
                                                 :content content
                                                 :headers headers
                                                 :force-binary t
                                                 :want-stream nil))
                          (parsed (json-parse (convert-byte-array-to-utf8 ba))))
                     (when *debug-stream*
                       (format *debug-stream* "~&anthropic response: ~A~%" parsed))
                     (when-let ((usage (gethash "usage" parsed)))
                       (incf (prompt-token-count provider)
                             (or (gethash "input_tokens" usage) 0))
                       (incf (completion-token-count provider)
                             (or (gethash "output_tokens" usage) 0)))
                     parsed))))
    (let ((content-blocks (gethash "content" result))
          (stop-reason (gethash "stop_reason" result)))
      (declare (ignore stop-reason))
      (let ((text nil)
            (tool-blocks nil))
        (when content-blocks
          (loop for block across content-blocks
                for block-type = (gethash "type" block)
                do (cond
                     ((string= block-type "text")
                      (setf text (gethash "text" block)))
                     ((string= block-type "tool_use")
                      (push (list :id (gethash "id" block)
                                  :name (gethash "name" block)
                                  :input-json (json-encode (gethash "input" block)))
                            tool-blocks)))))
        (if tool-blocks
            (let* ((assistant-msg (make-anthropic-tool-response tool-blocks))
                   (tool-answers (exec-anthropic-tool-calls provider tool-blocks)))
              (anthropic-non-streaming-loop
               provider endpoint headers
               (append messages (list assistant-msg) tool-answers)
               max-tokens))
            (values text
                    (append1 messages (make-message "assistant" text))))))))


(defmethod get-completion ((provider anthropic-provider) messages
                           &key (max-tokens 1024)
                             (streaming-callback nil)
                             (response-format nil))
  (declare (ignore response-format))
  (when (stringp messages)
    (setf messages (list (make-message "user" messages))))
  (with-budget ()
    (with-slots (endpoint api-key) provider
      (let ((headers `(("Content-Type" . "application/json")
                       ("x-api-key" . ,api-key)
                       ("anthropic-version" . ,*anthropic-version*))))
        (if streaming-callback
            (anthropic-streaming-loop provider endpoint headers messages max-tokens streaming-callback)
            (anthropic-non-streaming-loop provider endpoint headers messages max-tokens))))))
