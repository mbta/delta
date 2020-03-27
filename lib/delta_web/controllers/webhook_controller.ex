defmodule DeltaWeb.WebhookController do
  use DeltaWeb, :controller
  require Logger

  def update(conn, %{"name" => producer_name}) do
    result =
      try do
        Delta.WebhookProducer.send_conn(
          Delta.PipelineSupervisor.producer_name(producer_name),
          conn
        )
      catch
        :exit, reason -> reason
      end

    case result do
      :ok ->
        send_resp(conn, 200, ~s({"result": "OK"}))

      error ->
        Logger.warn("#{__MODULE__} error processing request error=#{inspect(error)}")
        send_resp(conn, 500, ~s({"result": "ERROR"}))
    end
  end
end
