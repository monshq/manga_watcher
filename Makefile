
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
	cp -r _build/prod/rel/manga_watcher/* /srv/projects/manga_watcher/
	init-exporter -p Procfile manga_watcher
	sudo systemctl restart apps-manga_watcher
