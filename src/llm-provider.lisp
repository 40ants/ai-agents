(uiop:define-package #:40ants-ai-agents/llm-provider
  (:use #:cl)
  (:import-from #:cl-base64)
  (:import-from #:str)
  (:import-from #:babel)
  (:import-from #:dex)
  (:import-from #:event-emitter)
  (:import-from #:alexandria
                #:when-let)
  (:import-from #:serapeum
                #:dict
                #:append1)
  (:import-from #:40ants-ai-agents/tool
                #:invoke-tool
                #:*tools*
                #:render-tool)
  (:import-from #:40ants-ai-agents/utils
                #:json-encode
                #:json-parse)
  (:export #:llm-provider
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
           #:total-tokens-used
           #:reset-token-counts
           #:budget-exceeded
           #:budget-exceeded-reason
           #:budget-exceeded-message
           #:*max-turns*
           #:*max-cost-usd*
           #:*cost-fn*
           #:with-budget
           #:with-budget-guard
           #:make-message
           #:make-text-block
           #:make-base64-block
           #:make-content-blocks
           #:file-to-base64
           #:media-type-from-path
           #:make-file-block
           #:json-encode
           #:json-parse
           #:safe-http-request
           #:convert-byte-array-to-utf8))
(in-package #:40ants-ai-agents/llm-provider)


(defvar *call-id-counter* 0)


(defclass llm-provider (event-emitter:event-emitter)
  ((model :initarg :model :reader provider-model)
   (tools :initarg :tools :initform nil :reader provider-tools)
   (prompt-token-count :initform 0 :accessor prompt-token-count)
   (completion-token-count :initform 0 :accessor completion-token-count)))


(defgeneric get-completion (provider messages &key max-tokens streaming-callback response-format)
  (:documentation "Send MESSAGES to the LLM and return (values text updated-messages)."))


(defgeneric get-single-completion (provider messages &key streaming-callback &allow-other-keys)
  (:documentation "Single LLM API call without tool loop.
Returns (values :text response-text updated-messages)
     or (values :tool-calls tool-calls-list updated-messages).
When STREAMING-CALLBACK is provided, it is called with each text chunk from the LLM response."))


(defgeneric call-tool (provider tool-name args)
  (:documentation "Invoke tool TOOL-NAME with ARGS via the tool registry.
Emit :tool-call and :tool-result events. :around methods allow interception."))


(defgeneric render-tool-for-api (provider tool)
  (:documentation "Render a function-tool into the provider-specific API format."))


(defgeneric total-tokens-used (provider))


(defgeneric reset-token-counts (provider))


(defgeneric make-text-block (provider text))


(defgeneric make-base64-block (provider block-type base64-data media-type))


(defgeneric make-content-blocks (provider &rest blocks))


(defmethod call-tool ((provider llm-provider) tool-name args)
  (let ((call-id (format nil "call_~A" (incf *call-id-counter*))))
    (event-emitter:emit :tool-call provider call-id tool-name args)
    (let ((result (invoke-tool tool-name args)))
      (event-emitter:emit :tool-result provider call-id result)
      (values result call-id))))


(defmethod total-tokens-used ((provider llm-provider))
  (+ (prompt-token-count provider) (completion-token-count provider)))


(defmethod reset-token-counts ((provider llm-provider))
  (setf (prompt-token-count provider) 0
        (completion-token-count provider) 0))


(defmethod make-text-block ((provider llm-provider) text)
  (dict "type" "text" "text" text))


(defmethod make-content-blocks ((provider llm-provider) &rest blocks)
  (coerce blocks 'vector))


(defun make-message (role content)
  "Create a chat message hash-table with ROLE and CONTENT."
  (dict "role" role "content" content))


(defun render-tools-payload (provider tool-symbols)
  "Render each tool symbol into the provider-specific format."
  (loop for sym in tool-symbols
        for tool = (gethash (symbol-name sym) *tools*)
        unless tool
          do (error "Undefined tool function: ~A" sym)
        collect (render-tool-for-api provider tool)))


(defun exec-tool-calls (provider tool-calls)
  "Execute tool calls (a list of hash-tables) and return list of tool-answer hash-tables.
Each call must have \"id\" and \"function\" (with \"name\" and \"arguments\") keys."
  (loop for tc in tool-calls
        for call-id = (gethash "id" tc)
        for func = (gethash "function" tc)
        for fn-name = (gethash "name" func)
        for raw-args = (gethash "arguments" func)
        for args = (json-parse raw-args)
        collect (multiple-value-bind (result _cid)
                    (call-tool provider fn-name args)
                  (declare (ignore _cid))
                  (dict "role" "tool"
                        "tool_call_id" call-id
                        "content" result))))



;;; Budget system

(defvar *max-turns* nil)
(defvar *max-cost-usd* nil)
(defvar *cost-fn* nil)
(defvar *turns-used* 0)
(defvar *cost-used* 0.0d0)

(define-condition budget-exceeded (error)
  ((reason :initarg :reason :reader budget-exceeded-reason)
   (message :initarg :message :reader budget-exceeded-message))
  (:report (lambda (c s) (write-string (budget-exceeded-message c) s))))

(defun check-budget ()
  (incf *turns-used*)
  (when (and *max-turns* (> *turns-used* *max-turns*))
    (restart-case
        (error 'budget-exceeded
               :reason :max-turns
               :message (format nil "Exceeded max-turns limit of ~A (used: ~A)."
                                 *max-turns* *turns-used*))
      (disable-turns-limit ()
        :report "Disable the turns limit."
        (setf *max-turns* nil))
      (increase-turns-limit (&optional (n *max-turns*))
        :report "Increase the turns limit."
        (setf *max-turns* (+ *max-turns* n)))))
  (when (and *cost-fn* *max-cost-usd* (> *cost-used* *max-cost-usd*))
    (restart-case
        (error 'budget-exceeded
               :reason :max-cost
               :message (format nil "Exceeded max-cost-usd limit of $~,4F (accumulated: $~,4F)."
                                 *max-cost-usd* *cost-used*))
      (disable-cost-limit ()
        :report "Disable the cost limit."
        (setf *max-cost-usd* nil))
      (increase-cost-limit (&optional (amount *max-cost-usd*))
        :report "Increase the cost limit."
        (setf *max-cost-usd* (+ *max-cost-usd* amount))))))

(defmacro with-budget (() &body body)
  `(let ((*max-turns* *max-turns*)
         (*max-cost-usd* *max-cost-usd*)
         (*turns-used* 0)
         (*cost-used* 0.0d0))
     ,@body))

(defmacro with-budget-guard ((provider) &body body)
  (let ((tokens-in-before (gensym "TOKENS-IN-"))
        (tokens-out-before (gensym "TOKENS-OUT-")))
    `(let ((,tokens-in-before (prompt-token-count ,provider))
           (,tokens-out-before (completion-token-count ,provider)))
       (check-budget)
       (multiple-value-prog1
           (progn ,@body)
         (when *cost-fn*
           (let ((delta-in (- (prompt-token-count ,provider) ,tokens-in-before))
                 (delta-out (- (completion-token-count ,provider) ,tokens-out-before)))
             (when (or (plusp delta-in) (plusp delta-out))
               (incf *cost-used* (funcall *cost-fn* delta-in delta-out)))))))))



;;; Multimedia helpers

(defun file-to-base64 (path)
  (with-open-file (stream path :element-type '(unsigned-byte 8))
    (let* ((length (file-length stream))
           (bytes (make-array length :element-type '(unsigned-byte 8))))
      (read-sequence bytes stream)
      (cl-base64:usb8-array-to-base64-string bytes))))

(defun media-type-from-path (path)
  (let ((ext (string-downcase (pathname-type (pathname path)))))
    (cond ((string= ext "png") "image/png")
          ((string= ext "jpg") "image/jpeg")
          ((string= ext "jpeg") "image/jpeg")
          ((string= ext "gif") "image/gif")
          ((string= ext "webp") "image/webp")
          ((string= ext "pdf") "application/pdf")
          (t (format nil "application/~A" ext)))))

(defun make-file-block (provider path &optional block-type)
  (let* ((media-type (media-type-from-path path))
         (base64-data (file-to-base64 path))
         (block-type (or block-type
                          (if (str:starts-with-p "image/" media-type)
                              "image"
                              "document"))))
    (make-base64-block provider block-type base64-data media-type)))



;;; HTTP utilities

(defun convert-byte-array-to-utf8 (byte-array)
  (let ((encodings '(:utf-8 :iso-8859-1 :windows-1252)))
    (loop for encoding in encodings
          do (handler-case
                 (return (babel:octets-to-string byte-array :encoding encoding :errorp t))
               (error () nil))
          finally (return (babel:octets-to-string byte-array :encoding :latin-1)))))

(defun safe-http-request (&rest args)
  "Wrapper around dex:post that converts error response bodies from byte arrays to strings."
  (handler-bind
      ((error (lambda (e)
                (when-let ((body (ignore-errors
                                   (typecase e
                                     (dex:http-request-failed
                                      (dex:response-body e))
                                     (otherwise nil)))))
                  (let ((string-body
                          (cond
                            ((typep body '(vector (unsigned-byte 8)))
                             (convert-byte-array-to-utf8 body))
                            ((streamp body)
                             (ignore-errors
                               (prog1
                                   (with-output-to-string (s)
                                     (loop for ch = (read-char body nil nil)
                                           while ch do (write-char ch s)))
                                 (close body))))
                            ((stringp body) body)
                            (t nil))))
                    (when string-body
                      (let* ((uri (princ-to-string (dex:request-uri e)))
                             (qpos (position #\? uri))
                             (safe-uri (if qpos (subseq uri 0 qpos) uri)))
                        (error "HTTP request to ~S failed (status=~A).~%~%~A"
                               safe-uri
                               (dex:response-status e)
                               string-body))))))))
    (apply #'dex:post args)))
