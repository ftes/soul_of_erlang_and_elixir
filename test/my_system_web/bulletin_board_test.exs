defmodule MySystemWeb.BulletinBoardTest do
  use MySystemWeb.ConnCase, async: false

  describe "regular user" do
    test "add post", %{conn: conn} do
      conn
      |> visit(~p"/board/buildingblocks")
      |> fill_in("Text", with: "Huhahahaha")
      |> fill_in("Author", with: "Woody Woodypecker")
      |> submit()
      |> assert_has("li", text: "Huhahahaha", text: 1000)
    end
  end

  describe "admin" do
    test "delete post", %{conn: conn} do
      post_fixture(%{text: "My post"})

      conn
      |> visit(~p"/board/building-blocks/admin")
      |> assert_has("li", text: "My post", timeout: 1000)
      |> click_button("Delete post")
      |> refute_has("li", text: "My post")
    end
  end

  defp post_fixture(attrs) do
    attrs = Enum.into(attrs, %{author: "author", text: "text", topic: "building-blocks"})
    :ok = MySystem.BulletinBoard.save_post(attrs.author, attrs.text, attrs.topic)
  end
end
