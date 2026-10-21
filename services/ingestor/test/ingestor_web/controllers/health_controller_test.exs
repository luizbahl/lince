defmodule IngestorWeb.HealthControllerTest do
  use IngestorWeb.ConnCase, async: true

  test "GET /health answers ok", %{conn: conn} do
    assert conn |> get("/health") |> json_response(200) == %{"status" => "ok"}
  end

  test "an unknown route answers 404 as JSON", %{conn: conn} do
    assert conn |> get("/nope") |> json_response(404) ==
             %{"errors" => %{"detail" => "Not Found"}}
  end
end
