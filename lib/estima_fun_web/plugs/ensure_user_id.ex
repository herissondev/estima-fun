defmodule EstimaFunWeb.Plugs.EnsureUserId do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :user_id) do
      conn
    else
      user_id = generate_user_id()
      put_session(conn, :user_id, user_id)
    end
  end

  defp generate_user_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end
end
