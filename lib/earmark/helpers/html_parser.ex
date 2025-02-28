defmodule Earmark.Helpers.HtmlParser do

  @moduledoc false

  import Earmark.Helpers.StringHelpers, only: [behead: 2]
  import Earmark.LineScanner, only: [void_tag?: 1]

  def parse_html(lines)
  def parse_html([tag_line|rest]) do
    case _parse_tag(tag_line) do
      nil                   -> [tag_line|rest]
      { :ok, tag, "" }      -> [_parse_rest(rest, tag, [])]
      { :ok, tag, suffix }  -> [_parse_rest(rest, tag, [suffix])]
      { :ext, tag, "" }     -> [_parse_rest(rest, tag, [])]
      { :ext, tag, suffix } -> [_parse_rest(rest, tag, []), [suffix]]
    end
  end

  # Parse One Tag
  # -------------

  @attribute ~r{\A([-\w]+)=(["'])(.*?)\2\s*}
  defp _parse_atts(string, tag, atts) do
    case Regex.run(@attribute, string) do
      [all, name, _delim, value] -> _parse_atts(behead(string, all), tag, [{name, value}|atts])
      _                          -> _parse_tag_tail(string, tag, atts)
    end
  end

  @attribute ~r{\A([-\w]+)=(["'])(.*?)\2\s*(>?)}
  defp _parse_atts(string, tag, atts) do
    case Regex.run(@attribute, string) do
      [all, name, _delim, value,] -> _parse_atts(behead(string, all), tag, [{name, value}|atts])
      _                          -> _parse_tag_tail(string, tag, atts)
    end
  end
  # Are leading and trailing "-"s ok?
  @tag_head ~r{\A\s*<([-\w]+)\s*}
  defp _parse_tag(string) do
    case Regex.run(@tag_head, string) do
      [all, tag] -> _parse_atts(behead(string, all), tag, [])
      _          -> nil
    end
  end

  @tag_tail  ~r{\A(/?)>\s*(.*)\z}
  defp _parse_tag_tail(string, tag, atts) do
    case Regex.run(@tag_tail, string) do
      [_, closing, suffix]  ->
        _close_tag_tail(tag, atts, closing != "", suffix)
      # [_, _, ""]            -> {:ok, {tag, Enum.reverse(atts)} }
      # [_, "", suffix]       -> {:ok, {tag, Enum.reverse(atts)}, suffix }
      # [_, _closing, suffix] -> {:ext, {tag, Enum.reverse(atts)}, suffix }
      _                     -> nil
    end
  end

  defp _close_tag_tail(tag, atts, closing?, suffix) do
    if closing? || void_tag?(tag) do
      {:ext, {tag, Enum.reverse(atts)}, suffix }
    else
      {:ok, {tag, Enum.reverse(atts)}, suffix }
    end
  end

  # Iterate over lines inside a tag
  # -------------------------------

  defp _parse_rest(rest, tag_tpl, lines)
  # Hu? That should never have happened but let us return some
  # sensible data, allowing rendering after the corruped block
  defp _parse_rest([], tag_tpl, lines) do
    tag_tpl |> Tuple.append(Enum.reverse(lines))
  end
  defp _parse_rest([last_line], {tag, _}=tag_tpl, lines) do
    case Regex.run(~r{\A</#{tag}>\s*(.*)}, last_line) do
      nil         -> tag_tpl |> Tuple.append(Enum.reverse([last_line|lines]))
      [_, ""]     -> tag_tpl |> Tuple.append(Enum.reverse(lines))
      [_, suffix] -> [tag_tpl |> Tuple.append(Enum.reverse(lines)), suffix]
    end
  end
  defp _parse_rest([inner_line|rest], tag_tpl, lines) do
    _parse_rest(rest, tag_tpl, [inner_line|lines])
  end

end
