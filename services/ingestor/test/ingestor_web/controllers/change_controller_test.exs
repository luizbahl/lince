defmodule IngestorWeb.ChangeControllerTest do
  use IngestorWeb.ConnCase, async: false

  alias Ingestor.ClickhouseRepo
  alias Ingestor.Schemas.Change

  setup {Ingestor.ClickhouseCase, :truncate_tables}

  setup do
    ClickhouseRepo.insert_all(Change, [
      %{
        dataset: "companies",
        reference_month: ~D[2026-08-01],
        cnpj_root: "00000000",
        change_type: "created"
      },
      %{
        dataset: "establishments",
        reference_month: ~D[2026-09-01],
        cnpj_root: "00000000",
        cnpj_order: "0001",
        cnpj_check_digits: "91",
        change_type: "updated",
        field: "registration_status_code",
        previous_value: "02",
        current_value: "08"
      }
    ])

    :ok
  end

  describe "GET /changes" do
    test "lists the changes of a CNPJ, newest month first", %{conn: conn} do
      assert %{"data" => [status, created]} =
               conn |> get("/changes", cnpj: "00.000.000/0001-91") |> json_response(200)

      assert %{
               "dataset" => "establishments",
               "reference_month" => "2026-09-01",
               "cnpj_root" => "00000000",
               "cnpj_order" => "0001",
               "cnpj_check_digits" => "91",
               "change_type" => "updated",
               "field" => "registration_status_code",
               "previous_value" => "02",
               "current_value" => "08"
             } = status

      assert %{"cnpj_order" => nil, "cnpj_check_digits" => nil, "field" => nil} = created
    end

    test "filters by since", %{conn: conn} do
      assert %{"data" => [%{"reference_month" => "2026-09-01"}]} =
               conn
               |> get("/changes", cnpj: "00000000", since: "2026-09-01")
               |> json_response(200)
    end

    test "answers 422 when the cnpj is missing", %{conn: conn} do
      assert conn |> get("/changes") |> json_response(422) ==
               %{"errors" => %{"cnpj" => ["can't be blank"]}}
    end

    test "answers 422 when since is not a date", %{conn: conn} do
      assert %{"errors" => %{"since" => ["is invalid"]}} =
               conn |> get("/changes", cnpj: "00000000", since: "yesterday") |> json_response(422)
    end
  end
end
