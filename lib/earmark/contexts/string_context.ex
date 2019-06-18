defmodule Earmark.Contexts.StringContext do
  
  @doc """
  Remove the leading part of a string

        iex(0)> behead("alpha", 2)
        "pha"

        iex(1)> behead("omega", "beta")
        "a"

  """
  @spec behead( binary(), binary() | number() ) :: binary()
  def behead(str, ignore)
  def behead(str, ignore) when is_integer(ignore) do
    String.slice(str, ignore..-1)
  end
  def behead(str, leading_string) do
    behead(str, String.length(leading_string))
  end

  @doc """
  Remove the leading indent of a string, thusly

      iex(2)> behead_indent(" ab", 6)
      "ab"

      iex(3)> behead_indent("  ab", 1)
      " ab"
  
  """
  @spec behead_indent( binary(), number() ) :: binary()
  def behead_indent(str, ignore) do
    Regex.replace(~r<\A\s{0,#{ignore}}>, str, "")
  end
  @doc """
  Returns a tuple with the prefix and the beheaded string

        iex(4)> behead_tuple("prefixpostfix", "prefix")
        {"prefix", "postfix"}
  """
  def behead_tuple(str, lead) do
    {lead, behead(str, lead)}
  end
end
