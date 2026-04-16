(uiop:define-package #:40ants-ai-agents/utils
  (:use #:cl)
  (:import-from #:serapeum
                #:->)
  (:export #:json-encode
           #:json-parse))
(in-package #:40ants-ai-agents/utils)


(defun json-encode (object)
  "Serialize OBJECT to a JSON string.

Round-trip safe: alists become JSON objects, vectors become JSON arrays,
:NULL becomes null, YASON:TRUE/YASON:FALSE become true/false.

Use JSON-PARSE with the same settings to get back the original structure."
  (let ((yason:*list-encoder* 'yason:encode-alist)
        (yason:*symbol-key-encoder* #'yason:encode-symbol-as-lowercase)
        (yason:*symbol-encoder* #'yason:encode-symbol-as-lowercase))
    (yason:with-output-to-string* ()
      (yason:encode object nil))))


(defun json-parse (string)
  "Parse STRING as JSON into alist structure.

Round-trip safe: JSON objects → alists, arrays → vectors,
null → :NULL, true/false → YASON:TRUE/YASON:FALSE.

Use JSON-ENCODE to serialize back to an equivalent JSON string."
  (let ((yason:*parse-object-key-fn*
          (lambda (key) (intern (string-upcase key) :keyword))))
    (yason:parse string
                 :object-as :alist
                 :json-arrays-as-vectors t
                 :json-booleans-as-symbols t
                 :json-nulls-as-keyword t)))
