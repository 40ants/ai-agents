(uiop:define-package #:40ants-ai-agents/llm-provider/ollama
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
  (:export #:ollama-provider))
(in-package #:40ants-ai-agents/llm-provider/ollama)


(defvar *debug-stream* nil)
(defvar *read-timeout* 120)


(defclass ollama-provider (llm-provider)
  ((endpoint :initarg :endpoint
             :initform "http://localhost:11434/api/chat")))


(defmethod render-tool-for-api ((provider ollama-provider) tool)
  (render-tool tool))


(defmethod make-base64-block ((provider ollama-provider) block-type base64-data media-type)
  (dict "type" "image_url"
        "image_url" (dict "url"
                          (format nil "data:~A;base64,~A" media-type base64-data))))


;;; Helpers

(defun make-tool-answer-message (fn-name content)
  (dict "role" "tool" "tool_name" fn-name "content" content))

(defun make-assistant-tool-call-message (tool-calls)
  (let ((calls (loop for tc in tool-calls
                     collect (dict "function"
                                   (dict "name" (gethash "name" (gethash "function" tc))
                                         "arguments" (gethash "arguments" (gethash "function" tc)))))))
    (dict "role" "assistant"
          "content" ""
          "tool_calls" (coerce calls 'vector))))


(defun render-tools-vec (provider)
  (let ((tools (provider-tools provider)))
    (when tools
      (coerce (render-tools-payload provider tools) 'vector))))


;;; Payload

(defun build-payload (provider messages streaming-p)
  (let ((result (dict
                  "model" (provider-model provider)
                  "stream" (if streaming-p yason:true yason:false)
                  "messages" (coerce messages 'vector)))
        (tools-vec (render-tools-vec provider)))
    (when tools-vec
      (setf (gethash "tools" result) tools-vec))
    result))


;;; Streaming

(defun read-ollama-stream (stream streaming-callback)
  (loop for line = (read-line stream nil 'eof)
        when *debug-stream*
          do (format *debug-stream* "~&ollama line: ~A~%" line)
        until (eq line 'eof)
        when (and (> (length line) 0)
                  (char/= (char line 0) #\}))
          do (let ((json (json-parse line)))
               (let ((msg (gethash "message" json))
                     (done (gethash "done" json)))
                 (when (and msg (not done))
                   (when-let ((text (gethash "content" msg)))
                     (when (and streaming-callback (string/= text ""))
                       (funcall streaming-callback text))))
                 json))))


(defun extract-stream-text (objs)
  (with-output-to-string (s)
    (loop for obj in objs
          for msg = (gethash "message" obj)
          for done = (gethash "done" obj)
          when (and msg (not done))
            do (when-let ((text (gethash "content" msg)))
                 (princ text s)))))


(defun find-tool-calls-in-stream (objs)
  (loop for obj in objs
        for msg = (gethash "message" obj)
        when (and msg (gethash "tool_calls" msg))
          return (gethash "tool_calls" msg)))


(defun extract-ollama-usage (obj provider)
  (when-let ((prompt-count (gethash "prompt_eval_count" obj)))
    (incf (prompt-token-count provider) prompt-count))
  (when-let ((eval-count (gethash "eval_count" obj)))
    (incf (completion-token-count provider) eval-count)))


(defun exec-ollama-tool-calls (provider tool-calls)
  (loop for tc across tool-calls
        for func = (gethash "function" tc)
        for fn-name = (gethash "name" func)
        for args = (or (gethash "arguments" func) (dict))
        collect (multiple-value-bind (result _cid)
                    (call-tool provider fn-name args)
                  (declare (ignore _cid))
                  (make-tool-answer-message fn-name result))))


;;; Main loop

(defun ollama-streaming-loop (provider endpoint headers messages streaming-callback)
  (let* ((content (json-encode (build-payload provider messages t)))
         (objs (with-budget-guard (provider)
                 (let ((stream (safe-http-request endpoint
                                                  :read-timeout *read-timeout*
                                                  :content content
                                                  :headers headers
                                                  :want-stream t)))
                   (unwind-protect
                        (read-ollama-stream stream streaming-callback)
                     (close stream))))))
    (let ((last-obj (car (last objs))))
      (when last-obj
        (extract-ollama-usage last-obj provider)))
    (let ((tool-calls (find-tool-calls-in-stream objs)))
      (if tool-calls
          (let* ((tool-list (coerce tool-calls 'list))
                 (tool-answers (exec-ollama-tool-calls provider tool-calls))
                 (assistant-msg (make-assistant-tool-call-message tool-list)))
            (ollama-streaming-loop
             provider endpoint headers
             (append messages (list assistant-msg) tool-answers)
             streaming-callback))
          (let ((response (extract-stream-text objs)))
            (values response
                    (append1 messages (make-message "assistant" response))))))))


(defun ollama-non-streaming-loop (provider endpoint headers messages)
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
                       (format *debug-stream* "~&ollama response: ~A~%" parsed))
                     (extract-ollama-usage parsed provider)
                     parsed))))
    (let ((msg (gethash "message" result))
          (tool-calls-raw (gethash "tool_calls" (gethash "message" result))))
      (if tool-calls-raw
          (let* ((tool-list (coerce tool-calls-raw 'list))
                 (tool-answers (exec-ollama-tool-calls provider tool-calls-raw))
                 (assistant-msg (make-assistant-tool-call-message tool-list)))
            (ollama-non-streaming-loop
             provider endpoint headers
             (append messages (list assistant-msg) tool-answers)))
          (let ((response (when msg (gethash "content" msg))))
            (values response
                    (append1 messages (make-message "assistant" response))))))))


(defmethod get-completion ((provider ollama-provider) messages
                           &key (max-tokens 1024)
                             (streaming-callback nil)
                             (response-format nil))
  (declare (ignore max-tokens response-format))
  (when (stringp messages)
    (setf messages
          (list (make-message "user" messages))))
  (with-budget ()
    (with-slots (endpoint) provider
      (let ((headers '(("Content-Type" . "application/json"))))
        (if streaming-callback
            (ollama-streaming-loop provider endpoint headers messages streaming-callback)
            (ollama-non-streaming-loop provider endpoint headers messages))))))
