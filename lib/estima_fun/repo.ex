defmodule EstimaFun.Repo do
  use Ecto.Repo,
    otp_app: :estima_fun,
    adapter: Ecto.Adapters.SQLite3
end
