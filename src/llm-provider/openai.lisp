(uiop:define-package #:40ants-ai-agents/llm-provider/openai
  (:use #:cl)
  (:import-from #:40ants-ai-agents/llm-provider
                #:llm-provider
                #:provider-model
                #:provider-tools
                #:prompt-token-count
                #:completion-token-count
                #:get-completion
                #:get-single-completion
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
                #:render-tool)
  (:import-from #:alexandria #:when-let)
  (:import-from #:serapeum #:dict #:take #:drop #:append1)
  (:export #:openai-provider))
(in-package #:40ants-ai-agents/llm-provider/openai)


(defvar *debug-stream* nil)


(defvar *read-timeout* 120)


(defclass openai-provider (llm-provider)
  ((endpoint :initarg :endpoint
             :initform "https://api.openai.com/v1/chat/completions")
   (api-key :initarg :api-key)))


(defmethod render-tool-for-api ((provider openai-provider) tool)
  (render-tool tool))


(defmethod make-base64-block ((provider openai-provider) block-type base64-data media-type)
  (dict "type" "image_url"
        "image_url" (dict "url"
                          (format nil "data:~A;base64,~A" media-type base64-data))))


;;; Helpers

(defun make-tool-answer-message (call-id content)
  (dict "role" "tool" "tool_call_id" call-id "content" content))

(defun make-assistant-tool-call-message (tool-calls)
  (dict "role" "assistant"
        "content" :null
        "tool_calls" (coerce tool-calls 'vector)))


(defun render-tools-vec (provider)
  (let ((tools (provider-tools provider)))
    (when tools
      (coerce (render-tools-payload provider tools) 'vector))))


;;; Payload

(defun build-payload (provider messages streaming-p)
  (let ((result (dict
                  "model" (provider-model provider)
                  "stream" (if streaming-p yason:true yason:false)
                  "messages" (coerce messages 'vector)
                  "max_tokens" 1024))
        (tools-vec (render-tools-vec provider)))
    (when tools-vec
      (setf (gethash "tools" result) tools-vec))
    result))


;;; Streaming

(defun read-streamed-json-objects (stream streaming-callback)
  (loop for line = (read-line stream nil 'eof)
        when *debug-stream*
          do (format *debug-stream* "~&openai line: ~A~%" line)
        until (or (eq line 'eof) (string= "data: [DONE]" line))
        when (and (> (length line) 6)
                  (string= "data: {" (take 7 line)))
          collect (let ((json (json-parse (drop 6 line))))
                    (let* ((choices (gethash "choices" json))
                           (delta (when (and choices (> (length choices) 0))
                                    (gethash "delta" (aref choices 0)))))
                      (when delta
                        (unless (gethash "tool_calls" delta)
                          (when-let ((text (gethash "content" delta)))
                            (funcall streaming-callback text)))))
                    json)))


(defun detect-tool-calls-in-stream (objs)
  (loop for obj in objs
        thereis (let* ((choices (gethash "choices" obj))
                       (delta (when (and choices (> (length choices) 0))
                                (gethash "delta" (aref choices 0)))))
                  (when delta (gethash "tool_calls" delta)))))


(defun accumulate-tool-calls (objs)
  (let ((map (dict)))
    (loop for obj in objs
          for choices = (gethash "choices" obj)
          for delta = (when (and choices (> (length choices) 0))
                        (gethash "delta" (aref choices 0)))
          for tcs = (when delta (gethash "tool_calls" delta))
          when tcs
            do (loop for tc across tcs
                     for id = (gethash "id" tc)
                     for func = (gethash "function" tc)
                     when id
                       do (unless (gethash id map)
                            (setf (gethash id map) (dict "id" id "name" nil "arguments" "")))
                          (when func
                            (let ((name (gethash "name" func))
                                  (args (gethash "arguments" func)))
                              (when name
                                (setf (gethash "name" (gethash id map)) name))
                              (when args
                                (setf (gethash "arguments" (gethash id map))
                                      (concatenate 'string
                                                   (gethash "arguments" (gethash id map))
                                                   args)))))))
    (loop for id being the hash-keys of map
          for data = (gethash id map)
          when (and (gethash "name" data)
                    (not (string= (gethash "arguments" data) "")))
            collect (dict "id" id
                          "function" (dict "name" (gethash "name" data)
                                           "arguments" (gethash "arguments" data))))))


(defun extract-stream-text (objs)
  (with-output-to-string (s)
    (loop for obj in objs
          for choices = (gethash "choices" obj)
          for delta = (when (and choices (> (length choices) 0))
                        (gethash "delta" (aref choices 0)))
          for text = (when delta (gethash "content" delta))
          when text do (princ text s))))


;;; Main loop

(defun openai-streaming-loop (provider endpoint headers messages streaming-callback)
  (let* ((content (json-encode (build-payload provider messages t)))
         (objs (with-budget-guard (provider)
                 (let ((stream (safe-http-request endpoint
                                                  :read-timeout *read-timeout*
                                                  :content content
                                                  :headers headers
                                                  :want-stream t)))
                   (unwind-protect
                        (read-streamed-json-objects stream streaming-callback)
                     (close stream))))))
    (if (detect-tool-calls-in-stream objs)
        (let* ((tool-calls (accumulate-tool-calls objs))
               (tool-answers (exec-tool-calls provider tool-calls))
               (assistant-msg (make-assistant-tool-call-message tool-calls)))
          (openai-streaming-loop
           provider endpoint headers
           (append messages (list assistant-msg) tool-answers)
           streaming-callback))
        (let ((response (extract-stream-text objs)))
          (values response
                  (append1 messages (make-message "assistant" response)))))))


(defun extract-non-streaming-data (result provider)
  "Extract usage info from RESULT and return (values tool-calls-or-nil response-text)."
  (when-let ((usage (gethash "usage" result)))
    (setf (prompt-token-count provider)
          (or (gethash "prompt_tokens" usage) 0))
    (setf (completion-token-count provider)
          (or (gethash "completion_tokens" usage) 0)))
  (let* ((choices (gethash "choices" result))
         (choice (when (and choices (> (length choices) 0))
                   (aref choices 0)))
         (msg (when choice (gethash "message" choice))))
    (values (when msg (gethash "tool_calls" msg))
            (when msg (gethash "content" msg)))))


(defun openai-non-streaming-loop (provider endpoint headers messages)
  (let* ((content (json-encode (build-payload provider messages nil)))
         (result (with-budget-guard (provider)
                   (let* ((ba (safe-http-request endpoint
                                                 :read-timeout *read-timeout*
                                                 :content content
                                                 :headers headers
                                                 :force-binary t
                                                 :want-stream nil))
                          (parsed (json-parse (convert-byte-array-to-utf8 ba))))
                     (when *debug-stream*
                       (format *debug-stream* "~&openai response: ~A~%" parsed))
                     parsed))))
    (multiple-value-bind (tool-calls response-text)
        (extract-non-streaming-data result provider)
      (if tool-calls
          (let* ((tool-answers (exec-tool-calls provider (coerce tool-calls 'list)))
                 (assistant-msg (make-assistant-tool-call-message tool-calls)))
            (openai-non-streaming-loop
             provider endpoint headers
             (append messages (list assistant-msg) tool-answers)))
          (values response-text
                  (append1 messages (make-message "assistant" response-text)))))))


(defmethod get-completion ((provider openai-provider) messages
                           &key (max-tokens 1024)
                             (streaming-callback nil)
                             (response-format nil))
  (declare (ignore max-tokens response-format))
  (when (stringp messages)
    (setf messages
          (list (make-message "user" messages))))
  (with-budget ()
    (with-slots (endpoint api-key) provider
      (let ((headers `(("Content-Type" . "application/json")
                       ("Authorization" . ,(concatenate 'string "Bearer " api-key)))))
        (if streaming-callback
            (openai-streaming-loop provider endpoint headers messages streaming-callback)
            (openai-non-streaming-loop provider endpoint headers messages))))))


(defmethod get-single-completion ((provider openai-provider) messages &key)
  (with-slots (endpoint api-key) provider
    (let* ((headers `(("Content-Type" . "application/json")
                      ("Authorization" . ,(concatenate 'string "Bearer " api-key))))
           (payload (build-payload provider messages nil))
           (content (json-encode payload))
           (result (with-budget-guard (provider)
                     ;; (break)
                     (let* ((ba (safe-http-request endpoint
                                                   :read-timeout *read-timeout*
                                                   :content content
                                                   :headers headers
                                                   :force-binary t
                                                   :want-stream nil))
                            (parsed (json-parse (convert-byte-array-to-utf8 ba))))
                       parsed))))
      (multiple-value-bind (tool-calls response-text)
          (extract-non-streaming-data result provider)
        (cond
          (tool-calls
           (let ((tool-calls-list (coerce tool-calls 'list)))
             (values :tool-calls
                     tool-calls-list
                     (append messages
                             (list (make-assistant-tool-call-message tool-calls-list))))))
          (t
           (values :text
                   response-text
                   (append1 messages (make-message "assistant" response-text)))))))))
