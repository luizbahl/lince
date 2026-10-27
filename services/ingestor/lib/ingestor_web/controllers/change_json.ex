defmodule IngestorWeb.ChangeJSON do
  @moduledoc """
  Response format of `IngestorWeb.ChangeController`.

  Columns stored as `""` when they do not apply (the establishment key of a company-level change,
  the field of a `created`/`removed` row) are rendered as `null`.
  """

  def index(%{changes: changes}) do
    %{data: Enum.map(changes, &data/1)}
  end

  defp data(change) do
    %{
      dataset: change.dataset,
      reference_month: change.reference_month,
      cnpj_root: change.cnpj_root,
      cnpj_order: blank_to_nil(change.cnpj_order),
      cnpj_check_digits: blank_to_nil(change.cnpj_check_digits),
      change_type: change.change_type,
      field: blank_to_nil(change.field),
      previous_value: change.previous_value,
      current_value: change.current_value,
      detected_at: change.detected_at
    }
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
