defmodule IngestorWeb.FallbackControllerTest do
  use IngestorWeb.ConnCase, async: true

  import ExUnit.CaptureLog

  alias IngestorWeb.FallbackController

  test "an internal error answers 500 and logs the detail instead of sending it", %{conn: conn} do
    error = {:error, :fetch_failed, %RuntimeError{message: "clickhouse is down"}}

    log =
      capture_log(fn ->
        conn = conn |> Phoenix.Controller.put_format("json") |> FallbackController.call(error)

        assert json_response(conn, 500) == %{"errors" => %{"detail" => "Internal Server Error"}}
      end)

    assert log =~ "clickhouse is down"
  end
end
