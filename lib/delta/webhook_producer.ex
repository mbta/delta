defmodule Delta.WebhookProducer do
  @moduledoc """
  GenStage which fulfills demand by receiving webhook POSTs.
  """
  alias Delta.File
  use GenStage
  require Logger

  @type opts :: [opt]
  @type opt ::
          {:authorization, binary}
          | {:filters, [Delta.Producer.filter()]}

  @start_link_opts [:name]

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, Keyword.take(opts, @start_link_opts))
  end

  @doc "Send a conn (received by the webhook endpoint) to the producer"
  def send_conn(server, conn) do
    GenStage.call(server, {:send_conn, conn})
  end

  defstruct [:authorization, :filters]

  @impl GenStage
  def init(opts) do
    authorization = Keyword.get(opts, :authorization)
    filters = Keyword.get(opts, :filters, Delta.Producer.default_filters())

    state = %__MODULE__{
      authorization: authorization,
      filters: filters
    }

    {:producer, state, dispatcher: GenStage.BroadcastDispatcher}
  end

  @impl GenStage
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  @impl GenStage
  def handle_call({:send_conn, conn}, _from, state) do
    authorization_headers = Plug.Conn.get_req_header(conn, "authorization")

    demand =
      with true <- authorized?(state.authorization, authorization_headers),
           {:ok, body, conn} <- read_body(conn, []) do
        conn
        |> process_file(body)
        |> Delta.Producer.apply_filters(state.filters)
      else
        _ -> []
      end

    {:reply, :ok, demand, state}
  end

  defp authorized?(nil, []) do
    true
  end

  defp authorized?(header, [header]) do
    true
  end

  defp authorized?(_, _) do
    false
  end

  defp read_body(conn, acc) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} ->
        {:ok, IO.iodata_to_binary([acc | body]), conn}

      {:more, body, conn} ->
        read_body(conn, [acc | body])

      {:error, _} = e ->
        e
    end
  end

  defp process_file(conn, body) do
    encoding =
      case Plug.Conn.get_req_header(conn, "encoding") do
        ["gzip"] -> :gzip
        [] -> :none
      end

    content_type =
      case Plug.Conn.get_req_header(conn, "content-type") do
        [content_type | _] -> content_type
        [] -> Application.get_env(:delta, :default_content_type)
      end

    [
      %File{
        url: "#{conn.scheme}://#{conn.host}#{conn.request_path}",
        updated_at: DateTime.utc_now(),
        body: body,
        encoding: encoding,
        content_type: content_type
      }
    ]
  end
end
