defmodule Ingestor do
  @moduledoc """
  Facade of the ingestor domain: the only module other layers (web, jobs, `iex`) may call.

  Each function pattern-matches the atom keys it requires and builds the pipeline's `Input`, so
  its contract is visible in the signature. The web layer converts request params (string keys)
  before calling it; a missing key is a caller bug and raises `FunctionClauseError`, while
  invalid values come back as `{:error, :invalid_input, changeset}` from the pipeline.
  """

  alias Ingestor.Pipeline.DetectChanges
  alias Ingestor.Pipeline.ImportMonth

  def import_companies(%{
        data_dir: data_dir,
        reference_month: reference_month
      }) do
    ImportMonth.call(%ImportMonth.Input{
      dataset: :companies,
      data_dir: data_dir,
      reference_month: reference_month
    })
  end

  def import_establishments(%{
        data_dir: data_dir,
        reference_month: reference_month
      }) do
    ImportMonth.call(%ImportMonth.Input{
      dataset: :establishments,
      data_dir: data_dir,
      reference_month: reference_month
    })
  end

  def detect_company_changes(%{reference_month: reference_month}) do
    DetectChanges.call(%DetectChanges.Input{
      dataset: :companies,
      reference_month: reference_month
    })
  end
end
