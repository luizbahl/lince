defmodule IngestorWeb.Router do
  use IngestorWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", IngestorWeb do
    pipe_through :api

    get "/health", HealthController, :show
    get "/changes", ChangeController, :index
  end
end
