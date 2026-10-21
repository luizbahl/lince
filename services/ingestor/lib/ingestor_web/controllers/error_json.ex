defmodule IngestorWeb.ErrorJSON do
  @moduledoc """
  Renders errors raised outside controllers (e.g. unknown route → 404) as JSON instead of
  Phoenix's default HTML page.
  """

  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
