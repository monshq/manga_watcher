add-test-page:
	curl -sLo test/support/fixtures/website_pages/$(NAME).html $(URL)

build:
	docker build --platform linux/amd64 --output type=tar,dest=release.tar .
	gzip -f release.tar

upload:
	scp release.tar.gz $(SERVER):/var/tmp/release.tar.gz

unpack:
	ssh $(SERVER) 'cd /var/tmp && rm -rf release && mkdir release && tar zxf release.tar.gz --directory=release'

start:
	ssh $(SERVER) 'cd /var/tmp/release && script/deploy.sh'
	echo 'release successful'

release: build upload unpack start

release-local:
	script/deploy.sh
