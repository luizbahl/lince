defmodule IngestorWeb.ConnCase do
  @moduledoc """
  Test case for HTTP tests. Requests are dispatched straight to `IngestorWeb.Endpoint` in
  memory (`Phoenix.ConnTest`), so no port is opened.

  Tests that also touch ClickHouse must use `async: false`, like `Ingestor.ClickhouseCase`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint IngestorWeb.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest
    end
  end

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
