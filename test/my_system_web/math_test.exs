defmodule MySystemWeb.MathTest do
  use MySystemWeb.ConnCase, async: false

  test "it works", %{conn: conn} do
    conn
    |> visit(~p"/")
    |> fill_in("Input", with: "5")
    |> submit()
    |> assert_has("[data-operation]", text: "∑(1..5) = 15", timeout: 1000)
  end
end
