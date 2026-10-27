defmodule IngestorWeb.ChangesetJSON do
  @moduledoc """
  Renders an invalid changeset as `{"errors": {"field": ["message", ...]}}`.
  """

  def error(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  defp translate_error({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, message ->
      String.replace(message, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
