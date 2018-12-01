IMAGE=express-container &&
version=$(< VERSION) &&
docker build -t "$IMAGE":"$version" -f Dockerfile-dev . &&
docker tag "$IMAGE":"$version" "$IMAGE":latest
