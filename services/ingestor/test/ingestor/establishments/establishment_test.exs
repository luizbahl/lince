defmodule Ingestor.Establishments.EstablishmentTest do
  use Ingestor.ClickhouseCase, async: false

  test "round-trips dates before 1970, missing dates and secondary CNAE lists" do
    ClickhouseRepo.insert_all(Establishment, [
      %{
        reference_month: ~D[2026-09-01],
        cnpj_root: "00000000",
        cnpj_order: "0001",
        cnpj_check_digits: "91",
        registration_status_code: "02",
        registration_status_date: ~D[2005-11-03],
        activity_start_date: ~D[1966-08-01],
        special_status_date: nil,
        main_cnae_code: "6422100",
        secondary_cnae_codes: ["6499999", "6619399"]
      }
    ])

    assert [stored] = ClickhouseRepo.all(Establishment)
    assert stored.activity_start_date == ~D[1966-08-01]
    assert stored.registration_status_date == ~D[2005-11-03]
    assert stored.special_status_date == nil
    assert stored.secondary_cnae_codes == ["6499999", "6619399"]
  end
end
