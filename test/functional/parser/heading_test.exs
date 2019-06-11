defmodule Parser.HeadingTest do
  use Support.ParserTestCase

  test "Heading at the start is interpreted correctly" do
    result = parse_markdown(["Heading", "=====", ""])
    assert result == [%Block.Heading{content: "Heading", level: 1, lnb: 1}]
  end

  test "Heading at the end is interpreted correctly" do
    result = parse_markdown(["", "Heading", "====="])
    assert result == [%Block.Heading{content: "Heading", level: 1, lnb: 2}]
  end

end

# SPDX-License-Identifier: Apache-2.0
