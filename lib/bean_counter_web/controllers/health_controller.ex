defmodule BeanCounterWeb.HealthController do
  use BeanCounterWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
