defmodule Earmark.Ast.Inline do

  @moduledoc false

  alias Earmark.Context
  alias Earmark.Helpers.LinkParser

  import Earmark.Ast.Renderer.AstWalker
  import Earmark.Helpers
  import Earmark.Helpers.AttrParser
  import Earmark.Helpers.StringHelpers, only: [behead: 2]
  import Earmark.Helpers.AstHelpers
  import Earmark.Context, only: [set_value: 2, update_context: 0]

  @typep conversion_data :: {String.t, non_neg_integer(), Earmark.Context.t, boolean()}
  def conv(src) do
    _convert(src, 0, update_context(), true).value
  end
  def convert(src, lnb, context)
  def convert(list, lnb, context) when is_list(list),
    do: _convert(Enum.join(list, "\n"), lnb, context, true)
  def convert(src, lnb, context), do: _convert(src, lnb, context, true)

  defp _convert(src, current_lnb, context, use_linky?)
  defp _convert("", _, context, _), do: context
  defp _convert(src, current_lnb, context, use_linky?) do
    case _convert_next(src, current_lnb, context, use_linky?) do
      {src1, lnb1, context1, use_linky1?} -> _convert(src1, lnb1, context1, use_linky1?)
      x -> raise "Internal Conversion Error\n\n#{inspect x}"
    end
  end

  @linky_converter_names [
    :converter_for_link_and_image,
    :converter_for_reflink,
    :converter_for_footnote,
    :converter_for_nolink
  ]

  defp all_converters do
    [
      converter_for_escape: &converter_for_escape/1,
      converter_for_autolink: &converter_for_autolink/1,
      converter_for_link_and_image: &converter_for_link_and_image/1,
      converter_for_only_image: &converter_for_only_image/1,
      converter_for_reflink: &converter_for_reflink/1,
      converter_for_footnote: &converter_for_footnote/1,
      converter_for_nolink: &converter_for_nolink/1,
      converter_for_strikethrough_gfm: &converter_for_strikethrough_gfm/1,
      converter_for_strong: &converter_for_strong/1,
      converter_for_em: &converter_for_em/1,
      converter_for_code: &converter_for_code/1,
      converter_for_br: &converter_for_br/1,
      converter_for_inline_ial: &converter_for_inline_ial/1,
      converter_for_pure_link: &converter_for_pure_link/1,
      converter_for_text: &converter_for_text/1
    ]

  end

  defp _convert_next(src, lnb, context, use_linky?) do
    converters =
      if use_linky? do
        all_converters()
      else
        all_converters() |> Keyword.drop(@linky_converter_names)
      end
    _find_and_execute_converter({src, lnb, context, use_linky?}, converters)
  end

  @spec _find_and_execute_converter( conversion_data(), list ) :: conversion_data()
  defp _find_and_execute_converter({src, lnb, context, use_linky?}, converters) do
    converters
    |> Enum.find_value( fn {_converter_name, converter} -> converter.({src, lnb, context, use_linky?}) end)
  end

  ######################
  #
  #  Converters
  #
  ######################
  defp converter_for_escape({src, lnb, context, use_linky?}) do
    if match = Regex.run(context.rules.escape, src) do
      [match, escaped] = match
      {behead(src, match), lnb, prepend(context, escaped), use_linky?}
    end
  end

  @autolink_rgx ~r{^<([^ >]+(@|:\/)[^ >]+)>}
  defp converter_for_autolink({src, lnb, context, use_linky?}) do
    if match = Regex.run(@autolink_rgx, src) do
      [match, link, protocol] = match
      {href, text} = convert_autolink(link, protocol)
      out = render_link(href, text)
      {behead(src, match), lnb, prepend(context, out), use_linky?}
    end
  end

  @pure_link_rgx ~r{\A\s*(https?://\S+\b)}u
  defp converter_for_pure_link({src, lnb, context, use_linky?}) do
    if context.options.pure_links do
      case Regex.run(@pure_link_rgx, src) do
        [ match, link_text ] ->
          out = render_link(link_text, link_text)
          {behead(src, match), lnb, prepend(context, out), use_linky?}
          _ -> nil
      end
    end
  end

  defp converter_for_link_and_image({src, lnb, context, use_linky?}) do
    match = LinkParser.parse_link(src, lnb)
    if match do
      {match1, text, href, title, link_or_img} = match
      out =
        case link_or_img do
          :link  -> output_link(context, text, href, title, lnb)
          :image -> render_image(text, href, title)
        end
      {behead(src, match1), lnb, prepend(context, out), use_linky?}
    end
  end

  defp converter_for_only_image({src, lnb, context, use_linky?}) do
    case LinkParser.parse_link(src, lnb) do
      {match1, text, href, title, :image} ->
        out = render_image(text, href, title)
        {behead(src, match1), lnb, prepend(context, out), use_linky?}
      _ -> nil
    end
  end

  defp converter_for_reflink({src, lnb, context, use_linky?}) do
    if match = Regex.run(context.rules.reflink, src) do
      {match, alt_text, id} =
        case match do
          [match, id, ""] -> {match, id, id}
          [match, alt_text, id] -> {match, alt_text, id}
        end

      case reference_link(context, match, alt_text, id, lnb) do
        {:ok, out} -> {behead(src, match), lnb, prepend(context, out), use_linky?}
        _ -> nil
      end
    end
  end

  defp converter_for_footnote({src, lnb, context, use_linky?}) do
    case Regex.run(context.rules.footnote, src) do
      [match, id] ->
        case footnote_link(context, match, id) do
          {:ok, out} -> {behead(src, match), lnb, prepend(context, out), use_linky?}
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp converter_for_nolink({src, lnb, context, use_linky?}) do
    case Regex.run(context.rules.nolink, src) do
      [match, id] ->
        case reference_link(context, match, id, id, lnb) do
          {:ok, out} -> {behead(src, match), lnb, prepend(context, out), use_linky?}
          _ -> nil
        end

      _ ->
        nil
    end
  end

  ################################
  # Simple Tags: em, strong, del #
  ################################
  @strikethrough_rgx ~r{\A~~(?=\S)([\s\S]*?\S)~~}
  defp converter_for_strikethrough_gfm({src, _, _, _}=conv_tuple) do
    if match = Regex.run(@strikethrough_rgx, src) do
      _converter_for_simple_tag(conv_tuple, match, "del")
    end
  end
  @strong_rgx ~r{\A__([\s\S]+?)__(?!_)|^\*\*([\s\S]+?)\*\*(?!\*)}
  defp converter_for_strong({src, _, _, _}=conv_tuple) do
    if match = Regex.run(@strong_rgx, src) do
      _converter_for_simple_tag(conv_tuple, match, "strong")
    end
  end
  @emphasis_rgx ~r{\A\b_((?:__|[\s\S])+?)_\b|^\*((?:\*\*|[\s\S])+?)\*(?!\*)}
  defp converter_for_em({src, _, _, _}=conv_tuple) do
    if match = Regex.run(@emphasis_rgx, src) do
      _converter_for_simple_tag(conv_tuple, match, "em")
    end
  end

  @squash_ws ~r{\s+}
  defp converter_for_code({src, lnb, context, use_linky?}) do
    if match = Regex.run(context.rules.code, src) do
      [match, _, content] = match
      # Commonmark
      content1 = content
      |> String.trim()
      |> String.replace(@squash_ws, " ")

      out = codespan(content1) # |> IO.inspect)
      {behead(src, match), lnb, prepend(context, out), use_linky?}
    end
  end

  defp converter_for_inline_ial(conv_data)
  defp converter_for_inline_ial(
         {src, lnb, context, use_linky?}
       ) do
    if match = Regex.run(context.rules.inline_ial, src) do
      [match, ial] = match
      {context1, ial_attrs} = parse_attrs(context, ial, lnb)
      new_tags = augment_tag_with_ial(context.value, ial_attrs)
      {behead(src, match), lnb, set_value(context1, new_tags), use_linky?}
    end
  end
  defp converter_for_inline_ial(_conv_data), do: nil

  defp converter_for_br({src, lnb, context, use_linky?}) do
    if match = Regex.run(context.rules.br, src, return: :index) do
      [{0, match_len}] = match
      {behead(src, match_len), lnb, prepend(context, {"br", [], []}), use_linky?}
    end
  end

  @line_ending ~r{\r\n?|\n}
  @spec converter_for_text( conversion_data() ) :: conversion_data()
  defp converter_for_text({src, lnb, context, _}) do
    matched =
      case Regex.run(context.rules.text, src) do
        [match] -> match
      end

    line_count = matched |> String.split(@line_ending) |> Enum.count

    ast = hard_line_breaks(matched, context.options.gfm)
    ast = walk_ast(ast, &gruber_line_breaks/1)
    {behead(src, matched), lnb + line_count - 1, prepend(context, ast), true}
  end

  ######################
  #
  #  Helpers
  #
  ######################
  defp _converter_for_simple_tag({src, lnb, context, use_linky?}, match, for_tag) do
    {match1, content} =
      case match do
        [m, _, c] -> {m, c}
        [m, c] -> {m, c}
      end

    context1 = _convert(content, lnb, set_value(context, []), use_linky?)

    {behead(src, match1), lnb, prepend(context, {for_tag, [], context1.value|>Enum.reverse}), use_linky?}
  end


  defp convert_autolink(link, separator)
  defp convert_autolink(link, _separator = "@") do
    link = if String.at(link, 6) == ":", do: behead(link, 7), else: link
    text = link
    href = "mailto:" <> text
    {href, text}
  end
  defp convert_autolink(link, _separator) do
    {link, link}
  end

  @gruber_line_break Regex.compile!(" {2,}(?>\n)", "m")
  defp gruber_line_breaks(text) do
    text
    |> String.split(@gruber_line_break)
    |> Enum.intersperse({"br", [], []})
    |> _remove_leading_empty()
  end

  @gfm_hard_line_break ~r{\\\n}
  defp hard_line_breaks(text, gfm)
  defp hard_line_breaks(text, false), do: text
  defp hard_line_breaks(text, nil), do: text
  defp hard_line_breaks(text, _) do
    text
    |> String.split(@gfm_hard_line_break)
    |> Enum.intersperse({"br", [], []})
    |> _remove_leading_empty()
  end


  defp output_image_or_link(context, link_or_image, text, href, title, lnb)
  defp output_image_or_link(_context, "!" <> _, text, href, title, _lnb) do
    render_image(text, href, title)
  end
  defp output_image_or_link(context, _, text, href, title, lnb) do
    output_link(context, text, href, title, lnb)
  end

  defp output_link(context, text, href, title, lnb) do
    context1 = %{context | options: %{context.options | pure_links: false}}

    context2 = _convert(text, lnb, set_value(context1, []), false)
    if title do
      { "a", [{"href", href}, {"title", title}], context2.value }
    else
      { "a", [{"href", href}], context2.value }
    end
  end

  defp reference_link(context, match, alt_text, id, lnb) do
    id = id |> replace(~r{\s+}, " ") |> String.downcase()

    case Map.fetch(context.links, id) do
      {:ok, link} ->
        {:ok, output_image_or_link(context, match, alt_text, link.url, link.title, lnb)}

      _ ->
        nil
    end
  end

  defp footnote_link(context, _match, id) do
    case Map.fetch(context.footnotes, id) do
      {:ok, %{number: number}} ->
        {:ok, render_footnote_link("fn:#{number}", "fnref:#{number}", number)}
      _ ->
        nil
    end
  end

  defp prepend(%Context{}=context, prep) do
    _prepend(context, prep)
  end

  defp _prepend(context, value)
  defp _prepend(context, [bin|rest]) when is_binary(bin) do
    _prepend(_prepend(context, bin), rest)
  end
  defp _prepend(%Context{value: [str|rest]}=context, prep) when is_binary(str) and is_binary(prep) do
    %{context | value: [str <> prep|rest]}
  end
  defp _prepend(%Context{value: value}=context, prep) when is_list(prep) do
    %{context | value: Enum.reverse(prep) ++ value}
  end
  defp _prepend(%Context{value: value}=context, prep) do
    %{context | value: [prep | value]}
  end

  defp _remove_leading_empty(list)
  defp _remove_leading_empty([""|rest]), do: rest
  defp _remove_leading_empty(list), do: list

end

# SPDX-License-Identifier: Apache-2.0
