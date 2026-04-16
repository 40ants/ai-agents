(uiop:define-package #:40ants-ai-agents/tool
  (:use #:cl)
  (:import-from #:serapeum
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
           #:render-tool))
(in-package #:40ants-ai-agents/tool)


(defclass function-tool ()
  ((description :initarg :description :reader tool-description)
   (name :initarg :name :reader tool-name)
   (parameters :initarg :parameters :reader tool-parameters)
   (fn :initarg :fn :reader tool-fn)))


(defvar *tools* (make-hash-table :test 'equalp)
  "Registry of all defined tools. Keys are tool name strings.")


(defun map-args-to-parameters (fn-tool args)
  "Map ARGS (an alist) to positional arguments in declared order."
  (loop for (param-name _param-type _param-desc) in (tool-parameters fn-tool)
        collect
        (let* ((key (intern (string-upcase param-name) :keyword))
               (found (or (assoc key args)
                          (assoc key args
                                 :test (lambda (a b)
                                         (and (stringp a)
                                              (stringp b)
                                              (string-equal a b)))))))
          (cdr found))))


(defun render-tool (tool)
  "Render TOOL as an OpenAI-style tool definition alist."
  (with-slots (description name parameters) tool
    `((:type . "function")
      (:function . ((:name . ,name)
                     (:description . ,description)
                     ,@(when parameters
                         `(:parameters .
                           ((:type . "object")
                            (:properties .
                             ,(loop for p in parameters
                                    collect (list (first p)
                                                  (cons :type (second p))
                                                  (cons :description (third p)))))
                            (:required .
                             ,(loop for p in parameters collect (first p)))))))))))


(defun invoke-tool (fn-name args)
  "Look up tool FN-NAME, call it with ARGS, return result string."
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
