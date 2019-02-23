. scripts/dockerdev.bash &&
. scripts/build-dev-image.bash &&
dockerdev_ensure_dev_container_started "$IMAGE" -v "$PWD":/app/ -p 3000:3000 &&
dockerdev_run_in_dev_container "$IMAGE" bash
