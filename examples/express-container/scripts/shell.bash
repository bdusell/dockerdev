. scripts/_dockerdev_container.bash &&
. scripts/build-dev-image.bash &&
dockerdev_ensure_dev_container_started "$IMAGE" -v "$PWD":/app/ -p 3000:3000 &&
dockerdev_exec_dev "$IMAGE" bash
