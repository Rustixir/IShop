defmodule ShopbuilderApi do
  @moduledoc false
  require Logger

  defp api_endpoints do
    api_root = "/api/v1/"

    %{
      "product" => api_root <> "product",
      "product_upsert" => api_root <> "product/upsert",
      "product_bulk" => api_root <> "product/bulk",
      "product_uuid" => api_root <> "product/uuid/!0",
      "collection" => api_root <> "collection",
      "collection_upsert" => api_root <> "collection/upsert",
      "collection_uuid" => api_root <> "collection/uuid/!0",
      "option" => api_root <> "option",
      "option_id" => api_root <> "option/!0",
      "order" => api_root <> "order/uuid/!0",
      "customer_profile" => api_root <> "customer-profile",
      "customer_profile_uuid" => api_root <> "customer-profile/uuid/!0",
      "payment_options" => api_root <> "order-payment-methods/uuid/!0",
      "shipping_options" => api_root <> "order-shipping-methods/uuid/!0",
      "subscribe" => api_root <> "sb_webhooks/subscribe_webhook",
      "get_events" => api_root <> "sb_webhooks",
      "unsubscribe" => api_root <> "sb_webhooks/unsubscribe_webhook",
      "roles" => api_root <> "sb_roles",
      "restricted" => api_root <> "sb_api_config",
      "profile_mobile_number" => api_root <> "sb_api_config/profile_mobile_number",
      "countries" => api_root <> "fetch-countries",
      "product_redirections" => api_root <> "sb_api_config/product_redirections",
      "user" => api_root <> "sb_user",
      "user_edit" => api_root <> "sb_user/uuid/!0",
      "auto_login" => api_root <> "sb_user/autologin_link",
      "order_query" => api_root <> "order/query",
      "redirection_to_product" => api_root <> "sb_api_config/add_to_cart_redirect",
      "email" => api_root <> "sb_user/email/!0.json",
      "buy_link_enable" => api_root <> "sb_api_config/buy_link",
      "buy_link_generate" => api_root <> "sb_buy/!0/!1",
      "settings" => api_root <> "installed_apps/settings",
      "get_subscribed_emails" => api_root <> "sb_emails",
      "subscribe_email" => api_root <> "sb_emails/subscribe_email",
      "unsubscribe_email" => api_root <> "sb_emails/unsubscribe_email",
      "custom_shipping" => api_root <> "custom_shipping",
      "delete_custom_shipping" => api_root <> "custom_shipping/!0",
      "image" => api_root <> "sb-image",
      "image_fid" => api_root <> "sb-image/!0",
      "update_custom_shipping" => api_root <> "custom_shipping/!0"
    }
  end

  defp client(website, access_token) do
    OAuth2.Client.new(site: website, token: access_token)
  end

  def get(website_url, access_token, object, params \\ %{}, format \\ "") do
    url = modify_url(api_endpoints()[object] <> parse_params(params), params.uri_token)

    case OAuth2.Client.get(client(website_url, access_token), url, [], [{:recv_timeout, 10_000}]) do
      {:ok, %OAuth2.Response{status_code: 200, body: response}} ->
        {:ok, format_output(format, response)}

      {:error, %OAuth2.Response{status_code: code, body: body}} ->
        error_handler(code, body)

      {:error, %OAuth2.Error{reason: reason}} ->
        error_handler(500, reason)
    end
  end

  def put(website_url, access_token, object, body \\ "", params \\ %{}, format \\ "") do
    url = modify_url(api_endpoints()[object] <> parse_params(params), params.uri_token)

    case OAuth2.Client.put(
           client(website_url, access_token),
           url,
           body,
           ["Content-Type": "application/json"],
           [{:recv_timeout, 10_000}]
         ) do
      {:ok, %OAuth2.Response{status_code: 200, body: response}} ->
        {:ok, format_output(format, response)}

      {:error, %OAuth2.Response{status_code: code, body: body}} ->
        error_handler(code, body)

      {:error, %OAuth2.Error{reason: reason}} ->
        error_handler(500, reason)
    end
  end

  def post(website_url, access_token, object, body \\ "", params \\ %{}, format \\ "") do
    url = modify_url(api_endpoints()[object] <> parse_params(params), params.uri_token)

    case OAuth2.Client.post(
           client(website_url, access_token),
           url,
           body,
           ["Content-Type": "application/json"],
           [{:recv_timeout, 60_000}]
         ) do
      {:ok, %OAuth2.Response{status_code: 200, body: response}} ->
        {:ok, format_output(format, response)}

      {:error, %OAuth2.Response{status_code: code, body: body}} ->
        error_handler(code, body)

      {:error, %OAuth2.Error{reason: reason}} ->
        error_handler(500, reason)
    end
  end

  def delete(website_url, access_token, object, params \\ %{}, format \\ "") do
    url = modify_url(api_endpoints()[object] <> parse_params(params), params.uri_token)

    case OAuth2.Client.delete(client(website_url, access_token), url) do
      {:ok, %OAuth2.Response{status_code: 200, body: response}} ->
        {:ok, format_output(format, response)}

      {:error, %OAuth2.Response{status_code: code, body: body}} ->
        error_handler(code, body)

      {:error, %OAuth2.Error{reason: reason}} ->
        error_handler(500, reason)
    end
  end

  def error_handler(status_code, reason) do
    logger =
      case status_code do
        401 ->
          if(String.trim(reason["error"]) == "") do
            "ExSbapi: Unauthorized token"
          else
            "ExSbapi: #{inspect(reason)}"
          end

        404 ->
          if(String.trim(reason["error"]) == "") do
            "ExSbapi: No entities found"
          else
            "ExSbapi: #{inspect(reason)}"
          end

        _ ->
          "ExSbapi: #{inspect(reason)}"
      end

    case Logger.error(logger) do
      :ok ->
        {:error, logger}

      {:error, reason} ->
        {:error, "ExSbapi: Unable to Log the follwing error #{inspect(reason)}"}
    end
  end

  defp parse_params(params) do
    query_params =
      []
      |> parse_params_filter(params)
      |> parse_params_fields(params)

    if length(query_params) > 0 do
      query = query_params |> Enum.join("&")
      "?" <> query
    else
      ""
    end
  end

  defp parse_params_filter(query_params, params) do
    filter = params |> Map.get(:filter, %{})

    if map_size(filter) > 0 do
      filter
      |> Enum.reduce(query_params, fn {k, v}, acc -> query_params ++ ["parameters[#{k}]=#{v}"] end)
    else
      query_params
    end
  end

  defp parse_params_fields(query_params, params) do
    fields = params |> Map.get(:fields, nil)

    if fields != nil do
      query_params ++ ["fields=#{fields}"]
    else
      query_params
    end
  end

  defp modify_url(url, params) do
    # replace tokens in commands with parameters
    %{count: _, data: currated_command} =
      Enum.reduce(params, %{count: 0, data: url}, fn x, %{data: data, count: count} = acc ->
        # We return a map with the new count (to properly update the pattern) and the new data
        # the data is being replaced incrementally, each time with the new param
        %{count: count + 1, data: String.replace(data, "!#{count}", "#{x}")}
      end)

    currated_command
  end

  defp to_json(x) do
    case Poison.encode(x) do
      {:ok, body} ->
        body
    end
  end

  defp format_output(format, response) do
    case format do
      "json" ->
        to_json(response)

      _ ->
        response
    end
  end
end
