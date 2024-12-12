defmodule BeanCounterWeb.WebhookController do
  use BeanCounterWeb, :controller

  require Logger

  alias BeanCounter.GitHub.Operations

  action_fallback BeanCounterWeb.FallbackController

  def create(conn, params) do
    # Get the GitHub event type from headers
    event_type = get_req_header(conn, "x-github-event") |> List.first()

    # Log the webhook for debugging
    log_event(conn, params)

    # Start an async task to handle the event
    Task.start(fn -> process_event(event_type, params) end)

    # Return immediate success response
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

      Logger.info("Successfully processed issue #{issue_number} move to In Progress")
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
         } = params
       ) do
    Operations.set_end_date(item_id)
    Logger.info("Set end date for item #{item_id}")
  end

  # PR review requested
  defp process_event("pull_request", %{"action" => "review_requested"} = params) do
    Logger.debug("Review requested event received: #{inspect(params)}")

    %{
      "pull_request" => pr,
      "repository" => %{"owner" => %{"login" => owner}, "name" => repo}
    } = params

    Logger.debug(
      "PR details - number: #{pr["number"]}, draft: #{pr["draft"]}, owner: #{owner}, repo: #{repo}"
    )

    Logger.debug("Status field ID: #{github_config(:status_field_id)}")
    Logger.debug("Project ID: #{github_config(:project_id)}")

    if pr["draft"] == false do
      Logger.debug("PR is not draft, getting linked issues for PR #{pr["number"]}")

      case Operations.get_linked_issues(owner, repo, pr["number"]) do
        {:ok, []} ->
          Logger.debug("No linked issues found for PR #{pr["number"]}")

        {:ok, issues} ->
          Logger.debug("Found linked issues: #{inspect(issues)}")

          Enum.each(issues, fn issue ->
            Logger.debug("Processing issue: #{inspect(issue)}")
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
    else
      Logger.debug("PR is draft, skipping")
    end
  end

  # PR review submitted with changes requested
  defp process_event("pull_request_review", %{"action" => "submitted"} = params) do
    Logger.debug("Review submitted event received: #{inspect(params)}")

    %{
      "review" => %{"state" => state},
      "pull_request" => pr,
      "repository" => %{"owner" => %{"login" => owner}, "name" => repo}
    } = params

    # Only move to In progress if changes are requested
    if state == "changes_requested" do
      Logger.debug("Changes requested, moving linked issues to In progress")

      with {:ok, issues} <- Operations.get_linked_issues(owner, repo, pr["number"]) do
        Logger.debug("Found linked issues: #{inspect(issues)}")

        Enum.each(issues, fn issue ->
          [project_item] = issue["projectItems"]["nodes"]
          Logger.debug("Moving project item #{project_item["id"]} to In progress")

          Operations.move_project_item(
            project_item["id"],
            github_config(:status_field_id),
            "In progress"
          )
        end)
      else
        error -> Logger.error("Failed to get linked issues: #{inspect(error)}")
      end
    else
      Logger.debug("Review state: #{state}, not moving issues")
    end
  end

  defp process_event(event_type, params) do
    Logger.info("Unhandled event: #{event_type}, action: #{params["action"]}")
  end

  defp github_config(key), do: Application.get_env(:bean_counter, :github)[key]

  defp log_event(conn, params) do
    # Log headers (GitHub sends important info in headers)
    headers = conn.req_headers |> Enum.into(%{})

    # Combine headers and payload
    payload = %{
      headers: headers,
      body: params
    }

    # Create filename with timestamp
    filename = "webhook_#{DateTime.utc_now() |> DateTime.to_unix()}.json"
    path = Path.join(["webhook_logs", filename])

    # Ensure directory exists
    File.mkdir_p!("webhook_logs")

    # Write payload to file
    File.write!(path, Jason.encode!(payload, pretty: true))

    Logger.info("Webhook received and logged to #{path}")
  end
end
