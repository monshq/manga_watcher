
add-test-page:
	curl -sLo test/support/fixtures/website_pages/$(NAME).html $(URL)

build:
	docker build --output type=tar,dest=release.tar .
	gzip -f release.tar

upload:
	scp release.tar.gz $(SERVER):/srv/projects/manga_watcher/release.tar.gz

unpack:
	ssh $(SERVER) 'cd /srv/projects/manga_watcher && tar zxf release.tar.gz'

start:
	ssh $(SERVER) 'init-exporter -p Procfile manga_watcher'
	ssh $(SERVER) 'sudo systemctl restart apps-manga_watcher'
	echo 'release successful'

release: build upload unpack start

release-local:
	MIX_ENV=prod mix do assets.deploy, release --overwrite
	sudo systemctl stop apps-manga_watcher
	rm -rf /srv/projects/manga_watcher/prev
	mv -f /srv/projects/manga_watcher/current /srv/projects/manga_watcher/prev
	mkdir -p /srv/projects/manga_watcher/current
	cp -r _build/prod/rel/manga_watcher/* /srv/projects/manga_watcher/current
	ln -sn /var/log/projects/manga_watcher /srv/projects/manga_watcher/current/log
	rm -rf /srv/projects/manga_watcher/current/shared
	ln -sn /srv/projects/manga_watcher/shared /srv/projects/manga_watcher/current/shared
	sudo init-exporter -p Procfile manga_watcher
	sudo systemctl restart apps-manga_watcher
