defmodule EarmarkHelpersTests.ListHelpers.SpaceListsTest do
  use ExUnit.Case

  alias Earmark.Block
  import Earmark.Helpers.ListHelpers, only: [loosen_lists: 1]

  @one_input [
  %Block.Blank{},
  %Block.List{
    attrs: nil,
    blocks: [
      %Block.ListItem{
        attrs: nil,
        blocks: [
          :blank,
          %Block.Para{attrs: nil, lines: ["one"], lnb: 1}
        ],
        bullet: "-",
        bullet_type: "-",
        lnb: 1,
        spaced: true,
        type: :ul
      }
    ],
    bullet: "-, +, *, 1) or 2.",
    bullet_type: "-",
    lnb: 1,
    start: "",
    type: :ul
  },
  :blank
] 

  @one_output [
  %Block.Blank{},
  %Block.List{
    attrs: nil,
    blocks: [
      %Block.ListItem{
        attrs: nil,
        blocks: [
          :blank,
          %Block.Para{attrs: nil, lines: ["one"], lnb: 1}
        ],
        bullet: "-",
        bullet_type: "-",
        lnb: 1,
        spaced: false,
        type: :ul
      }
    ],
    bullet: "-, +, *, 1) or 2.",
    bullet_type: "-",
    lnb: 1,
    start: "",
    type: :ul
  },
  :blank
]
  test "one" do
    assert loosen_lists(@one_input) == @one_output
  end
end
