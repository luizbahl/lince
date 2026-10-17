defmodule Ingestor.Receita.Companies do
  @moduledoc """
  Turns an extracted `Empresas` CSV file into a lazy stream of rows for the `companies` table.

  Nothing is read until the stream is consumed, so files of several GB are processed line by
  line with constant memory.
  """

  alias Ingestor.Receita.CSV
  alias Ingestor.Receita.Fields

  @spec stream(Path.t(), Date.t()) :: Enumerable.t(map())
  def stream(csv_path, %Date{} = reference_month) do
    csv_path
    |> File.stream!()
    |> CSV.parse_stream(skip_headers: false)
    |> Stream.map(&to_company(&1, reference_month))
  end

  @spec to_company([binary()], Date.t()) :: map()
  def to_company(
        [
          cnpj_root,
          legal_name,
          legal_nature_code,
          responsible_qualification_code,
          share_capital,
          size_code,
          federative_entity
        ],
        %Date{} = reference_month
      ) do
    %{
      reference_month: reference_month,
      cnpj_root: cnpj_root,
      legal_name: Fields.text(legal_name),
      legal_nature_code: legal_nature_code,
      responsible_qualification_code: responsible_qualification_code,
      share_capital: Fields.decimal(share_capital),
      size_code: size_code,
      federative_entity: Fields.text(federative_entity)
    }
  end
end
