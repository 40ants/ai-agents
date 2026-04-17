(uiop:define-package #:40ants-ai-agents/tool
  (:use #:cl)
  (:import-from #:serapeum
                #:dict
                #:soft-list-of
                #:->)
  (:export #:function-tool
           #:tool-description
           #:tool-name
           #:tool-parameters
           #:tool-fn
           #:defun-tool
           #:*tools*
           #:invoke-tool
           #:map-args-to-parameters
           #:list-available-tools
           #:get-tool-info
           #:render-tool
           #:%param-name->string
           #:%param-type->string))
(in-package #:40ants-ai-agents/tool)


(defclass function-tool ()
  ((description :initarg :description :reader tool-description)
   (name :initarg :name :reader tool-name)
   (parameters :initarg :parameters :reader tool-parameters)
   (fn :initarg :fn :reader tool-fn)))


(defvar *tools* (make-hash-table :test 'equalp)
  "Registry of all defined tools. Keys are tool name strings.")


(defun map-args-to-parameters (fn-tool args)
  "Extract positional arg values from ARGS (hash-table with string keys)
in the order declared by the tool's parameter list."
  (loop for (param-name _param-type _param-desc) in (tool-parameters fn-tool)
        collect (gethash (%param-name->string param-name) args)))


(defun %param-name->string (name)
  (etypecase name
    (string name)
    (symbol (string-downcase (symbol-name name)))))

(defun %param-type->string (type)
  (etypecase type
    (string type)
    (symbol (string-downcase (symbol-name type)))))


(defun render-tool (tool)
  "Render TOOL as an OpenAI-style tool definition hash-table."
  (with-slots (description name parameters) tool
    (let ((props (when parameters
                   (apply #'dict
                          (loop for p in parameters
                                append (list (%param-name->string (first p))
                                             (dict "type" (%param-type->string (second p))
                                                   "description" (third p))))))))
      (dict
       "type" "function"
       "function" (apply #'dict
                         (append (list "name" name
                                       "description" description)
                                 (when parameters
                                   (list "parameters"
                                         (dict "type" "object"
                                               "properties" props
                                               "required" (mapcar (lambda (p)
                                                                    (%param-name->string (first p)))
                                                                  parameters))))))))))


(defun invoke-tool (fn-name args)
  "Look up tool FN-NAME, call it with ARGS (hash-table), return result string."
  (handler-case
      (let ((fn-tool (gethash fn-name *tools*)))
        (unless fn-tool
          (return-from invoke-tool (format nil "Error: Unknown tool: ~A" fn-name)))
        (let ((fn (tool-fn fn-tool)))
          (unless fn
            (return-from invoke-tool (format nil "Error: Tool ~A has no function" fn-name)))
          (apply fn (map-args-to-parameters fn-tool args))))
    (error (e)
      (format nil "Error: ~A" e))))


(defun list-available-tools ()
  "Return a list of all registered tool name strings."
  (loop for tool-name being the hash-keys of *tools*
        collect tool-name))


(defun get-tool-info (tool-name)
  "Return a plist with :name, :description, :parameters for the named tool, or NIL."
  (let ((tool (gethash (if (symbolp tool-name)
                           (symbol-name tool-name)
                           tool-name)
                       *tools*)))
    (when tool
      (list :name (tool-name tool)
            :description (tool-description tool)
            :parameters (tool-parameters tool)))))


(defmacro defun-tool (name args description &rest body)
  "Define a tool function that can be called by LLM completions.

NAME       — symbol or string naming the tool.
ARGS       — list of (name type description) triples.
DESCRIPTION — string describing the tool for the LLM.
BODY       — forms implementing the tool."
  (let ((name-str (if (symbolp name) (symbol-name name) name))
        (arg-names (mapcar (lambda (arg) (intern (string-upcase (first arg)))) args)))
    `(progn
       (setf (gethash ,name-str *tools*)
             (make-instance 'function-tool
                            :name ,name-str
                            :description ,description
                            :parameters ',args
                            :fn (lambda ,arg-names ,@body)))
       ',name)))
