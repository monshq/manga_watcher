# Creating users

One-liner to transfer status of last read chapters to a new user:
```elixir
MangaWatcher.Series.list_mangas() |> Enum.map(fn(m) -> {:ok, um} = MangaWatcher.UserMangas.add_manga(1, %{url: m.url}); MangaWatcher.UserMangas.update_user_manga(um, %{last_read_chapter: m.last_read_chapter}) end); :ok
```

To allow postgres user to create extension (citext):
```sql
grant create on database manga_watcher to manga_watcher;
```
