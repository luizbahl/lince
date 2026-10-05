defmodule Ingestor.Pipeline.ExtractTest do
  use ExUnit.Case, async: true

  import Ingestor.ReceitaFixtures

  alias Ingestor.Pipeline.Extract

  @moduletag :tmp_dir

  test "extracts the files of the zip and returns their paths", %{tmp_dir: tmp_dir} do
    line = company_line("00000000", "EMPRESA")
    zip_path = empresas_zip!(tmp_dir, [line])
    dest_dir = Path.join(tmp_dir, "out")
    File.mkdir_p!(dest_dir)

    assert {:ok, [csv_path]} = Extract.extract(zip_path, dest_dir)
    assert Path.basename(csv_path) == "K3241.K03200Y1.D60912.EMPRECSV"
    assert File.read!(csv_path) == line
  end

  test "returns an error when the zip does not exist", %{tmp_dir: tmp_dir} do
    assert {:error, _reason} = Extract.extract(Path.join(tmp_dir, "missing.zip"), tmp_dir)
  end
end
