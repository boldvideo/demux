defmodule Demux.Repo do
  use Ecto.Repo,
    otp_app: :demux,
    adapter: Ecto.Adapters.Postgres
end
