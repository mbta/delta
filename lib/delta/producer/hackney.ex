defmodule Delta.Producer.Hackney do
  @moduledoc """
  Implementation of HTTP behavior using the Hackney HTTP library.
  """
  @behaviour Delta.Producer.HTTP

  defstruct [
    :url,
    headers: [
      {"accept-encoding", "gzip"}
    ]
  ]

  @hackney_opts [
    follow_redirects: true
  ]

  @impl Delta.Producer.HTTP
  def new(url) do
    {:ok, %__MODULE__{url: url}}
  end

  @impl Delta.Producer.HTTP
  def fetch(conn) do
    case :hackney.request(:get, conn.url, conn.headers, [], @hackney_opts) do
      {:ok, 200, headers, ref} ->
        conn = update_cache_headers(conn, headers)
        {:ok, body} = :hackney.body(ref)
        {:ok, conn, build_file(conn, headers, body)}

      {:ok, 304, headers, ref} ->
        _ = :hackney.body(ref)
        conn = update_cache_headers(conn, headers)
        {:unmodified, conn}

      {:ok, status, _headers, ref} ->
        body = :hackney.body(ref)
        {:error, conn, {:invalid_status, status, body}}

      {:error, reason} ->
        {:error, conn, reason}
    end
  end

  defp build_file(state, headers, body) do
    encoding =
      case Enum.find_value(headers, fn {key, value} ->
             String.downcase(key) == "content-encoding" and value
           end) do
        "gzip" -> :gzip
        nil -> :none
      end

    updated_at = parse_datetime(best_datetime(headers))

    %Delta.File{
      updated_at: updated_at,
      url: state.url,
      body: body,
      encoding: encoding
    }
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
    Enum.reduce_while(headers, nil, &best_datetime_header/2)
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
