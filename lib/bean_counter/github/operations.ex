defmodule BeanCounter.GitHub.Operations do
  require Logger
  alias BeanCounter.GitHub.Client
  alias Tentacat.{Issues, References}

  def assign_issue(owner, repo, issue_number, assignee) do
    client = Client.client()

    case Issues.update(client, owner, repo, issue_number, %{assignees: [assignee]}) do
      {200, _, _} -> {:ok, assignee}
      error -> {:error, error}
    end
  end

  def create_branch(owner, repo, branch_name, base_sha) do
    client = Client.client()

    case References.create(client, owner, repo, %{
           "ref" => "refs/heads/#{branch_name}",
           "sha" => base_sha
         }) do
      {201, _, _} -> {:ok, branch_name}
      {422, %{"message" => "Reference already exists"}, _} -> {:ok, branch_name}
      error -> {:error, error}
    end
  end

  def get_default_branch(owner, repo) do
    client = Client.client()

    case Tentacat.Repositories.repo_get(client, owner, repo) do
      {200, repo_info, _} -> {:ok, repo_info["default_branch"]}
      error -> {:error, error}
    end
  end

  def get_ref_sha(owner, repo, ref) do
    client = Client.client()

    case Tentacat.References.find(client, owner, repo, "heads/#{ref}") do
      {200, %{"object" => %{"sha" => sha}}, _} -> {:ok, sha}
      error -> {:error, error}
    end
  end

  def move_project_item(item_id, field_id, status_name) do
    option_id = get_status_option_id(status_name)

    query = """
    mutation {
      updateProjectV2ItemFieldValue(
        input: {
          projectId: "#{project_id()}"
          itemId: "#{item_id}"
          fieldId: "#{field_id}"
          value: {
            singleSelectOptionId: "#{option_id}"
          }
        }
      ) {
        projectV2Item {
          id
        }
      }
    }
    """

    case graphql_request(query) do
      {:ok, _response} -> :ok
      error -> {:error, error}
    end
  end

  def set_start_date(item_id) do
    today = Date.utc_today() |> Date.to_iso8601()

    query = """
    mutation {
      updateProjectV2ItemFieldValue(
        input: {
          projectId: "#{project_id()}"
          itemId: "#{item_id}"
          fieldId: "#{github_config(:start_date_field_id)}"
          value: {
            date: "#{today}"
          }
        }
      ) {
        projectV2Item {
          id
        }
      }
    }
    """

    case graphql_request(query) do
      {:ok, _response} -> :ok
      error -> {:error, error}
    end
  end

  def set_end_date(item_id) do
    today = Date.utc_today() |> Date.to_iso8601()

    query = """
    mutation {
      updateProjectV2ItemFieldValue(
        input: {
          projectId: "#{project_id()}"
          itemId: "#{item_id}"
          fieldId: "#{github_config(:end_date_field_id)}"
          value: {
            date: "#{today}"
          }
        }
      ) {
        projectV2Item {
          id
        }
      }
    }
    """

    case graphql_request(query) do
      {:ok, _response} ->
        :ok

      error ->
        {:error, error}
    end
  end

  def get_issue(issue_number) do
    query = """
    query {
      repository(owner: "#{github_config(:org)}", name: "#{github_config(:repo)}") {
        issue(number: #{issue_number}) {
          title
          number
          repository {
            owner {
              login
            }
            name
          }
        }
      }
    }
    """

    case graphql_request(query) do
      {:ok, %{body: %{"data" => %{"repository" => %{"issue" => issue}}}}} -> {:ok, issue}
      error -> {:error, error}
    end
  end

  def get_issue_from_node(node_id) do
    query = """
    query {
      node(id: "#{node_id}") {
        ... on Issue {
          number
          title
          repository {
            owner {
              login
            }
            name
          }
        }
      }
    }
    """

    case graphql_request(query) do
      {:ok, %{body: %{"data" => %{"node" => issue}}}} -> {:ok, issue}
      error -> {:error, error}
    end
  end

  def get_linked_issues(owner, repo, pr_number) do
    query = """
    query {
      repository(owner: "#{owner}", name: "#{repo}") {
        pullRequest(number: #{pr_number}) {
          closingIssuesReferences(first: 10) {
            nodes {
              id
              number
              projectItems(first: 1) {
                nodes {
                  id
                }
              }
            }
          }
        }
      }
    }
    """

    case graphql_request(query) do
      {:ok,
       %{
         body: %{
           "data" => %{
             "repository" => %{
               "pullRequest" => %{"closingIssuesReferences" => %{"nodes" => issues}}
             }
           }
         }
       }}
      when is_list(issues) and length(issues) > 0 ->
        {:ok, issues}

      error ->
        {:error, error}
    end
  end

  defp project_id, do: github_config(:project_id)
  defp github_config(key), do: Application.get_env(:bean_counter, :github)[key]

  def slugify(str) do
    str
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/[\s-]+/, "-")
    |> String.trim("-")
  end

  defp graphql_request(query, variables \\ %{}) do
    client = Client.client()

    headers = [
      accept: "application/vnd.github.v4+json",
      authorization: "Bearer #{client.auth.access_token}"
    ]

    case Neuron.query(query, variables,
           headers: headers,
           url: Application.get_env(:neuron, :url)
         ) do
      {:ok, _response} = success ->
        success

      error ->
        error
    end
  end

  def get_status_option_id(status_name) do
    case status_name do
      "In review" -> github_config(:status_in_review)
      "In progress" -> github_config(:status_in_progress)
      _ -> raise "Unknown status: #{status_name}"
    end
  end
end
