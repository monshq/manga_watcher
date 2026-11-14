defmodule MangaWatcher.MangaFilter do
  @moduledoc """
  A small query language for filtering a user's mangas.

      action (isekai | fantasy) -stale -is:broken unread:>5

    * terms separated by spaces must all match, `|` separates alternatives,
      `-` negates and parentheses group
    * a bare word (or a `"quoted phrase"`) is a tag
    * `is:unread`, `is:read`, `is:broken`, `is:dormant` match the reading state
    * `site:asura` matches a part of the manga's host
    * `unread:>5` compares the number of unread chapters (`>`, `>=`, `<`, `<=`, `=`)

  A parsed query is always `{:and, terms}`, so its top-level terms can be
  inspected and rewritten.
  """

  alias MangaWatcher.Series.Manga
  alias MangaWatcher.UserMangas

  @type op :: :gt | :gte | :lt | :lte | :eq
  @type predicate ::
          {:tag, String.t()}
          | {:is, UserMangas.state()}
          | {:site, String.t()}
          | {:unread, op(), non_neg_integer()}
  @type node_ :: predicate() | {:not, node_()} | {:and, [node_()]} | {:or, [node_()]}
  @type t :: {:and, [node_()]}

  @states %{"unread" => :unread, "read" => :read, "broken" => :broken, "dormant" => :dormant}
  @ops %{">" => :gt, ">=" => :gte, "<" => :lt, "<=" => :lte, "=" => :eq, "" => :eq}
  @op_strings %{gt: ">", gte: ">=", lt: "<", lte: "<=", eq: ""}

  @spec empty() :: t()
  def empty, do: {:and, []}

  # PARSING

  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(string) when is_binary(string) do
    with {:ok, tokens} <- tokenize(string, []) do
      parse_tokens(tokens)
    end
  end

  defp parse_tokens([]), do: {:ok, empty()}

  defp parse_tokens(tokens) do
    case parse_or(tokens) do
      {:ok, {:and, _} = node, []} -> {:ok, node}
      {:ok, node, []} -> {:ok, {:and, [node]}}
      {:ok, _node, _rest} -> {:error, "unexpected )"}
      {:error, _} = error -> error
    end
  end

  defp tokenize("", acc), do: {:ok, Enum.reverse(acc)}
  defp tokenize("(" <> rest, acc), do: tokenize(rest, [:lparen | acc])
  defp tokenize(")" <> rest, acc), do: tokenize(rest, [:rparen | acc])
  defp tokenize("|" <> rest, acc), do: tokenize(rest, [:pipe | acc])
  defp tokenize("-" <> rest, acc), do: tokenize(rest, [:minus | acc])

  defp tokenize("\"" <> rest, acc) do
    case String.split(rest, "\"", parts: 2) do
      [phrase, rest] -> tokenize(rest, [{:quoted, phrase} | acc])
      [_] -> {:error, "missing closing quote"}
    end
  end

  defp tokenize(string, acc) do
    case Regex.run(~r/\A\s+/u, string) do
      [space] ->
        string
        |> binary_part(byte_size(space), byte_size(string) - byte_size(space))
        |> tokenize(acc)

      nil ->
        [word] = Regex.run(~r/\A[^\s()|"]+/u, string)
        rest = binary_part(string, byte_size(word), byte_size(string) - byte_size(word))
        tokenize(rest, [{:word, word} | acc])
    end
  end

  defp parse_or(tokens) do
    with {:ok, node, rest} <- parse_and(tokens, []) do
      parse_or_rest(rest, [node])
    end
  end

  defp parse_or_rest([:pipe | rest], acc) do
    with {:ok, node, rest} <- parse_and(rest, []) do
      parse_or_rest(rest, [node | acc])
    end
  end

  defp parse_or_rest(rest, [node]), do: {:ok, node, rest}
  defp parse_or_rest(rest, acc), do: {:ok, {:or, Enum.reverse(acc)}, rest}

  defp parse_and([token | _] = tokens, acc) when token not in [:rparen, :pipe] do
    with {:ok, node, rest} <- parse_unary(tokens) do
      parse_and(rest, [node | acc])
    end
  end

  defp parse_and(tokens, []), do: {:error, "expected a term #{position(tokens)}"}
  defp parse_and(tokens, [node]), do: {:ok, node, tokens}
  defp parse_and(tokens, nodes), do: {:ok, {:and, Enum.reverse(nodes)}, tokens}

  defp position([]), do: "at the end"
  defp position([:rparen | _]), do: "before )"
  defp position([:pipe | _]), do: "before |"

  defp parse_unary([:minus | rest]) do
    case rest do
      [next | _] when next not in [:rparen, :pipe] ->
        with {:ok, node, rest} <- parse_unary(rest), do: {:ok, {:not, node}, rest}

      _ ->
        {:error, "expected a term after -"}
    end
  end

  defp parse_unary([:lparen | rest]) do
    case parse_or(rest) do
      {:ok, node, [:rparen | rest]} -> {:ok, node, rest}
      {:ok, _node, _rest} -> {:error, "missing )"}
      {:error, _} = error -> error
    end
  end

  defp parse_unary([{:quoted, phrase} | rest]), do: {:ok, tag(phrase), rest}

  defp parse_unary([{:word, word} | rest]) do
    with {:ok, node} <- parse_word(word), do: {:ok, node, rest}
  end

  defp parse_word("is:" <> state) do
    case @states do
      %{^state => value} ->
        {:ok, {:is, value}}

      _ ->
        expected = @states |> Map.keys() |> Enum.join(", ")
        {:error, "unknown state is:#{state}, expected one of: #{expected}"}
    end
  end

  defp parse_word("site:" <> site) when site != "", do: {:ok, {:site, String.downcase(site)}}

  defp parse_word("unread:" <> comparison) do
    case Regex.run(~r/\A(>=|<=|>|<|=|)(\d{1,9})\z/, comparison) do
      [_, op, number] -> {:ok, {:unread, @ops[op], String.to_integer(number)}}
      nil -> {:error, "bad comparison unread:#{comparison}, expected e.g. unread:>5"}
    end
  end

  defp parse_word(word), do: {:ok, tag(word)}

  defp tag(name), do: {:tag, name |> String.trim() |> String.downcase()}

  # PRINTING

  @spec to_string(t()) :: String.t()
  def to_string({:and, terms}), do: Enum.map_join(terms, " ", &format/1)

  defp format({:and, terms}), do: "(" <> Enum.map_join(terms, " ", &format/1) <> ")"

  defp format({:or, alternatives}) do
    "(" <> Enum.map_join(alternatives, " | ", &format_alternative/1) <> ")"
  end

  defp format({:not, node}), do: "-" <> format(node)
  defp format({:is, state}), do: "is:#{state}"
  defp format({:site, site}), do: "site:#{site}"
  defp format({:unread, op, number}), do: "unread:#{@op_strings[op]}#{number}"

  defp format({:tag, name}) do
    if parse_word(name) == {:ok, {:tag, name}} and name =~ ~r/\A[^\s()|"-][^\s()|"]*\z/u,
      do: name,
      else: "\"#{name}\""
  end

  defp format_alternative({:and, terms}), do: Enum.map_join(terms, " ", &format/1)
  defp format_alternative(node), do: format(node)

  # REWRITING

  @doc """
  Combines the standing `base` filter with the `query` typed on top of it.

  Whatever the query mentions wins: top-level base terms about the same tag,
  state, site or unread count are dropped, so that `stale` shows stale mangas
  even when the base says `-stale`.
  """
  @spec merge(t(), t()) :: t()
  def merge(base, {:and, query_terms} = query) do
    {:and, kept} = without_overridden(base, query)
    {:and, kept ++ query_terms}
  end

  @doc "The part of the `base` filter that still applies next to the `query`, see `merge/2`."
  @spec without_overridden(t(), t()) :: t()
  def without_overridden({:and, base_terms}, query) do
    mentioned = query |> predicates() |> MapSet.new(&subject/1)

    kept =
      Enum.reject(base_terms, fn term ->
        case unwrap(term) do
          nil -> false
          predicate -> subject(predicate) in mentioned
        end
      end)

    {:and, kept}
  end

  defp unwrap({:not, node}), do: unwrap(node)
  defp unwrap({kind, _} = node) when kind in [:tag, :is, :site], do: node
  defp unwrap({:unread, _, _} = node), do: node
  defp unwrap(_), do: nil

  defp subject({:unread, _, _}), do: :unread
  defp subject(predicate), do: predicate

  defp predicates({kind, nodes}) when kind in [:and, :or], do: Enum.flat_map(nodes, &predicates/1)
  defp predicates({:not, node}), do: predicates(node)
  defp predicates(predicate), do: [predicate]

  @doc "Names of all tags the filter mentions."
  @spec tags(t()) :: [String.t()]
  def tags(filter) do
    for {:tag, name} <- predicates(filter), uniq: true, do: name
  end

  @doc "Whether a top-level term requires (`:include`) or forbids (`:exclude`) the tag."
  @spec tag_state(t(), String.t()) :: :include | :exclude | nil
  def tag_state({:and, terms}, name) do
    tag = tag(name)

    cond do
      tag in terms -> :include
      {:not, tag} in terms -> :exclude
      true -> nil
    end
  end

  @doc "Cycles a tag among top-level terms: absent -> included -> excluded -> absent."
  @spec toggle_tag(t(), String.t()) :: t()
  def toggle_tag({:and, terms} = filter, name) do
    tag = tag(name)

    case tag_state(filter, name) do
      nil -> {:and, terms ++ [tag]}
      :include -> {:and, Enum.map(terms, &if(&1 == tag, do: {:not, tag}, else: &1))}
      :exclude -> {:and, terms -- [{:not, tag}]}
    end
  end

  # MATCHING

  @doc """
  Whether the manga passes the filter for the given user. The manga must have
  its tags and the user's `user_mangas` record preloaded.
  """
  @spec match?(t(), Manga.t(), integer()) :: boolean()
  def match?(filter, %Manga{} = manga, user_id) do
    eval(filter, %{
      tags: MapSet.new(manga.tags, &String.downcase(&1.name)),
      state: UserMangas.manga_state(manga, user_id),
      host: String.downcase(URI.parse(manga.url || "").host || ""),
      unread: (manga.last_chapter || 0) - UserMangas.user_manga!(manga, user_id).last_read_chapter
    })
  end

  defp eval({:and, nodes}, facts), do: Enum.all?(nodes, &eval(&1, facts))
  defp eval({:or, nodes}, facts), do: Enum.any?(nodes, &eval(&1, facts))
  defp eval({:not, node}, facts), do: not eval(node, facts)
  defp eval({:tag, name}, facts), do: name in facts.tags
  defp eval({:is, state}, facts), do: facts.state == state
  defp eval({:site, site}, facts), do: String.contains?(facts.host, site)
  defp eval({:unread, :gt, number}, facts), do: facts.unread > number
  defp eval({:unread, :gte, number}, facts), do: facts.unread >= number
  defp eval({:unread, :lt, number}, facts), do: facts.unread < number
  defp eval({:unread, :lte, number}, facts), do: facts.unread <= number
  defp eval({:unread, :eq, number}, facts), do: facts.unread == number
end
