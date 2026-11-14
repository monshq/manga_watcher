defmodule MangaWatcher.MangaFilterTest do
  use MangaWatcher.DataCase, async: true

  import MangaWatcher.AccountsFixtures
  import MangaWatcher.SeriesFixtures

  alias MangaWatcher.MangaFilter
  alias MangaWatcher.UserMangas

  defp parse!(query) do
    {:ok, filter} = MangaFilter.parse(query)
    filter
  end

  describe "parse/1" do
    test "returns an empty filter for a blank query" do
      assert MangaFilter.parse("") == {:ok, {:and, []}}
      assert MangaFilter.parse("  \n ") == {:ok, {:and, []}}
    end

    test "parses tags, negation and predicates into top-level terms" do
      assert parse!("Isekai -slow-burner is:unread -is:broken site:Asura unread:>5") ==
               {:and,
                [
                  {:tag, "isekai"},
                  {:not, {:tag, "slow-burner"}},
                  {:is, :unread},
                  {:not, {:is, :broken}},
                  {:site, "asura"},
                  {:unread, :gt, 5}
                ]}
    end

    test "parses alternatives and groups" do
      assert parse!("a | b") == {:and, [{:or, [{:tag, "a"}, {:tag, "b"}]}]}

      assert parse!("a (b | c d) -(e f)") ==
               {:and,
                [
                  {:tag, "a"},
                  {:or, [{:tag, "b"}, {:and, [{:tag, "c"}, {:tag, "d"}]}]},
                  {:not, {:and, [{:tag, "e"}, {:tag, "f"}]}}
                ]}
    end

    test "parses quoted tags and unread comparisons" do
      assert parse!(~s("slice of life" "is:read")) ==
               {:and, [{:tag, "slice of life"}, {:tag, "is:read"}]}

      assert parse!("unread:3 unread:=3 unread:>=1 unread:<2 unread:<=9") ==
               {:and,
                [
                  {:unread, :eq, 3},
                  {:unread, :eq, 3},
                  {:unread, :gte, 1},
                  {:unread, :lt, 2},
                  {:unread, :lte, 9}
                ]}
    end

    test "rejects malformed queries" do
      for query <- ["(a", "a)", "a |", "| a", "()", "-", "a -)", ~s("a), "is:nope", "unread:many"] do
        assert {:error, message} = MangaFilter.parse(query)
        assert is_binary(message)
      end
    end
  end

  describe "to_string/1" do
    test "round-trips queries" do
      for query <- [
            "",
            "isekai -stale is:unread -is:broken site:asura unread:>5 unread:3",
            "a (b | c d) -(e f)",
            ~s("slice of life" "is:read" "-x")
          ] do
        assert query |> parse!() |> MangaFilter.to_string() == query
      end
    end
  end

  describe "merge/2" do
    test "appends the query to the base" do
      assert MangaFilter.merge(parse!("-stale -is:broken"), parse!("isekai")) ==
               parse!("-stale -is:broken isekai")
    end

    test "drops base terms about anything the query mentions" do
      base = parse!("-stale -is:broken unread:>0 (a | b)")

      assert MangaFilter.merge(base, parse!("stale")) ==
               parse!("-is:broken unread:>0 (a | b) stale")

      assert MangaFilter.merge(base, parse!("(x | is:broken) unread:<3 a")) ==
               parse!("-stale (a | b) (x | is:broken) unread:<3 a")
    end
  end

  describe "tags" do
    test "tags/1 lists every mentioned tag once" do
      assert MangaFilter.tags(parse!("a -b (c | a) is:read")) == ["a", "b", "c"]
    end

    test "toggle_tag/2 cycles a top-level tag and keeps the rest" do
      filter = parse!("(a | b) is:unread")

      included = MangaFilter.toggle_tag(filter, "Seinen")
      assert MangaFilter.to_string(included) == "(a | b) is:unread seinen"
      assert MangaFilter.tag_state(included, "seinen") == :include

      excluded = MangaFilter.toggle_tag(included, "seinen")
      assert MangaFilter.to_string(excluded) == "(a | b) is:unread -seinen"
      assert MangaFilter.tag_state(excluded, "seinen") == :exclude

      assert MangaFilter.toggle_tag(excluded, "seinen") == filter
      assert MangaFilter.tag_state(filter, "a") == nil
    end
  end

  describe "match?/3" do
    setup do
      user = user_fixture()

      manga =
        manga_for_user_fixture(user, %{
          url: "http://asuracomic.net/series/one",
          last_chapter: 10,
          tags: "Seinen, school",
          user_manga: %{last_read_chapter: 4}
        })

      %{user: user, manga: UserMangas.get_manga!(user.id, manga.id)}
    end

    defp matches?(query, manga, user), do: query |> parse!() |> MangaFilter.match?(manga, user.id)

    test "matches tags case-insensitively", %{user: user, manga: manga} do
      assert matches?("", manga, user)
      assert matches?("seinen SCHOOL", manga, user)
      refute matches?("seinen josei", manga, user)
      assert matches?("josei | school", manga, user)
      refute matches?("-seinen", manga, user)
      assert matches?("-(seinen josei)", manga, user)
    end

    test "matches state, site and unread count", %{user: user, manga: manga} do
      assert matches?("is:unread -is:read -is:broken -is:dormant", manga, user)
      assert matches?("site:asura", manga, user)
      refute matches?("site:series", manga, user)
      assert matches?("unread:6 unread:>5 unread:>=6 unread:<7 unread:<=6", manga, user)
      refute matches?("unread:>6", manga, user)
    end

    test "states are exclusive", %{user: user, manga: manga} do
      broken = %{manga | failed_updates: 6}

      assert matches?("is:broken", broken, user)
      refute matches?("is:unread", broken, user)
    end
  end
end
