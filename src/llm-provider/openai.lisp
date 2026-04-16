(uiop:define-package #:40ants-ai-agents/llm-provider/openai
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
                #:total-tokens-used
                #:reset-token-counts
                #:make-text-block
                #:make-base64-block
                #:make-content-blocks
                #:with-budget
                #:with-budget-guard
                #:safe-http-request
                #:convert-byte-array-to-utf8)
  (:import-from #:40ants-ai-agents/tool
                #:*tools*
                #:render-tool)
  (:import-from #:alexandria #:when-let)
  (:import-from #:serapeum #:take #:drop #:append1)
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
  (list (cons :type "image_url")
        (cons :image_url
              (list (cons :url
                          (format nil "data:~A;base64,~A"
                                  media-type base64-data))))))


;;; JSON helpers

(defun %json-encode (object)
  (let ((yason:*list-encoder* 'yason:encode-alist)
        (yason:*symbol-key-encoder* #'yason:encode-symbol-as-lowercase)
        (yason:*symbol-encoder* #'yason:encode-symbol-as-lowercase))
    (with-output-to-string (s)
      (yason:encode object s))))


(defun %json-parse (string)
  (let ((yason:*parse-object-key-fn*
          (lambda (key) (intern (string-upcase key) :keyword))))
    (yason:parse string :object-as :alist)))


(defun %aget (key alist)
  (cdr (assoc key alist)))


(defun render-tools-payload (provider tool-symbols)
  (loop for sym in tool-symbols
        for tool = (gethash (symbol-name sym) *tools*)
        unless tool
          do (error "Undefined tool function: ~A" sym)
        collect (render-tool-for-api provider tool)))


;;; Streaming helpers

(defun read-streamed-json-objects (stream streaming-callback)
  (loop for line = (read-line stream nil 'eof)
        when *debug-stream*
          do (format *debug-stream* "~&openai line: ~A~%" line)
        until (or (eq line 'eof) (string= "data: [DONE]" line))
        when (and (> (length line) 6)
                  (string= "data: {" (take 7 line)))
          collect (let ((json (%json-parse (drop 6 line))))
                    (let ((delta (%aget :delta (second (%aget :choices json)))))
                      (unless (%aget :tool_calls delta)
                        (when-let ((text (%aget :content delta)))
                          (funcall streaming-callback text))))
                    json)))


(defun detect-tool-calls-in-stream (objs)
  (loop for obj in objs
        thereis (let* ((choices (%aget :choices obj))
                       (delta (%aget :delta (first choices))))
                  (%aget :tool_calls delta))))


(defun accumulate-tool-calls (objs)
  (let ((map (make-hash-table :test 'equal)))
    (loop for obj in objs
          for delta = (%aget :delta (first (%aget :choices obj)))
          for tcs = (%aget :tool_calls delta)
          when tcs
            do (loop for tc across tcs
                     for id = (%aget :id tc)
                     for func = (%aget :function tc)
                     when id
                       do (unless (gethash id map)
                            (setf (gethash id map)
                                  (list :id id :function nil :arguments "")))
                          (when func
                            (let ((name (%aget :name func))
                                  (args (%aget :arguments func)))
                              (when name
                                (setf (getf (gethash id map) :function) func))
                              (when args
                                (setf (getf (gethash id map) :arguments)
                                      (concatenate 'string
                                                   (getf (gethash id map) :arguments)
                                                    args)))))))
    (loop for id being the hash-keys of map
          for data = (gethash id map)
          when (and (getf data :function)
                    (not (string= (getf data :arguments) "")))
             collect (list (cons :id id)
                           (cons :function (getf data :function))))))


;;; Tool execution

(defun exec-tool-calls (provider tool-calls from-vector)
  "Execute tool calls and return list of tool-answer alists."
  (let ((calls (if from-vector (coerce tool-calls 'list) tool-calls)))
    (loop for tc in calls
          for call-id = (%aget :id tc)
          for func = (%aget :function tc)
          for fn-name = (%aget :name func)
          for raw-args = (%aget :arguments func)
          for args = (%json-parse raw-args)
          collect (multiple-value-bind (result _cid)
                      (call-tool provider fn-name args)
                    (declare (ignore _cid))
                    `(("role" . "tool")
                      ("tool_call_id" . ,call-id)
                      ("content" . ,result))))))


;;; Main loop

(defun build-payload (provider messages streaming-p)
  (let* ((tools (provider-tools provider))
         (tools-rendered (when tools (render-tools-payload provider tools))))
    `(("model" . ,(provider-model provider))
      ("stream" . ,(if streaming-p yason:true yason:false))
      ,@(when tools-rendered
          `(("tools" ,(coerce tools-rendered 'vector))))
      ("messages" ,(coerce messages 'vector))
      ("max_tokens" . 1024))))


(defun openai-streaming-loop (provider endpoint headers messages streaming-callback)
  "Handle streaming OpenAI completion with tool-call loop."
  (let* ((content (%json-encode (build-payload provider messages t)))
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
               (tool-answers (exec-tool-calls provider tool-calls nil))
               (assistant-msgs (loop for tc in tool-calls
                                     collect `(("role" . "assistant")
                                               ("content" . nil)
                                               ("tool_calls" ,(vector tc))))))
          (openai-streaming-loop
           provider endpoint headers
           (append messages assistant-msgs tool-answers)
           streaming-callback))
        (let ((response (with-output-to-string (s)
                          (loop for obj in objs
                                for delta = (%aget :delta (second (%aget :choices obj)))
                                for text = (%aget :content delta)
                                when text do (princ text s)))))
           (values response
                  (append1 messages
                           `(("role" . "assistant") ("content" . ,response))))))))


(defun openai-non-streaming-loop (provider endpoint headers messages)
  "Handle non-streaming OpenAI completion with tool-call loop."
  (let* ((content (%json-encode (build-payload provider messages nil)))
         (result (with-budget-guard (provider)
                   (let* ((ba (safe-http-request endpoint
                                                 :read-timeout *read-timeout*
                                                 :content content
                                                 :headers headers
                                                 :force-binary t
                                                 :want-stream nil))
                          (parsed (%json-parse (convert-byte-array-to-utf8 ba))))
                     (when *debug-stream*
                       (format *debug-stream* "~&openai response: ~A~%" parsed))
                     (when-let ((usage (%aget :usage parsed)))
                       (setf (prompt-token-count provider)
                             (or (%aget :prompt_tokens usage) 0))
                       (setf (completion-token-count provider)
                             (or (%aget :completion_tokens usage) 0)))
                     parsed))))
    (let ((tool-calls (%aget :tool_calls
                      (%aget :message
                       (second (%aget :choices result))))))
      (if tool-calls
          (let* ((tool-answers (exec-tool-calls provider tool-calls t))
                 (assistant-msgs (loop for tc across tool-calls
                                       collect `(("role" . "assistant")
                                                 ("content" . nil)
                                                 ("tool_calls" ,(vector tc))))))
            (openai-non-streaming-loop
             provider endpoint headers
             (append messages assistant-msgs tool-answers)))
           (let ((response (%aget :content
                            (%aget :message
                             (second (%aget :choices result))))))
             (values response
                    (append1 messages
                             `(("role" . "assistant")
                               ("content" . ,response)))))))))


(defmethod get-completion ((provider openai-provider) messages
                           &key (max-tokens 1024)
                             (streaming-callback nil)
                             (response-format nil))
  (declare (ignore max-tokens response-format))
  (when (stringp messages)
    (setf messages `((("role" . "user") ("content" . ,messages)))))
  (with-budget ()
    (with-slots (endpoint api-key) provider
      (let ((headers `(("Content-Type" . "application/json")
                       ("Authorization" . ,(concatenate 'string "Bearer " api-key)))))
        (if streaming-callback
            (openai-streaming-loop provider endpoint headers messages streaming-callback)
            (openai-non-streaming-loop provider endpoint headers messages))))))
