defmodule Earmark.Contexts.ListContext.ListLookahead do

  use Earmark.Types

  # TODO: Remove me
  alias Dev.Debugging

  alias Earmark.Contexts.ListContext.ListInfo
  alias Earmark.Line
  # alias Dev.Debugging, as: D
  import Earmark.Helpers.InlineCodeHelpers
  import Earmark.Contexts.ListContext.ListHelpers
  import Earmark.Contexts.StringContext, only: [behead: 2, behead_indent: 2]


  @moduledoc """
  Read all lines that are contained in a list item and return them with the information
  if the list item is loose and if it has trailing blank items.
  """

  @doc """
  Called to slurp in the lines for a list item.
  basically, we allow indents and blank lines, and
  we allow text lines only after an indent (and initially)
  We also slurp in lines that are inside a multiline inline
  code block as indicated by `pending`.
  """
  def read_list_lines([%{list_indent: indent}=first|lines]) do
    pending = opens_inline_code(first)
    list_indent = calculate_list_indent(first)
    {bullet, _type, _start} = determine_list_type(first)
    # IO.puts ">>> read_list_lines"
    # lines
    # |> D.duplicate
    # |> D.inspect_only([:line])
    _dbg_read_list_lines(
      lines,
      [behead(first.line, indent)],
      %ListInfo{
        bullet_type: String.slice(bullet, -1..-1),
        indent: indent,
        list_indent: list_indent,
        pending: pending})
    # IO.puts "<<< read_list_line"
    # IO.inspect(y)
  end


  @not_pending {nil, 0}

  defp _read_list_lines(lines, result, list_info)
  defp _read_list_lines([%Line.Blank{} | rest], result, %ListInfo{pending: @not_pending} = list_info ) do
    _dbg_read_list_lines(rest, [""|result], %{list_info | trailing_blanks?: true})
  end
  defp _read_list_lines([%Line.Blank{} | rest], result, %ListInfo{} = list_info ) do
    _dbg_read_list_lines(rest, [""|result], %{list_info | trailing_blanks?: false})
  end
  # Loose if blank line before list item of the same list
  defp _read_list_lines(
         [ %Line.ListItem{bullet_type: new_bullet, initial_indent: new_indent} | _]=lines,
         result,
         %ListInfo{bullet_type: old_bullet, list_indent: list_indent, pending: @not_pending, trailing_blanks?: true}
       )
       when new_bullet == old_bullet and new_indent < list_indent do
         {true, true, Enum.reverse(result), lines}
       end
  # Thight if no blank line
  defp _read_list_lines(
         [ %Line.ListItem{bullet_type: new_bullet, initial_indent: new_indent} | _]=lines,
         result,
         %ListInfo{bullet_type: old_bullet, list_indent: list_indent, pending: @not_pending, trailing_blanks?: false}
       )
       when new_bullet == old_bullet and new_indent < list_indent do
         {true, true, Enum.reverse(result), lines}
       end
  defp _read_list_lines(
         [ %Line.ListItem{bullet_type: new_bullet, line: line} | rest],
         result,
         params = %ListInfo{bullet_type: old_bullet, list_indent: list_indent, pending: @not_pending}
       )
       when new_bullet == old_bullet do
         # IO.inspect [ :l02, line: line, indent: indent, new_indent: new_indent ]
         _dbg_read_list_lines(rest, [behead_indent(line, list_indent) | result], _opens_inline_code(line, params))
       end
  defp _read_list_lines(
         [ %Line.ListItem{line: line, initial_indent: new_indent} | rest],
         result,
         params = %{list_indent: list_indent, pending: @not_pending, loose?: false, trailing_blanks?: false})
       when new_indent >= list_indent  do
         _dbg_read_list_lines(rest, [behead_indent(line, list_indent)| result], _opens_inline_code(line, params))
       end
  defp _read_list_lines(
         [ %Line.ListItem{} | _] = rest,
         result,
         %{pending: @not_pending,trailing_blanks?: trailing_blanks, loose?: loose})
       do
         # IO.inspect [:l03]
         {loose || trailing_blanks, trailing_blanks, Enum.reverse(result), rest}
  end
  defp _read_list_lines(
         [ %Line.Ruler{} | _] = rest,
         result,
         %ListInfo{loose?: loose, trailing_blanks?: trailing_blanks}
       ) do
         # IO.inspect [:l05]
         {loose, trailing_blanks, Enum.reverse(result), rest}
  end
  # As long as we are not behind a blank line
  defp _read_list_lines(
        [ %{line: line} | rest ],
        result,
        params = %{pending: @not_pending, list_indent: list_indent, trailing_blanks?: false}) do
         # IO.inspect [:l04, params, line: line]
    _dbg_read_list_lines(rest, [behead_indent(line, list_indent) | result], _opens_inline_code(line, params))
  end
  # Behind a blank line, indent is important
  defp _read_list_lines([%{line: line, initial_indent: initial_indent} | rest],
    result,
    params = %{pending: @not_pending, list_indent: list_indent})
  when initial_indent >= list_indent do
    # IO.inspect [:l06, line: line]
    _dbg_read_list_lines(rest, [behead_indent(line, list_indent)|result], _opens_inline_code(line, params))
  end
  defp _read_list_lines(
    input,
    result,
    %ListInfo{pending: @not_pending, loose?: loose})
  do
    # IO.inspect [:l06, line: line]
    {loose, true, Enum.reverse(result), input}
  end
  # Only now we match for list lines inside an open multiline inline code block
  defp _read_list_lines(
         [%{line: line} | rest],
         result,
         params = %ListInfo{list_indent: list_indent, pending: pending}) do
    line1 = behead_indent(line, list_indent)
    pending1 = still_inline_code(line1, pending)
        # IO.inspect [:l12, line: line, pending: pending]
     _dbg_read_list_lines(rest, [line1 | result], %{ params | pending: pending1 })
  end
  defp _read_list_lines([],
    result,
    %ListInfo{loose?: loose, trailing_blanks?: trailing_blanks}) do
    {loose, trailing_blanks, Enum.reverse(result), []}
  end

  defp _dbg_read_list_lines(input, result, info) do

    Debugging.debug({input, result, info}, "read_list_lines")
    _read_list_lines(input, result, info)
  end


  # defp _remove_trailing_blank_lines(lines)
  # defp _remove_trailing_blank_lines([]) do
  #   []
  # end
  # defp _remove_trailing_blank_lines([""|rest]) do
  #   _remove_trailing_blank_lines(rest)
  # end
  # defp _remove_trailing_blank_lines(lines) do
  #   Enum.reverse(lines)
  # end

  # Convenience wrapper around `opens_inline_code` into a map
  defp _opens_inline_code(line, params)
  defp _opens_inline_code(line, params) when is_binary(line) do
    _opens_inline_code(%{line: line, lnb: 0}, params)
  end
  defp _opens_inline_code(line, params) do
    %{params | pending: opens_inline_code(line), trailing_blanks?: false}
  end
end
# SPDX-License-Identifier: Apache-2.0
