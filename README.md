dockerdev
=========

This repository contains a collection of bash functions that make it extremely
easy to use Docker containers as local development environments. Using Docker
containers this way keeps the environment in which you develop software both
deterministic and isolated from the rest of your system. It is a much more
powerful form of determinism and isolation than package managers like `npm`
and `pipenv`, which you can still use inside of the container.

You are meant to copy the bash scripts in this repository into your own
software project, write your own scripts that call the helper functions, and
use them as part of your workflow.

The functions defined here automate a lot of the tedium of managing Docker
containers when using them as local development environments. For example,
with a single command you can open a shell inside the container, while
ensuring that that the container has been created, that it is running the
latest image, and that the internals of the container have been configured
correctly.

These scripts are the product of lots of trial and error trying to get a
nice workflow with Docker set up. They have no major dependencies other than
bash and Docker.

Why is this useful?
-------------------

I see Docker, and containers in general, as solving two very important but
distinct problems:

1. Dev and production environments should match
2. Installing the environment necessary to run the app should be automated,
   deterministic, and isolated from the host system
   1. in development
   2. more importantly, in production

This repository is meant to facilitate point 2.i.

Features
--------

* Automatically creates a container based on a Docker image you specify, or
  re-uses a previously-created container with that image to avoid constant
  container refreshing
* If a container contains an older version of the same image, makes sure to
  start a new container with the updated image
* Creates a non-root user inside the container matching your user on the
  host, so that things like `node_modules` and lock files can be written to
  the host with the correct permissions using bind mounts
  * Supported for images based on Ubuntu or Alpine
* Keeping `node_modules` on the host avoids re-installing them every time the
  container image changes
* Fixes the terminal width and height of the shell inside the container
* Supports callbacks that only run when a new container is started, e.g. for
  attaching networks to the container
* Also works for containers that live inside of stacks: given a
  `docker-compose.yml` file, automatically creates a stack, service, and
  container if they do not exist
* If the image of the container in the stack is not up to date, it is
  automatically updated
* If the container in the stack needs to be created or updated, automatically
  waits until the container is ready to run commands before running a command
* Every function is well-documented, and every quirk and workaround is
  commented

Example Usage
-------------

    $ cd /path/to/your/projects/git/repo
    $ mkdir scripts
    $ cd scripts
    $ wget https://raw.githubusercontent.com/bdusell/dockerdev/master/dockerdev.bash
    $ git add .
    $ git commit -m 'Add dockerdev scripts.'
    $ vim shell.bash # Write a script to open a shell in the dev environment
    $ cd ..
    $ bash scripts/shell.bash
    > # Now you're in the container

Complete examples are included under `examples/`.
