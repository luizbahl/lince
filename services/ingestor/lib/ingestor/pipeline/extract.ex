defmodule Ingestor.Pipeline.Extract do
  @moduledoc """
  Unzips a Receita Federal archive to disk.

  Files are extracted to disk instead of memory because a single uncompressed `Empresas` file can
  be several GB.
  """

  @spec extract(Path.t(), Path.t()) :: {:ok, [Path.t()]} | {:error, term()}
  def extract(zip_path, dest_dir) do
    # Erlang's :zip works with charlists, not Elixir strings.
    case :zip.extract(String.to_charlist(zip_path), cwd: String.to_charlist(dest_dir)) do
      {:ok, files} -> {:ok, Enum.map(files, &List.to_string/1)}
      {:error, reason} -> {:error, reason}
    end
  end
end
