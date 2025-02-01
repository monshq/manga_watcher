#!/bin/bash
set -e

export MIX_ENV=prod

# check we are in correct directory
[ -f bin/manga_watcher ] || exit 1

# stop the old service
sudo systemctl stop apps-manga_watcher

# save previous release into prev directory
rm -rf /srv/projects/manga_watcher/prev
mv -f /srv/projects/manga_watcher/current /srv/projects/manga_watcher/prev
mkdir -p /srv/projects/manga_watcher/current

# copy new release
cp -r * /srv/projects/manga_watcher/current

# link shared directories
ln -sn /var/log/projects/manga_watcher /srv/projects/manga_watcher/current/log
rm -rf /srv/projects/manga_watcher/current/shared
ln -sn /srv/projects/manga_watcher/shared /srv/projects/manga_watcher/current/shared

# export and start the updated service
sudo init-exporter -p Procfile manga_watcher
sudo systemctl restart apps-manga_watcher
