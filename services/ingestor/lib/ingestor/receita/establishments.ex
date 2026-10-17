defmodule Ingestor.Receita.Establishments do
  @moduledoc """
  Turns an extracted `Estabelecimentos` CSV file into a lazy stream of rows for the
  `establishments` table.

  Each line has 30 fields, in the order of Receita Federal's data dictionary. A line with any
  other number of fields raises `FunctionClauseError`, because the file is corrupt; individual
  values that may be malformed (dates) become `nil` instead (see `Ingestor.Receita.Fields`).
  """

  alias Ingestor.Receita.CSV
  alias Ingestor.Receita.Fields

  @spec stream(Path.t(), Date.t()) :: Enumerable.t(map())
  def stream(csv_path, %Date{} = reference_month) do
    csv_path
    |> File.stream!()
    |> CSV.parse_stream(skip_headers: false)
    |> Stream.map(&to_establishment(&1, reference_month))
  end

  @spec to_establishment([binary()], Date.t()) :: map()
  def to_establishment(
        [
          cnpj_root,
          cnpj_order,
          cnpj_check_digits,
          branch_type_code,
          trade_name,
          registration_status_code,
          registration_status_date,
          registration_status_reason_code,
          foreign_city_name,
          country_code,
          activity_start_date,
          main_cnae_code,
          secondary_cnae_codes,
          street_type,
          street,
          street_number,
          address_complement,
          neighborhood,
          postal_code,
          state_code,
          municipality_code,
          phone_1_area_code,
          phone_1,
          phone_2_area_code,
          phone_2,
          fax_area_code,
          fax,
          email,
          special_status,
          special_status_date
        ],
        %Date{} = reference_month
      ) do
    %{
      reference_month: reference_month,
      cnpj_root: cnpj_root,
      cnpj_order: cnpj_order,
      cnpj_check_digits: cnpj_check_digits,
      branch_type_code: branch_type_code,
      trade_name: Fields.text(trade_name),
      registration_status_code: registration_status_code,
      registration_status_date: Fields.date(registration_status_date),
      registration_status_reason_code: registration_status_reason_code,
      foreign_city_name: Fields.text(foreign_city_name),
      country_code: country_code,
      activity_start_date: Fields.date(activity_start_date),
      main_cnae_code: main_cnae_code,
      secondary_cnae_codes: Fields.list(secondary_cnae_codes),
      street_type: Fields.text(street_type),
      street: Fields.text(street),
      street_number: Fields.text(street_number),
      address_complement: Fields.text(address_complement),
      neighborhood: Fields.text(neighborhood),
      postal_code: postal_code,
      state_code: state_code,
      municipality_code: municipality_code,
      phone_1_area_code: phone_1_area_code,
      phone_1: phone_1,
      phone_2_area_code: phone_2_area_code,
      phone_2: phone_2,
      fax_area_code: fax_area_code,
      fax: fax,
      email: Fields.text(email),
      special_status: Fields.text(special_status),
      special_status_date: Fields.date(special_status_date)
    }
  end
end
