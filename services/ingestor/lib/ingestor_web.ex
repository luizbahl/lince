defmodule IngestorWeb do
  @moduledoc """
  The HTTP layer of the ingestor: a JSON-only API that translates requests into calls to the
  `Ingestor` facade.

  Used as `use IngestorWeb, :router` or `use IngestorWeb, :controller`.
  """

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:json]

      import Plug.Conn
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
