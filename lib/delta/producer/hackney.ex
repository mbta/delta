defmodule Delta.Producer.Hackney do
  @moduledoc """
  Implementation of HTTP behavior using the Hackney HTTP library.
  """
  @behaviour Delta.Producer.HTTP
  @default_headers [
    {"accept-encoding", ["gzip"]}
  ]
  defstruct [
    :url,
    headers: @default_headers
  ]

  @impl Delta.Producer.HTTP
  def new(url, opts \\ []) do
    headers = Keyword.get(opts, :headers, []) ++ @default_headers
    {:ok, %__MODULE__{url: url, headers: headers}}
  end

  @impl Delta.Producer.HTTP
  def fetch(conn) do
    case Req.get(conn.url, headers: conn.headers, retry: false) do
      {:ok, %Req.Response{status: 200, headers: headers, body: body}} ->
        maybe_file(conn, headers, body)

      {:ok, %Req.Response{status: 304, headers: headers}} ->
        conn = update_cache_headers(conn, headers)
        {:unmodified, conn}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, conn, {:invalid_status, status, body}}

      {:error, exception} ->
        {:error, conn, inspect(exception)}
    end
  end

  @impl Delta.Producer.HTTP
  def stream(conn, {:ssl_closed, _}) do
    {:ok, conn, []}
  end

  def stream(_conn, _other) do
    :unknown
  end

  defp maybe_file(conn, headers, body) do
    new_conn = update_cache_headers(conn, headers)

    if modified_cache_headers?(new_conn.headers, conn.headers) do
      {:ok, new_conn, build_file(new_conn, headers, body)}
    else
      {:unmodified, new_conn}
    end
  end

  defp modified_cache_headers?(new_headers, old_headers) do
    # Last-Modified time (accurate to the second) good enoough.
    List.keyfind(new_headers, "if-none-match", 0, :new) !=
      List.keyfind(old_headers, "if-none-match", 0, :old)
  end

  defp build_file(state, headers, body) do
    encoding =
      case find_header(headers, "content-encoding") do
        "gzip" -> :gzip
        nil -> :none
      end

    content_type = find_header(headers, "content-type")

    updated_at = parse_datetime(best_datetime(headers))

    %Delta.File{
      updated_at: updated_at,
      url: state.url,
      body: body,
      content_type: content_type,
      encoding: encoding
    }
  end

  defp find_header(headers, header) do
    case Enum.find_value(headers, fn {key, value} ->
           String.downcase(key) == header and value
         end) do
      nil -> nil
      [value] -> value
    end
  end

  defp update_cache_headers(conn, headers) do
    Enum.reduce(headers, conn, &update_cache_header/2)
  end

  defp update_cache_header({header, value}, conn) do
    headers =
      case String.downcase(header) do
        "last-modified" ->
          store_header(conn.headers, "if-modified-since", value)

        "etag" ->
          store_header(conn.headers, "if-none-match", value)

        _ ->
          conn.headers
      end

    %{conn | headers: headers}
  end

  defp store_header(headers, key, value) do
    List.keystore(headers, key, 0, {key, value})
  end

  defp best_datetime(headers) do
    case Enum.reduce_while(headers, nil, &best_datetime_header/2) do
      [dt] -> dt
      _ -> DateTime.new!(~D[1970-01-01], ~T[00:00:00], "Etc/UTC")
    end
  end

  defp best_datetime_header({key, value}, acc) do
    # prefer last-modified if they have it, otherwise use date.
    case String.downcase(key) do
      "last-modified" ->
        {:halt, value}

      "date" ->
        {:cont, value}

      _ ->
        {:cont, acc}
    end
  end

  defp parse_datetime(bin) when is_binary(bin) do
    erl_dt = :cow_date.parse_date(bin)
    naive_dt = NaiveDateTime.from_erl!(erl_dt)
    DateTime.from_naive!(naive_dt, "Etc/UTC")
  end
end
