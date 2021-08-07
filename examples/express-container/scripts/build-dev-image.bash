set -e
set -u
set -o pipefail

. scripts/_variables.bash

version=$(< VERSION)
docker build "$@" -t "$IMAGE":"$version" -f Dockerfile-dev .
docker tag "$IMAGE":"$version" "$IMAGE":latest
