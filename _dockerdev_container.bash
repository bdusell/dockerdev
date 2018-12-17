# This file defines functions for managing Docker containers that are meant
# to serve as local development environments.
#
# You should source this file in another bash script like so:
#
#     . _dockerdev_container.bash
#
# Typically the source code of your application will be bind-mounted into the
# container so that you have write access to the source code from within the
# container (which is useful for things like lock files).
#
# You will mainly be interested in these functions:
# * dockerdev_ensure_dev_container_started
# * dockerdev_ensure_dev_container_started_callback
# * dockerdev_run_in_dev_container

DOCKERDEV_VERSION='0.2.0'

# dockerdev_container_info <container-name>
#   Get the image name and status of a container.
dockerdev_container_info() {
  local container_name=$1
  # The ^/ ... $ syntax is necessary to get an exact match. This does not
  # appear to be documented anywhere.
  # See https://forums.docker.com/t/how-to-filter-docker-ps-by-exact-name/2880
  docker ps -a -f name="^/$container_name\$" --format '{{.Image}} {{.Status}}'
}

# dockerdev_start_new_container <container-name> <image-name> \
#     [<docker-run-flags>...]
#   Start a new container with a certain image.
dockerdev_start_new_container() {
  local container_name=$1
  local image_name=$2
  shift 2
  echo 'Starting new container' &&
  docker run -d "$@" --name "$container_name" "$image_name"
}

# dockerdev_start_new_dev_container <container-name> <image-name> \
#     [<docker-run-flags>...]
#   Start a new container with a certain image and set up a non-root user.
dockerdev_start_new_dev_container() {
  local container_name=$1
  local image_name=$2
  shift 2
  local userid
  local username
  local groupid
  local groupname
  userid=$(id -u "$USER") &&
  username=$USER &&
  groupid=$(id -g "$USER") &&
  groupname=$(id -gn "$USER") &&
  dockerdev_start_new_container "$container_name" "$image_name" -it "$@" &&
  # Add a user matching the user on the host system, so we can write files as
  # the same (non-root) user as the host. This allows to do things like write
  # node_modules and lock files into a bind-mounted volume with the correct
  # permissions.
  # NOTE: The addgroup and adduser commands are not portable across
  # distributions, but they automatically set up a home directory, and some
  # tools balk if there is no home directory.
  # Use `-u 0:0` to make sure we run as root.
  docker exec -i -u 0:0 "$container_name" sh -c "
    if addgroup --help 2>&1 | grep -i busybox > /dev/null; then
      addgroup -g $groupid $groupname && \
      adduser -u $userid -G $groupname -D -g '' $username
    elif addgroup --version 2>&1 | grep -i ubuntu > /dev/null; then
      addgroup --gid $groupid $groupname && \
      adduser --uid $userid --gid $groupid --disabled-password --gecos '' $username
    else
      echo 'error: Could not figure out how to add a new user.'
      false
    fi
  "
}

# dockerdev_ensure_container_started <image-name> [<docker-run-flags>...]
#   Start a container with a certain image if it is not already running.
dockerdev_ensure_container_started() {
  dockerdev_ensure_container_started_callback : "$@"
}

# dockerdev_ensure_container_started_callback <image-name> <function-name> \
#     [<docker-run-flags>...]
#   Like `dockerdev_ensure_container_started`, but accepts the name of a
#   command to be called just after the container is started. It will not be
#   called if the container is already running.
dockerdev_ensure_container_started_callback() {
  _dockerdev_ensure_container_started_impl dockerdev_start_new_container "$@"
}

# dockerdev_ensure_dev_container_started <image-name> \
#     [<docker-run-flags>...]
#   Start a container with a certain image if it is not already running, and
#   ensure that the container has a user that can write to the host system as
#   a non-root user, which is useful when using package manager tools like NPM
#   and Composer from inside the container. This is the function you should
#   use to create a container for your development environment.
dockerdev_ensure_dev_container_started() {
  dockerdev_ensure_dev_container_started_callback : "$@"
}

# dockerdev_ensure_dev_container_started_callback <image-name> \
#     <function-name> [<docker-run-flags>...]
#   Like `dockerdev_ensure_dev_container_started`, but accepts the name of a
#   command to be called just after the container is started. It will not be
#   called if the container is already running.
dockerdev_ensure_dev_container_started_callback() {
  _dockerdev_ensure_container_started_impl dockerdev_start_new_dev_container "$@"
}

_dockerdev_ensure_container_started_impl() {
  local start_container_cmd=$1
  local on_start_cmd=$2
  local image_name=$3
  local container_name=$image_name
  shift 3
  local info
  info=$(dockerdev_container_info "$container_name") &&
  if [[ $info =~ ^([^ ]+)\ (.+)$ ]]; then
    # A container with the right name exists.
    local container_image=${BASH_REMATCH[1]}
    local container_status=${BASH_REMATCH[2]}
    echo "Found container $container_name"
    echo "  Image:  $container_image"
    echo "  Status: $container_status"
    if [[ $container_image = $image_name ]]; then
      # The container is running the correct image.
      if [[ $container_status =~ ^Up\  ]]; then
        # The container is running.
        echo "Container $container_name is already running"
      else
        # The container needs to be started.
        echo "Starting container $container_name"
        docker start "$container_name"
      fi
    else
      # The container is running a different image (i.e. one that is out of
      # date).
      local new_name="${container_name}_${container_image}"
      # The existing container needs to be stopped because it is most likely
      # bound to the same port we need.
      echo "Stopping container $container_name" &&
      docker stop "$container_name" &&
      echo "Renaming container $container_name to $new_name" &&
      docker rename "$container_name" "$new_name" &&
      $start_container_cmd "$image_name" "$container_name" "$@" &&
      $on_start_cmd "$container_name"
    fi
  else
    # No container with the expected name exists.
    $start_container_cmd "$image_name" "$container_name" "$@" &&
    $on_start_cmd "$container_name"
  fi
}

# dockerdev_run_in_container <docker-exec-args>...
#   Run a command in a container.
dockerdev_run_in_container() {
  local cols
  local lines
  # COLUMNS and LINES fix an issue with terminal width.
  # See https://github.com/moby/moby/issues/33794
  cols=$(tput cols) &&
  lines=$(tput lines) &&
  docker exec -it -e COLUMNS="$cols" -e LINES="$lines" "$@"
}

# dockerdev_run_in_dev_container <docker-exec-args>...
#   Run a command in a container as the same user as the host user.
dockerdev_run_in_dev_container() {
  local userid
  local groupid
  userid=$(id -u "$USER") &&
  groupid=$(id -g "$USER") &&
  # -u lets us execute the command as the host user.
  dockerdev_run_in_container -u "$userid:$groupid" "$@"
}
