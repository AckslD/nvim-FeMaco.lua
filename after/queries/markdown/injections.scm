;; extends

(fenced_code_block
  (info_string
    (language) @language)
  (#not-match? @language "elm")
  (block_continuation) @content
  .
  (fenced_code_block_delimiter))
