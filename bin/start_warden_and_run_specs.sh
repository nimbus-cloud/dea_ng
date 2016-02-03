#!/bin/bash
set -e -x -u

# Start warden

mkdir -p /tmp/warden/rootfs

echo -n "Extracting rootfs..."
sudo tar -xf /var/cf-release/.blobs/`basename $(readlink /var/cf-release/blobs/rootfs/*)` -C /tmp/warden/rootfs
echo "finished"

(
  cd /var/cf-release/src/dea-hm-workspace/src/warden/warden
  sudo bundle install
  bundle exec rake setup:bin
  sudo bundle exec rake warden:start[config/linux.yml] &> /tmp/warden.log &
)

echo "waiting for warden to come up"
while [ ! -e /tmp/warden.sock ]
do
  sleep 1
done
echo "warden is ready"

# Start foreman (directory server & nats)

cd /var/cf-release/src/dea-hm-workspace/src/dea_next
sudo bundle install
sudo bundle exec foreman start &> /tmp/foreman.log &

# Run specs

exit_code=0
bundle install
bundle exec rspec spec/unit -fd
exit_code=$?

bundle exec rspec spec/integration -fd
exit_code=$?

echo "Tests finished: killing background jobs:"
jobs

JOBS="ruby rake runner"
for j in $JOBS
do
	sudo killall $j
done

exit $exit_code
