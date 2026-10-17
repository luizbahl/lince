defmodule Ingestor.ReceitaFixtures do
  @moduledoc """
  Builds small Receita Federal files for tests, in the real format: quoted fields separated by
  `;`, ISO-8859-1 text, no header, zipped with a name that has no `.csv` extension.
  """

  @doc """
  An `Empresas` CSV line. `legal_name` is given as UTF-8 and written as ISO-8859-1, like the
  real files.
  """
  def company_line(cnpj_root, legal_name, share_capital \\ "0,00") do
    latin1_name = :unicode.characters_to_binary(legal_name, :utf8, :latin1)
    ~s("#{cnpj_root}";"#{latin1_name}";"2062";"49";"#{share_capital}";"01";""\n)
  end

  @establishment_defaults [
    cnpj_root: "00000000",
    cnpj_order: "0001",
    cnpj_check_digits: "91",
    branch_type_code: "1",
    trade_name: "",
    registration_status_code: "02",
    registration_status_date: "20051103",
    registration_status_reason_code: "00",
    foreign_city_name: "",
    country_code: "",
    activity_start_date: "19660801",
    main_cnae_code: "6422100",
    secondary_cnae_codes: "6499999,6619399",
    street_type: "SETOR",
    street: "BANCARIO SUL",
    street_number: "1",
    address_complement: "",
    neighborhood: "ASA SUL",
    postal_code: "70074900",
    state_code: "DF",
    municipality_code: "9701",
    phone_1_area_code: "61",
    phone_1: "34939002",
    phone_2_area_code: "",
    phone_2: "",
    fax_area_code: "",
    fax: "",
    email: "",
    special_status: "",
    special_status_date: ""
  ]

  @doc """
  An `Estabelecimentos` CSV line with its 30 fields in the source order. Any field can be
  overridden by its column name (`registration_status_code: "08"`); text is given as UTF-8 and
  written as ISO-8859-1.
  """
  def establishment_line(overrides \\ []) do
    fields =
      Enum.map(@establishment_defaults, fn {column, default} ->
        value = Keyword.get(overrides, column, default)
        ~s("#{:unicode.characters_to_binary(value, :utf8, :latin1)}")
      end)

    Enum.join(fields, ";") <> "\n"
  end

  @doc """
  Writes `Empresas` `lines` into a zip named `name` inside `dir` and returns the zip path.
  """
  def empresas_zip!(dir, lines, name \\ "Empresas1.zip") do
    zip!(dir, name, ~c"K3241.K03200Y1.D60912.EMPRECSV", lines)
  end

  @doc """
  Writes `Estabelecimentos` `lines` into a zip named `name` inside `dir` and returns the zip path.
  """
  def estabelecimentos_zip!(dir, lines, name \\ "Estabelecimentos1.zip") do
    zip!(dir, name, ~c"K3241.K03200Y1.D60912.ESTABELE", lines)
  end

  defp zip!(dir, name, entry_name, lines) do
    zip_path = Path.join(dir, name)
    {:ok, _} = :zip.create(String.to_charlist(zip_path), [{entry_name, IO.iodata_to_binary(lines)}])
    zip_path
  end
end
