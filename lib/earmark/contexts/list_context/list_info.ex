defmodule Earmark.Contexts.ListContext.ListInfo do
  @moduledoc """
  Represents the information needed by the parser to decide if
  a line does still belong to a list item and if it is loose (<p>...</p>).
  """
  defstruct [
    bullet_type: "-, *, +, ), .",
    pending: {nil, 0}, # or { "`", 42}
    indent: 0,      # "  1. a" --> 2
    list_indent: 0, # "  1. a" --> 5
    loose?: false,
    trailing_blanks?: false,
    type: :ul ] # or | :ol 
end
