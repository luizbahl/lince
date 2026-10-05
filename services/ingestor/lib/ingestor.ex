defmodule Ingestor do
  @moduledoc false

  alias Ingestor.Pipeline.ImportCompanies
  alias Ingestor.Pipeline.ImportCompanies.Input

  def import_companies(%{
        zip_path: zip_path,
        reference_month: reference_month
      }) do
    ImportCompanies.call(%Input{
      zip_path: zip_path,
      reference_month: reference_month
    })
  end
end
