(uiop:define-package #:40ants-ai-agents/llm-provider/gemini
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
                #:render-tool
                #:tool-name
                #:tool-description
                #:tool-parameters
                #:%param-name->string
                #:%param-type->string)
  (:import-from #:alexandria #:when-let)
  (:import-from #:serapeum #:dict #:take #:append1)
  (:export #:gemini-provider))
(in-package #:40ants-ai-agents/llm-provider/gemini)


(defvar *debug-stream* nil)
(defvar *read-timeout* 120)


(defclass gemini-provider (llm-provider)
  ((api-key :initarg :api-key)))


(defun gemini-endpoint (model action api-key)
  (format nil "https://generativelanguage.googleapis.com/v1beta/models/~A:~A?key=~A"
          model action api-key))


(defmethod render-tool-for-api ((provider gemini-provider) tool)
  (with-slots ((name tool-name) (desc tool-description) (params tool-parameters))
      tool
    (let ((result (dict "name" name
                        "description" desc)))
      (when params
        (let ((props (dict))
              (required nil))
          (loop for p in params
                for pname = (%param-name->string (first p))
                for ptype = (%param-type->string (second p))
                for pdesc = (third p)
                do (setf (gethash pname props)
                         (dict "type" (string-upcase ptype)
                               "description" pdesc))
                   (push pname required))
          (setf (gethash "parameters" result)
                (dict "type" "OBJECT"
                      "properties" props
                      "required" (nreverse required)))))
      result)))


(defun render-tools-payload-gemini (provider)
  (let ((tools (provider-tools provider)))
    (when tools
      (list (dict "functionDeclarations"
                  (coerce
                   (loop for sym in tools
                         for tool = (gethash (symbol-name sym)
                                             40ants-ai-agents/tool:*tools*)
                         unless tool
                           do (error "Undefined tool function: ~A" sym)
                         collect (render-tool-for-api provider tool))
                   'vector))))))


(defmethod make-base64-block ((provider gemini-provider) block-type base64-data media-type)
  (dict "inline_data" (dict "mime_type" media-type
                            "data" base64-data)))


;;; Message conversion: OpenAI-style → Gemini-style

(defun convert-role (role)
  (cond
    ((string= role "assistant") "model")
    ((string= role "tool") "user")
    (t role)))


(defun convert-messages-to-contents (messages)
  (let ((contents nil)
        (system-instruction nil))
    (dolist (m messages)
      (let ((role (gethash "role" m))
            (content (gethash "content" m)))
        (cond
          ((string= role "system")
           (setf system-instruction
                 (dict "parts" (vector (dict "text" content)))))
          ((string= role "tool")
           (let ((fn-name (gethash "tool_name" m)))
             (push (dict "role" "user"
                         "parts" (vector
                                  (dict "functionResponse"
                                        (dict "name" fn-name
                                              "response" (dict "result" content)))))
                   contents)))
          (t
           (push (dict "role" (convert-role role)
                       "parts" (vector (dict "text" content)))
                 contents)))))
    (values (nreverse contents) system-instruction)))


(defun convert-messages-with-tool-calls (messages tool-call-infos)
  (let ((contents nil)
        (system-instruction nil))
    (dolist (m messages)
      (let ((role (gethash "role" m))
            (content (gethash "content" m)))
        (cond
          ((string= role "system")
           (setf system-instruction
                 (dict "parts" (vector (dict "text" content)))))
          (t
           (push (dict "role" (convert-role role)
                       "parts" (vector (dict "text" (or content ""))))
                 contents)))))
    (dolist (info tool-call-infos)
      (let ((call-id (getf info :id))
            (fn-name (getf info :name))
            (args (getf info :args)))
        (push (dict "role" "model"
                    "parts" (vector
                             (dict "functionCall"
                                   (append (list "name" fn-name
                                                 "args" args)
                                           (when call-id (list "id" call-id))))))
              contents)))
    (values (nreverse contents) system-instruction)))


;;; Payload

(defun build-payload (provider contents system-instruction &key streaming-p)
  (declare (ignore streaming-p))
  (let ((result (dict "contents" (coerce contents 'vector)))
        (tools-payload (render-tools-payload-gemini provider)))
    (when system-instruction
      (setf (gethash "systemInstruction" result) system-instruction))
    (when tools-payload
      (setf (gethash "tools" result) (coerce tools-payload 'vector)))
    result))


;;; Extract function calls from Gemini response

(defun extract-function-calls (result)
  (let* ((candidates (gethash "candidates" result))
         (content (when (and candidates (> (length candidates) 0))
                    (gethash "content" (aref candidates 0))))
         (parts (when content (gethash "parts" content))))
    (when parts
      (loop for part across parts
            when (gethash "functionCall" part)
              collect (let ((fc (gethash "functionCall" part)))
                        (list :id (gethash "id" fc)
                              :name (gethash "name" fc)
                              :args (or (gethash "args" fc) (dict))))))))


(defun extract-text-from-response (result)
  (let* ((candidates (gethash "candidates" result))
         (content (when (and candidates (> (length candidates) 0))
                    (gethash "content" (aref candidates 0))))
         (parts (when content (gethash "parts" content))))
    (when parts
      (with-output-to-string (s)
        (loop for part across parts
              when (gethash "text" part)
                do (princ (gethash "text" part) s))))))


(defun extract-gemini-usage (result provider)
  (when-let ((usage (gethash "usageMetadata" result)))
    (when-let ((pt (gethash "promptTokenCount" usage)))
      (incf (prompt-token-count provider) pt))
    (when-let ((ct (gethash "candidatesTokenCount" usage)))
      (incf (completion-token-count provider) ct))))


;;; Tool execution

(defun exec-gemini-tool-calls (provider tool-calls)
  (loop for tc in tool-calls
        for call-id = (getf tc :id)
        for fn-name = (getf tc :name)
        for args = (getf tc :args)
        collect (multiple-value-bind (result _cid)
                    (call-tool provider fn-name args)
                  (declare (ignore _cid))
                  (dict "role" "user"
                        "parts" (vector
                                 (dict "functionResponse"
                                       (append (list "name" fn-name
                                                     "response" (dict "result" result))
                                               (when call-id (list "id" call-id)))))))))


(defun make-model-tool-call-content (tool-calls)
  (dict "role" "model"
        "parts" (coerce
                 (loop for tc in tool-calls
                       collect (dict "functionCall"
                                     (append (list "name" (getf tc :name)
                                                   "args" (getf tc :args))
                                             (when (getf tc :id)
                                               (list "id" (getf tc :id))))))
                 'vector)))


;;; Streaming

(defun read-gemini-sse-stream (stream streaming-callback)
  (loop for line = (read-line stream nil 'eof)
        when *debug-stream*
          do (format *debug-stream* "~&gemini line: ~A~%" line)
        until (eq line 'eof)
        when (and (> (length line) 6)
                  (string= "data: " (take 6 line)))
          collect (let ((json (json-parse (subseq line 6))))
                    (let* ((candidates (gethash "candidates" json))
                           (content (when (and candidates (> (length candidates) 0))
                                      (gethash "content" (aref candidates 0))))
                           (parts (when content (gethash "parts" content))))
                      (when parts
                        (loop for part across parts
                              for text = (gethash "text" part)
                              when (and text streaming-callback)
                                do (funcall streaming-callback text))))
                    json)))


(defun find-function-calls-in-stream (objs)
  (let ((all-calls nil))
    (dolist (obj objs)
      (let* ((candidates (gethash "candidates" obj))
             (content (when (and candidates (> (length candidates) 0))
                        (gethash "content" (aref candidates 0))))
             (parts (when content (gethash "parts" content))))
        (when parts
          (loop for part across parts
                when (gethash "functionCall" part)
                  do (let ((fc (gethash "functionCall" part)))
                       (push (list :id (gethash "id" fc)
                                   :name (gethash "name" fc)
                                   :args (or (gethash "args" fc) (dict)))
                             all-calls))))))
    (nreverse all-calls)))


(defun extract-stream-text (objs)
  (with-output-to-string (s)
    (dolist (obj objs)
      (let* ((candidates (gethash "candidates" obj))
             (content (when (and candidates (> (length candidates) 0))
                        (gethash "content" (aref candidates 0))))
             (parts (when content (gethash "parts" content))))
        (when parts
          (loop for part across parts
                when (gethash "text" part)
                  do (princ (gethash "text" part) s)))))))


;;; Main loop

(defun gemini-non-streaming-loop (provider endpoint headers messages)
  (multiple-value-bind (contents sys-instr)
      (convert-messages-to-contents messages)
    (let* ((payload (build-payload provider contents sys-instr))
           (result (with-budget-guard (provider)
                     (let* ((ba (safe-http-request endpoint
                                                   :read-timeout *read-timeout*
                                                   :content (json-encode payload)
                                                   :headers headers
                                                   :force-binary t
                                                   :want-stream nil))
                            (parsed (json-parse (convert-byte-array-to-utf8 ba))))
                       (when *debug-stream*
                         (format *debug-stream* "~&gemini response: ~A~%" parsed))
                       (extract-gemini-usage parsed provider)
                       parsed))))
      (let ((tool-calls (extract-function-calls result)))
        (if tool-calls
            (let* ((model-content (make-model-tool-call-content tool-calls))
                   (tool-answers (exec-gemini-tool-calls provider tool-calls))
                   (new-contents (append contents (list model-content) tool-answers))
                   (new-messages (append messages
                                         (list (make-message "assistant" ""))
                                         (loop for ta in tool-answers
                                               collect (make-message "tool"
                                                                     (gethash "result"
                                                                              (gethash "response"
                                                                                       (aref (gethash "parts" ta) 0))))))))
              (gemini-non-streaming-loop-2 provider endpoint headers new-contents sys-instr new-messages))
            (let ((text (extract-text-from-response result)))
              (values text
                      (append1 messages (make-message "assistant" (or text ""))))))))))


(defun gemini-non-streaming-loop-2 (provider endpoint headers contents sys-instr original-messages)
  (let* ((payload (build-payload provider contents sys-instr))
         (result (with-budget-guard (provider)
                   (let* ((ba (safe-http-request endpoint
                                                 :read-timeout *read-timeout*
                                                 :content (json-encode payload)
                                                 :headers headers
                                                 :force-binary t
                                                 :want-stream nil))
                          (parsed (json-parse (convert-byte-array-to-utf8 ba))))
                     (when *debug-stream*
                       (format *debug-stream* "~&gemini response: ~A~%" parsed))
                     (extract-gemini-usage parsed provider)
                     parsed))))
    (let ((tool-calls (extract-function-calls result)))
      (if tool-calls
          (let* ((model-content (make-model-tool-call-content tool-calls))
                 (tool-answers (exec-gemini-tool-calls provider tool-calls))
                 (new-contents (append contents (list model-content) tool-answers)))
            (gemini-non-streaming-loop-2 provider endpoint headers new-contents sys-instr original-messages))
          (let ((text (extract-text-from-response result)))
            (values text
                    (append1 original-messages (make-message "assistant" (or text "")))))))))


(defun gemini-streaming-loop (provider endpoint headers messages streaming-callback)
  (multiple-value-bind (contents sys-instr)
      (convert-messages-to-contents messages)
    (let* ((payload (build-payload provider contents sys-instr :streaming-p t))
           (objs (with-budget-guard (provider)
                   (let ((stream (safe-http-request endpoint
                                                    :read-timeout *read-timeout*
                                                    :content (json-encode payload)
                                                    :headers headers
                                                    :want-stream t)))
                     (unwind-protect
                          (read-gemini-sse-stream stream streaming-callback)
                       (close stream))))))
      (let ((last-obj (car (last objs))))
        (when last-obj
          (extract-gemini-usage last-obj provider)))
      (let ((tool-calls (find-function-calls-in-stream objs)))
        (if tool-calls
            (let* ((model-content (make-model-tool-call-content tool-calls))
                   (tool-answers (exec-gemini-tool-calls provider tool-calls))
                   (new-contents (append contents (list model-content) tool-answers)))
              (gemini-streaming-loop-2 provider endpoint headers new-contents sys-instr messages streaming-callback))
            (let ((text (extract-stream-text objs)))
              (values text
                      (append1 messages (make-message "assistant" (or text ""))))))))))


(defun gemini-streaming-loop-2 (provider endpoint headers contents sys-instr original-messages streaming-callback)
  (let* ((payload (build-payload provider contents sys-instr :streaming-p t))
         (objs (with-budget-guard (provider)
                 (let ((stream (safe-http-request endpoint
                                                  :read-timeout *read-timeout*
                                                  :content (json-encode payload)
                                                  :headers headers
                                                  :want-stream t)))
                   (unwind-protect
                        (read-gemini-sse-stream stream streaming-callback)
                     (close stream))))))
    (let ((last-obj (car (last objs))))
      (when last-obj
        (extract-gemini-usage last-obj provider)))
    (let ((tool-calls (find-function-calls-in-stream objs)))
      (if tool-calls
          (let* ((model-content (make-model-tool-call-content tool-calls))
                 (tool-answers (exec-gemini-tool-calls provider tool-calls))
                 (new-contents (append contents (list model-content) tool-answers)))
            (gemini-streaming-loop-2 provider endpoint headers new-contents sys-instr original-messages streaming-callback))
          (let ((text (extract-stream-text objs)))
            (values text
                    (append1 original-messages (make-message "assistant" (or text "")))))))))


;;; Entry point

(defmethod get-completion ((provider gemini-provider) messages
                           &key (max-tokens 1024)
                             (streaming-callback nil)
                             (response-format nil))
  (declare (ignore max-tokens response-format))
  (when (stringp messages)
    (setf messages
          (list (make-message "user" messages))))
  (with-budget ()
    (with-slots (api-key) provider
      (let* ((model (provider-model provider))
             (headers '(("Content-Type" . "application/json")))
             (endpoint (if streaming-callback
                           (gemini-endpoint model "streamGenerateContent" api-key)
                           (gemini-endpoint model "generateContent" api-key))))
        (if streaming-callback
            (gemini-streaming-loop provider endpoint headers messages streaming-callback)
            (gemini-non-streaming-loop provider endpoint headers messages))))))
