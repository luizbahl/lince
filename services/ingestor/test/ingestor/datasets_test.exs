defmodule Ingestor.DatasetsTest do
  use ExUnit.Case, async: true

  alias Ingestor.Datasets

  test "names/0 lists every importable dataset" do
    assert Datasets.names() == [:companies, :establishments]
  end

  test "with_change_detection/0 lists only datasets with compared fields" do
    assert Datasets.with_change_detection() == [:companies]
  end

  test "fetch!/1 raises for an unknown dataset" do
    assert_raise KeyError, fn -> Datasets.fetch!(:partners) end
  end
end
