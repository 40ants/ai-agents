(uiop:define-package #:40ants-ai-agents/utils
  (:use #:cl)
  (:export #:json-encode
           #:json-parse))
(in-package #:40ants-ai-agents/utils)


(defun json-encode (object)
  "Serialize OBJECT to a JSON string.

Round-trip safe: hash-tables become JSON objects, vectors become JSON arrays,
:NULL becomes null, YASON:TRUE/YASON:FALSE become true/false.

Use JSON-PARSE with the same settings to get back the original structure."
  (yason:with-output-to-string* ()
    (yason:encode object nil)))


(defun json-parse (string)
  "Parse STRING as JSON into hash-tables with string keys.

Round-trip safe: JSON objects → hash-tables, arrays → vectors,
null → :NULL, true/false → YASON:TRUE/YASON:FALSE.

Use JSON-ENCODE to serialize back to an equivalent JSON string."
  (yason:parse string
               :json-arrays-as-vectors t
               :json-booleans-as-symbols t
               :json-nulls-as-keyword t))
