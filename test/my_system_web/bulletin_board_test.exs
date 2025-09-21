defmodule MySystemWeb.BulletinBoardTest do
  use MySystemWeb.ConnCase, async: true

  test "adds post", %{conn: conn} do
    conn
    |> visit(~p"/bulletin_board/buildingblocks")
    |> open_browser()
    |> fill_in("Text", with: "Huhahahaha")
    |> fill_in("Author", with: "Woody Woodypecker")
    |> submit()
    |> assert_has("li", text: "Huhahahaha", text: 1000)
  end
end
