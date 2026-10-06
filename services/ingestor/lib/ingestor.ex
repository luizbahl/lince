defmodule Ingestor do
  @moduledoc """
  Facade of the ingestor domain: the only module other layers (web, jobs, `iex`) may call.

  Each function pattern-matches the atom keys it requires and builds the pipeline's `Input`, so
  its contract is visible in the signature. The web layer converts request params (string keys)
  before calling it; a missing key is a caller bug and raises `FunctionClauseError`, while
  invalid values come back as `{:error, :invalid_input, changeset}` from the pipeline.
  """

  alias Ingestor.Pipeline.ImportCompanies

  def import_companies(%{
        zip_path: zip_path,
        reference_month: reference_month
      }) do
    ImportCompanies.call(%ImportCompanies.Input{
      zip_path: zip_path,
      reference_month: reference_month
    })
  end
end
