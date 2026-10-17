defmodule Ingestor.Receita.Fields do
  @moduledoc """
  Converts raw Receita Federal CSV fields (ISO-8859-1 bytes) into Elixir values.

  Fields that may legitimately be missing or malformed in the source (dates) become `nil` instead
  of raising, so one bad value does not fail the import of a whole month.
  """

  @doc """
  Converts ISO-8859-1 text to UTF-8. Every byte is a valid ISO-8859-1 character, so this cannot
  fail.
  """
  @spec text(binary()) :: String.t()
  def text(raw), do: :unicode.characters_to_binary(raw, :latin1)

  @doc """
  Parses a decimal written with a comma as the decimal separator (`"1500,75"`).
  """
  @spec decimal(binary()) :: Decimal.t()
  def decimal(raw), do: raw |> String.replace(",", ".") |> Decimal.new()

  @doc """
  Parses a `YYYYMMDD` date. Returns `nil` for missing dates (`""`, `"0"`, `"00000000"`), invalid
  dates and years before 1900, which ClickHouse's `Date32` cannot store.
  """
  @spec date(binary()) :: Date.t() | nil
  def date(<<year::binary-4, month::binary-2, day::binary-2>>) do
    case Date.from_iso8601("#{year}-#{month}-#{day}") do
      {:ok, %Date{year: year} = date} when year >= 1900 -> date
      _ -> nil
    end
  end

  def date(_raw), do: nil

  @doc """
  Splits a comma-separated list (`"4751201,4789099"`); an empty field is an empty list.
  """
  @spec list(binary()) :: [String.t()]
  def list(raw), do: String.split(raw, ",", trim: true)
end
