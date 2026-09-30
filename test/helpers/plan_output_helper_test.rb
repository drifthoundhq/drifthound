require "test_helper"

class PlanOutputHelperTest < ActionView::TestCase
  ACTIONS = "Terraform will perform the following actions:\n".freeze

  PLAN = <<~PLAN
    aws_s3_bucket.logs: Refreshing state... [id=logs-bucket]

    Resource actions are indicated with the following symbols:
      + create
      - destroy

    Terraform will perform the following actions:

      # aws_instance.web will be created
      + resource "aws_instance" "web" {
          + ami = "ami-123"
        }

      # aws_s3_bucket.logs will be updated in-place
      ~ resource "aws_s3_bucket" "logs" {
          ~ acl = "private" -> "public-read"
          - tags = {} -> null
            # (4 unchanged attributes hidden)
        }

    Plan: 1 to add, 1 to change, 0 to destroy.
  PLAN

  def fragment(output)
    Nokogiri::HTML.fragment(colorize_plan_output(output))
  end

  def texts(output, selector)
    fragment(output).css(selector).map(&:text)
  end

  test "colours only the action symbol, not the rest of the line" do
    html = fragment(ACTIONS + "  + resource \"a\" \"b\" {\n      - tags = {}\n  ~ id = \"x\"\n")

    assert_equal [ "+" ], html.css("span.plan-symbol-add").map(&:text)
    assert_equal [ "-" ], html.css("span.plan-symbol-destroy").map(&:text)
    assert_equal [ "~" ], html.css("span.plan-symbol-change").map(&:text)
    assert_includes colorize_plan_output(ACTIONS + "  + resource \"a\" \"b\" {\n"), '<span class="plan-symbol-add">+</span> resource &quot;a&quot;'
  end

  test "colours each half of a replacement symbol" do
    html = colorize_plan_output(ACTIONS + "-/+ resource \"a\" \"b\" {\n+/- resource \"c\" \"d\" {\n")

    assert_includes html, '<span class="plan-symbol-destroy">-</span>/<span class="plan-symbol-add">+</span> resource'
    assert_includes html, '<span class="plan-symbol-add">+</span>/<span class="plan-symbol-destroy">-</span> resource'
  end

  test "colours data source reads" do
    assert_equal [ "<=" ], texts(ACTIONS + " <= data \"aws_ami\" \"base\" {\n", "span.plan-symbol-read")
  end

  test "bolds the resource address and flags destructive words in headers" do
    output = ACTIONS + <<~OUT
      # aws_instance.web will be created
      # aws_instance.db must be replaced
      # aws_iam_role.old will be destroyed
      # aws_s3_bucket.keep will no longer be managed by Terraform, but will not be destroyed
      # (because aws_iam_role.old is not in configuration)
    OUT

    assert_equal [ "# aws_instance.web", "# aws_instance.db", "# aws_iam_role.old", "# aws_s3_bucket.keep" ], texts(output, "span.plan-address")
    assert_equal [ "replaced", "destroyed", "will not be destroyed" ], texts(output, "span.plan-danger")
  end

  test "dims hidden attribute summaries and null values" do
    output = ACTIONS + "      - tags = {} -> null\n        # (18 unchanged attributes hidden)\n        # (1 unchanged block hidden)\n"

    assert_equal [ "-> null", "# (18 unchanged attributes hidden)", "# (1 unchanged block hidden)" ], texts(output, "span.plan-dim").map(&:strip)
  end

  test "highlights the attribute that forces a replacement" do
    output = ACTIONS + "      ~ ami = \"ami-1\" -> \"ami-2\" # forces replacement\n"

    assert_equal [ "# forces replacement" ], texts(output, "span.plan-forces-replacement")
  end

  test "marks unknown values so viewers can mute them" do
    output = ACTIONS + "      ~ id = \"i-123\" -> (known after apply)\n      + host_id = (known after apply)\n"

    assert_equal [ "(known after apply)" ] * 2, texts(output, "span.plan-noise")
  end

  test "bolds the plan summary label" do
    assert_equal [ "Plan:" ], texts(PLAN, "span.plan-summary")
  end

  test "leaves everything before the actions section untouched" do
    before_actions = PLAN.split("Terraform will perform").first

    assert_equal ERB::Util.html_escape(before_actions), colorize_plan_output(before_actions)
  end

  test "keeps the text and line breaks of the plan" do
    assert_equal PLAN, fragment(PLAN).text
  end

  test "matches the OpenTofu wording" do
    output = "OpenTofu will perform the following actions:\n  + resource \"a\" \"b\" {}\n"

    assert_equal [ "+" ], texts(output, "span.plan-symbol-add")
  end

  test "ignores hyphens that are not action symbols" do
    assert_empty fragment(ACTIONS + "---\n-var=foo\n  some-name\n").css("span")
  end

  test "escapes HTML in plan output" do
    html = colorize_plan_output(ACTIONS + "  + tag = \"<script>alert(1)</script>\"\n  # <img src=x onerror=alert(1)> will be created\n")

    assert_predicate html, :html_safe?
    assert_not_includes html, "<script>"
    assert_not_includes html, "<img"
    assert_includes html, "&lt;script&gt;alert(1)&lt;/script&gt;"
  end

  test "strips ANSI colour codes everywhere" do
    output = "\e[0m\e[1mInitializing the backend...\e[0m\n" + ACTIONS + "  \e[32m+\e[0m resource \"a\" \"b\" {}\n"
    html = colorize_plan_output(output)

    assert_not_includes html, "\e"
    assert_not_includes html, "[0m"
    assert_includes html, "Initializing the backend..."
    assert_equal [ "+" ], texts(output, "span.plan-symbol-add")
  end

  test "handles nil and Windows line endings" do
    assert_equal "", colorize_plan_output(nil)

    html = colorize_plan_output("Terraform will perform the following actions:\r\n  + a\r\n")
    assert_includes html, "<span class=\"plan-symbol-add\">+</span> a\r\n"
  end
end
