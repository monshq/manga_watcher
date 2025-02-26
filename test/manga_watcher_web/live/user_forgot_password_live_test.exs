defmodule MangaWatcherWeb.UserForgotPasswordLiveTest do
  use MangaWatcherWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MangaWatcher.AccountsFixtures

  alias MangaWatcher.Accounts
  alias MangaWatcher.Repo

  describe "Forgot password page" do
    test "renders email page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/users/reset_password")

      assert html =~ "Forgot your password?"
      assert has_element?(lv, ~s|a[href="#{~p"/users/log_in"}"]|, "Log in")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/reset_password")

      assert {:error, {:redirect, _}} = result
    end
  end

  describe "Reset link" do
    setup do
      %{user: user_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password")

      {:error, {:redirect, _}} =
        lv
        |> form("#reset_password_form", user: %{"email" => user.email})
        |> render_submit()

      assert Repo.get_by!(Accounts.UserToken, user_id: user.id).context ==
               "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password")

      {:error, {:redirect, _}} =
        lv
        |> form("#reset_password_form", user: %{"email" => "unknown@example.com"})
        |> render_submit()

      assert Repo.all(Accounts.UserToken) == []
    end
  end
end
