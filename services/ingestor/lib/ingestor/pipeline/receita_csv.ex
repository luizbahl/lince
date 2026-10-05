# NimbleCSV.define/2 is a macro that *generates* the module at compile time,
# so this file has no `defmodule` of its own.
NimbleCSV.define(Ingestor.Pipeline.ReceitaCSV,
  separator: ";",
  escape: "\"",
  moduledoc: """
  CSV parser for Receita Federal open CNPJ files.

  Fields are wrapped in double quotes and separated by `;`. Files have **no header row**, so
  always pass `skip_headers: false`, otherwise the first record of each file is silently dropped.

  Parsing works on the raw ISO-8859-1 bytes (`;` and `"` are the same byte in both encodings);
  converting text fields to UTF-8 is the caller's job.
  """
)
