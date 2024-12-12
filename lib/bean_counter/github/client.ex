defmodule BeanCounter.GitHub.Client do
  @moduledoc """
  GitHub API client using Tentacat.
  """

  require Logger

  @token_cache_key :github_installation_token
  # Refresh 10 mins before expiry
  @token_ttl :timer.minutes(50)

  def client do
    case get_cached_token() do
      nil ->
        token = fetch_new_token()
        cache_token(token)
        Tentacat.Client.new(%{access_token: token})

      token ->
        Tentacat.Client.new(%{access_token: token})
    end
  end

  defp get_cached_token do
    case :persistent_term.get(@token_cache_key, nil) do
      {token, expiry} ->
        if DateTime.compare(expiry, DateTime.utc_now()) == :gt do
          token
        end

      _ ->
        nil
    end
  end

  defp cache_token(token) do
    expiry = DateTime.utc_now() |> DateTime.add(@token_ttl * 1000, :microsecond)
    :persistent_term.put(@token_cache_key, {token, expiry})
    token
  end

  defp fetch_new_token do
    jwt = generate_jwt()

    url = "https://api.github.com/app/installations/#{installation_id()}/access_tokens"

    headers = [
      {"Authorization", "Bearer #{jwt}"},
      {"Accept", "application/vnd.github.v3+json"}
    ]

    case HTTPoison.post(url, "", headers) do
      {:ok, %{status_code: 201, body: body}} ->
        Jason.decode!(body)["token"]

      error ->
        Logger.error("Failed to get installation token: #{inspect(error)}")
        raise "Failed to get GitHub installation token"
    end
  end

  defp generate_jwt do
    app_id = github_config(:app_id)

    claims = %{
      "iat" => DateTime.utc_now() |> DateTime.to_unix(),
      "exp" => DateTime.utc_now() |> DateTime.add(600, :second) |> DateTime.to_unix(),
      "iss" => app_id
    }

    signer = Joken.Signer.create("RS256", %{"pem" => github_config(:private_key)})
    {:ok, token, _claims} = Joken.generate_and_sign(%{}, claims, signer)
    token
  end

  defp installation_id do
    github_config(:installation_id)
  end

  defp github_config(key) do
    Application.get_env(:bean_counter, :github)[key] ||
      raise "Missing GitHub config: #{key}"
  end
end
