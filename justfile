image := "cr.mons.one/manga_watcher:latest"

build:
	podman build --platform linux/amd64 -t {{image}} .

# requires `podman login cr.mons.one` beforehand
push: build
	podman push {{image}}

# same steps as .github/workflows/docker.yml: push the image, then ask the server to redeploy
deploy: push
	sleep 5
	curl -fsS --max-time 30 -X POST \
		-H "Content-Type: application/json" \
		-d '{"service":"manga_watcher"}' \
		https://r.mons.one/webhook/deploy
