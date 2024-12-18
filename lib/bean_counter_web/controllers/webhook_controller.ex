defmodule BeanCounterWeb.WebhookController do
  use BeanCounterWeb, :controller

  require Logger

  alias BeanCounter.GitHub.Operations

  action_fallback BeanCounterWeb.FallbackController

  plug :verify_signature when action in [:create]

  def create(conn, params) do
    event_type = get_req_header(conn, "x-github-event") |> List.first()
    Task.start(fn -> process_event(event_type, params) end)
    send_resp(conn, 200, "ok")
  end

  # Item moved to In Progress
  defp process_event(
         "projects_v2_item",
         %{
           "action" => "edited",
           "changes" => %{
             "field_value" => %{
               "field_name" => "Status",
               "to" => %{"name" => "In progress"},
               "from" => %{"name" => from_status}
             }
           },
           "projects_v2_item" => %{
             "node_id" => item_id,
             "content_type" => "Issue"
           }
         } = params
       ) do
    with {:ok, issue} <-
           Operations.get_issue_from_node(params["projects_v2_item"]["content_node_id"]),
         %{"number" => issue_number, "repository" => repo} <- issue do
      # Only assign and set start date if coming from Ready
      if from_status == "Ready" do
        Operations.assign_issue(
          repo["owner"]["login"],
          repo["name"],
          issue_number,
          params["sender"]["login"]
        )

        Operations.set_start_date(item_id)
      end
    else
      error -> Logger.error("Failed to process issue: #{inspect(error)}")
    end
  end

  # Item moved to Done
  defp process_event(
         "projects_v2_item",
         %{
           "action" => "edited",
           "changes" => %{
             "field_value" => %{
               "field_name" => "Status",
               "to" => %{"name" => "Done"}
             }
           },
           "projects_v2_item" => %{
             "node_id" => item_id,
             "content_type" => "Issue"
           }
         }
       ) do
    Operations.set_end_date(item_id)
  end

  # PR review requested
  defp process_event("pull_request", %{"action" => "review_requested"} = params) do
    %{
      "pull_request" => pr,
      "repository" => %{"owner" => %{"login" => owner}, "name" => repo}
    } = params

    if pr["draft"] == false do
      case Operations.get_linked_issues(owner, repo, pr["number"]) do
        {:ok, []} ->
          :ok

        {:ok, issues} ->
          Enum.each(issues, fn issue ->
            [project_item] = issue["projectItems"]["nodes"]

            Operations.move_project_item(
              project_item["id"],
              github_config(:status_field_id),
              "In review"
            )
          end)

        error ->
          Logger.error("Failed to get linked issues: #{inspect(error)}")
      end
    end
  end

  # PR review submitted with changes requested
  defp process_event("pull_request_review", %{"action" => "submitted"} = params) do
    %{
      "review" => %{"state" => state},
      "pull_request" => pr,
      "repository" => %{"owner" => %{"login" => owner}, "name" => repo}
    } = params

    # Only move to In progress if changes are requested
    if state == "changes_requested" do
      with {:ok, issues} <- Operations.get_linked_issues(owner, repo, pr["number"]) do
        Enum.each(issues, fn issue ->
          [project_item] = issue["projectItems"]["nodes"]

          Operations.move_project_item(
            project_item["id"],
            github_config(:status_field_id),
            "In progress"
          )
        end)
      else
        error -> Logger.error("Failed to get linked issues: #{inspect(error)}")
      end
    end
  end

  defp process_event(_event_type, _params), do: nil

  defp github_config(key), do: Application.get_env(:bean_counter, :github)[key]

  defp verify_signature(conn, _opts) do
    signature = get_req_header(conn, "x-hub-signature-256") |> List.first()
    secret = github_config(:webhook_secret)
    body = conn.assigns[:raw_body]

    computed =
      "sha256=" <> (:crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower))

    if Plug.Crypto.secure_compare(signature, computed) do
      assign(conn, :raw_body, body)
    else
      conn
      |> send_resp(401, "Invalid signature")
      |> halt()
    end
  end
end
