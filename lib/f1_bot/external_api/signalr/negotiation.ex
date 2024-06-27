defmodule F1Bot.ExternalApi.SignalR.Negotiation do
  @moduledoc """
  HTTP client for SignalR connection negotiation.

  Useful documentation for SignalR 1.2:
  https://blog.3d-logic.com/2015/03/29/signalr-on-the-wire-an-informal-description-of-the-signalr-protocol/
  """
  @finch_instance F1Bot.Finch

  require Logger

  def negotiate(opts) do
    connection_data =
      opts
      |> Keyword.fetch!(:conn_data)
      |> Jason.encode!()

    query =
      %{
        clientProtocol: "1.2",
        connectionData: connection_data
      }
      |> URI.encode_query()

    base_path = Keyword.fetch!(opts, :base_path)

    url =
      %URI{
        scheme: Keyword.fetch!(opts, :scheme),
        host: Keyword.fetch!(opts, :hostname),
        port: Keyword.fetch!(opts, :port),
        path: "#{base_path}/negotiate",
        query: query
      }
      |> URI.to_string()

    Logger.info("Negotiating SignalR at '#{url}'")

    headers = [
      {"user-agent", Keyword.fetch!(opts, :user_agent)}
    ]

    Finch.build(:get, url, headers)
    |> Finch.request(@finch_instance, receive_timeout: 2000)
    |> parse_response()
  end

  defp parse_response({:ok, %{status: 200, body: body, headers: headers}}) do
    cookies =
      headers
      |> Enum.filter(fn {name, _v} -> name == "set-cookie" end)
      |> Enum.map(fn {_name, val} -> val end)
      |> Enum.map(fn val -> String.split(val, ";") end)
      |> Enum.map(fn [val | _] -> val end)
      |> Enum.map(fn val -> String.split(val, "=") end)
      |> Enum.map(fn [name, value] -> {name, value} end)
      |> Enum.into(%{})

    parsed = Jason.decode!(body)

    %{
      "TryWebSockets" => true,
      "ProtocolVersion" => "1.2"
    } = parsed

    response = %{
      data: parsed,
      cookies: cookies
    }

    {:ok, response}
  end
end
