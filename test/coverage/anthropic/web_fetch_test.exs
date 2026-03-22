defmodule ReqLLM.Coverage.Anthropic.WebFetchTest do
  use ExUnit.Case, async: false

  import ReqLLM.Test.Helpers

  @moduletag :coverage
  @moduletag provider: "anthropic"
  @moduletag timeout: 180_000

  @model_spec "anthropic:claude-sonnet-4-5"

  setup_all do
    LLMDB.load(allow: :all, custom: %{})
    :ok
  end

  @tag scenario: :web_fetch_basic
  @tag model: "claude-sonnet-4-5"
  test "web fetch retrieves and analyzes URL content" do
    opts =
      fixture_opts("web_fetch_basic",
        provider_options: [
          web_fetch: %{max_uses: 2}
        ]
      )

    {:ok, response} =
      ReqLLM.generate_text(
        @model_spec,
        "Fetch https://example.com and summarize what the page contains.",
        opts
      )

    text = ReqLLM.Response.text(response)
    assert is_binary(text) and text != ""
  end
end
