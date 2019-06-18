defmodule Earmark.Contexts.ParserContext.ListParser do

  alias Earmark.Block
  alias Earmark.Line
  alias Earmark.Options
  alias Earmark.Contexts.ListContext.ListInfo

  import Earmark.Contexts.ListContext.ListHelpers, only: [calculate_list_indent: 1, extract_start: 1]
  import Earmark.Contexts.StringContext,  only: [behead_indent: 2]
  import Earmark.Helpers.InlineCodeHelpers, only: [opens_inline_code: 1, still_inline_code: 2]
  import Earmark.Message, only: [add_message: 2]

  @moduledoc """
  Parse list items into a list
  """

  @doc """
  Parse all lines corresponding to the list
  """
  def parse_list(lines, result, options \\ %Options{})
  def parse_list([%Line.ListItem{}=item|_]=lines, result, options) do
    list_info = _make_list_info(item)
    {list_items, rest, options1} = _parse_list(lines, [], list_info, options)
    list = _make_list(list_info, list_items)
    {[list|result], rest, options1}
  end

  #
  # Recursive Descending Parsers (in hierarchical order, top first)
  # ===============================================================

  defp _parse_list(lines, items, list_info, options)
  # Check if still in list, if so create list_item, parse it and add to lists blocks
  defp _parse_list(
    [%{Line.ListItem{bullet_type: bullet_type, list_indent: item_indent} | lines],
      items,
      %ListInfo{bullet_type: bullet_type, list_indent: orig_indent} = list_info,
      options)
  # TODO: Remove this clause, it should be the postcondition of _parse_list_item
  when item_indent <= orig_indent do
    {item, rest, options} = _parse_list_item(lines, [], list_info, options)
    _parse_list(rest, [item | items], list_info, options)
  end
  # Else return list
  defp _parse_list(lines, items, _list_info, options) do
    {items, lines, options}
  end


  @not_pending {nil, 0}

  defp _parse_list_item(lines, blocks, %ListInfo{pending: @not_pending}=list_info, options) do
    _parse_np_item(lines, blocks, list_info, options)
  end
  defp _parse_list_item(lines, blocks, list_info, options) do
    _parse_pending_list(lines, blocks, list_info, options)
  end

  defp _parse_np_item(lines, blocks, list_info, options)
  defp _parse_np_item([%Line.Blank{lnb: lnb}|rest], blocks, list_info, options) do
    _parse_np_body(rest, _add_to_first_block(blocks, %Block.Blank{lnb: lnb}), list_info, options)
  end
  defp _parse_np_item([], blocks, _, options) do
    {blocks, [], options}
  end

  defp _parse_np_body(lines, blocks, list_info, options)
  defp _parse_np_body([], blocks, _, options) do
    {blocks, [], options}
  end
  # defp _parse_list_item(
  #   [%Line.ListItem{bullet_type: bullet_type, list_indent: li_indent}|rest],
  #   %ListInfo{bullet_type: bullet_type, list_indent: list_indent},
  #   options
  # ) when li_indent <= list_indent do
  #   _parse_list_item(rest, [item | blocks], list_info, options)
  # end
  # defp _parse_list_item([], blocks, _, options) do
  #   {blocks, [], options}
  # end

  defp _parse_pending_list(lines, blocks, list_info, options)
  defp _parse_pending_list(
    [%{line: line}=line_pair|rest],
    [%Block.ListItem{blocks: [%Block.Para{lines: lines} = para| para_rest]} = item | blocks],
    %ListInfo{pending: pending, list_indent: list_indent}=list_info,
    options)
  do
    line1  = behead_indent(line, list_indent)
    lines1 = [line1|lines]
    item1  = Map.put(item, :blocks, [%{para | lines: [line1 | lines]} | para_rest])
    _parse_list_item(rest,
      [item1 | blocks],
      %{list_info | pending: still_inline_code(line_pair, pending)},
      options)
  end
  defp _parse_pending_list([], blocks, %ListInfo{pending: {pending, lnb}}, options) do
    options1 = add_message(options, {:warning, lnb, "Closing unclosed backquotes #{pending} at end of input"})
    {blocks, [], options1}
  end

  #
  # Helpers in alphabetical order
  # =============================

  defp _add_to_first_block(blocks, item)
  defp _add_to_first_block([%{blocks: blocks}=first|rest], item) do
    [%{first | blocks: [item|blocks]}]
  end

  defp _make_list_info(%Line.ListItem{}=item) do
    %ListInfo{
      bullet_type: item.bullet_type,
      indent: item.initial_indent,
      list_indent: calculate_list_indent(item),
      pending: opens_inline_code(item),
    }
    # list = %Block.List{
    #   blocks: [list_item],
    #   bullet: item.bullet,
    #   bullet_type: item.bullet_type,
    #   lnb: item.lnb,
    #   start: extract_start(item),
    #   type: item.type,
    # }
  end

  defp _make_list_item(%Line.ListItem{}=item) do
    %Block.ListItem{
      blocks: [%Block.Para{lines: [item.content], loose: false, lnb: item.lnb}],
      bullet: item.bullet,
      bullet_type: item.bullet_type,
      lnb: item.lnb,
      type: item.type,
    }
  end
end
