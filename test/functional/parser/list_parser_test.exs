defmodule Functional.Parser.ListParserTest do
  use Support.ParserTestCase

  # TODO: Remove next example group
  describe "incremental development" do
    test "debugging" do
      markdown = """
      - a `line1
            line2`
      """
      [%List{blocks: [%ListItem{blocks: paras, bullet_type: "-", loose: false}, %Blank{lnb: 3}]}] = parse_list(markdown)
      [%Para{lines: lines, lnb: 1}] = paras
      assert lines == ["a `line1", "   line2"]
      
    end
  end

  describe "GFM spec compliance" do
    test "parse_list: GFM spec #281" do
      markdown = """
      - foo
      - bar
      + baz
      """
      %Block.List{} = parse_list(markdown)
    end
  end
  
end
