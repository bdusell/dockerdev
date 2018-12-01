# This file defines functions for managing *stacks* of Docker containers
# (created with `docker stack deploy`) that are meant to serve as local
# development environments. This is necessary if, for example, you want to use
# a container with Docker secrets.
#
# You should source this file in another bash script like so:
#
#     . _dockerdev_stack.bash
#
# You will mainly be interested in this function:
# * dockerdev_run_in_dev_stack_container

. "$(dirname "$BASH_SOURCE")"/_dockerdev_container.bash || exit

# dockerdev_get_service_container_name <service>
#   Get the full name of a service's container.
dockerdev_get_service_container_name() {
  local service=$1
  local id
  local name
  id=$(docker service ps "$service" --filter desired-state=running -q) &&
  [[ $id ]] &&
  name=$(docker service ps "$service" --filter id="$id" --format '{{.Name}}') &&
  printf '%s' "$name"."$id"
}

# dockerdev_get_container_image <container>
#   Get the full name of a container's image.
dockerdev_get_container_image() {
  local container=$1
  docker ps -a --filter name="^/$container\$" --format '{{.Image}}'
}

# dockerdev_ensure_service_image_updated <service> <image>
#   Ensure that a service is running a certain image. This is usually used to
#   ensure that the service is running the latest version of an image.
dockerdev_ensure_service_image_updated() {
  local service=$1
  local image=$2
  local container
  local current_image
  while ! container=$(dockerdev_get_service_container_name "$service"); do
    echo "Waiting for service $service to appear..." &&
    sleep 1
  done &&
  current_image=$(dockerdev_get_container_image "$container") &&
  while [[ $current_image = '' ]]; do
    echo "Waiting for container $container to appear..." &&
    sleep 1 &&
    { current_image=$(dockerdev_get_container_image "$container") || return; }
  done &&
  echo "Found container $container." &&
  if [[ $current_image != $image ]]; then
    echo "Updating image of service $service from $current_image to $image..." &&
    docker service update --image "$image" --force "$service"
  else
    echo "Image of service $service is already up to date."
  fi
}

# dockerdev_ping_container <container>
#   Tell whether a container is ready to execute commands.
dockerdev_ping_container() {
  local container=$1
  docker exec "$container" echo ready &> /dev/null
}

# dockerdev_ensure_dev_user_added <container>
#   Ensure that a non-root user matching the host user has been added to a
#   container. See also `dockerdev_start_new_dev_container`.
dockerdev_ensure_dev_user_added() {
  local container_name=$1
  local userid
  local username
  local groupid
  local groupname
  userid=$(id -u "$USER") &&
  username=$USER &&
  groupid=$(id -g "$USER") &&
  groupname=$(id -gn "$USER") &&
  docker exec -i "$container_name" sh -c "
    if ! id -u $username > /dev/null 2>&1; then
      addgroup --gid $groupid $groupname && \
      adduser --uid $userid --gid $groupid --disabled-password --gecos '' $username
    fi
  "
}

# dockerdev_ensure_dev_stack_container_ready <docker-compose-file> \
#     <stack-name> <service> <image>
#   Ensure that a stack has been deployed and that one of its services has a
#   container that is ready to receive commands. Ensure that the container is
#   running a certain image. The stack, service, and container will be created
#   if they do not already exist, and the image will be updated if necessary.
dockerdev_ensure_dev_stack_container_ready() {
  local compose_file=$1
  local stack=$2
  local service=$3
  local image=$4
  local full_service_name="$stack"_"$service"
  local container
  docker stack deploy -c "$compose_file" --prune "$stack" &&
  dockerdev_ensure_service_image_updated "$full_service_name" "$image" &&
  container=$(dockerdev_get_service_container_name "$full_service_name") &&
  while ! dockerdev_ping_container "$container"; do
    echo "Polling container $container..." &&
    sleep 1
  done &&
  dockerdev_ensure_dev_user_added "$container"
}

# dockerdev_run_in_dev_stack_container <docker-compose-file> <stack-name> \
#     <service> <image> <docker-exec-args>...
#   Ensure that a stack, service, and container have been created as in
#   `dockerdev_ensure_dev_stack_container_ready`, and also run a command in
#   the container.
dockerdev_run_in_dev_stack_container() {
  local stack=$1
  local service=$2
  local image=$3
  shift 3
  local container
  dockerdev_ensure_dev_stack_container_ready "$stack" "$service" "$image" &&
  container=$(get_service_container_name "$stack"_"$service") &&
  dockerdev_exec_dev "$container" "$@"
}
