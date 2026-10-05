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

  @doc """
  Writes `lines` into a zip inside `dir` and returns the zip path.
  """
  def empresas_zip!(dir, lines) do
    zip_path = Path.join(dir, "Empresas1.zip")
    entry = {~c"K3241.K03200Y1.D60912.EMPRECSV", IO.iodata_to_binary(lines)}
    {:ok, _} = :zip.create(String.to_charlist(zip_path), [entry])
    zip_path
  end
end
