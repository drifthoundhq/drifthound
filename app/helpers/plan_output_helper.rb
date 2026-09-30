module PlanOutputHelper
  # Styling follows what `terraform plan` prints in a colour terminal
  # (hashicorp/terraform internal/command/format/format.go and
  # internal/command/jsonformat): only the action symbol is coloured, headers
  # bold the resource address, and hints such as "-> null" are dimmed.

  # Colour escape sequences, printed when a tool runs without -no-color
  # (terragrunt's automatic init, for one).
  ANSI_ESCAPE = /\e\[[0-9;]*[A-Za-z]/

  # The line that opens the list of proposed changes. Anything before it
  # (init and refresh logs, the symbol legend, notes about objects changed
  # outside of Terraform) is left as it is, even when it contains hyphens.
  PLAN_ACTIONS_START = /\A\s*(Terraform|OpenTofu) will perform the following actions:/

  # An action symbol at the start of a line, followed by whitespace or the
  # end of the line, so "---" or "-var=..." are left alone.
  PLAN_SYMBOL = %r{\A(\s*)(-/\+|\+/-|<=|[+\-~])(?=\s|\z)(.*)\z}

  PLAN_SYMBOL_CLASSES = {
    "+" => "plan-symbol-add",
    "-" => "plan-symbol-destroy",
    "~" => "plan-symbol-change",
    "<=" => "plan-symbol-read"
  }.freeze

  # "# aws_instance.web will be created", "# aws_instance.web must be replaced".
  # The address starts right after "# ", so "# (because ...)" does not match.
  PLAN_RESOURCE_HEADER = /\A(\s*)(# [^\s(]\S*)( (?:will|must|has|is) .*)\z/

  # Words Terraform prints in bold red inside a resource header.
  PLAN_HEADER_DANGER = /will not be destroyed|replaced|destroyed/

  # "# (18 unchanged attributes hidden)", "# (2 unchanged blocks hidden)".
  PLAN_HIDDEN_SUMMARY = /\A\s*# \(\d+ unchanged .+ hidden\)\s*\z/

  PLAN_SUMMARY = /\A(\s*)(Plan:)(.*)\z/

  PLAN_INLINE_TOKENS = {
    "# forces replacement" => "plan-forces-replacement",
    "-> null" => "plan-dim",
    # Plain in Terraform; viewers can choose to mute it.
    "(known after apply)" => "plan-noise"
  }.freeze
  PLAN_INLINE_TOKEN = Regexp.union(PLAN_INLINE_TOKENS.keys)

  # Marks up the actions section of a plan for the history view. Every piece
  # goes through content_tag or safe_join, so the output stays HTML-escaped.
  def colorize_plan_output(output)
    in_actions = false

    lines = output.to_s.gsub(ANSI_ESCAPE, "").split(/(?<=\n)/).map do |line|
      text = line.chomp
      newline = line.delete_prefix(text)
      marked_up = in_actions ? plan_line(text) : text
      in_actions ||= text.match?(PLAN_ACTIONS_START)

      safe_join([ marked_up, newline ])
    end

    safe_join(lines)
  end

  private

  def plan_line(text)
    if (match = text.match(PLAN_RESOURCE_HEADER))
      safe_join([ match[1], tag.span(match[2], class: "plan-address"), plan_header_rest(match[3]) ])
    elsif text.match?(PLAN_HIDDEN_SUMMARY)
      tag.span(text, class: "plan-dim")
    elsif (match = text.match(PLAN_SUMMARY))
      safe_join([ match[1], tag.span(match[2], class: "plan-summary"), match[3] ])
    elsif (match = text.match(PLAN_SYMBOL))
      safe_join([ match[1], plan_symbol(match[2]), plan_inline_tokens(match[3]) ])
    else
      plan_inline_tokens(text)
    end
  end

  # "-/+" and "+/-" colour each half, as Terraform does.
  def plan_symbol(symbol)
    return tag.span(symbol, class: PLAN_SYMBOL_CLASSES[symbol]) if PLAN_SYMBOL_CLASSES.key?(symbol)

    first, second = symbol.split("/")
    safe_join([ plan_symbol(first), "/", plan_symbol(second) ])
  end

  def plan_header_rest(text)
    parts = text.split(/(#{PLAN_HEADER_DANGER})/).map do |part|
      part.match?(/\A(#{PLAN_HEADER_DANGER})\z/) ? tag.span(part, class: "plan-danger") : part
    end

    safe_join(parts)
  end

  def plan_inline_tokens(text)
    parts = text.split(/(#{PLAN_INLINE_TOKEN})/).map do |part|
      css_class = PLAN_INLINE_TOKENS[part]
      css_class ? tag.span(part, class: css_class) : part
    end

    safe_join(parts)
  end
end
