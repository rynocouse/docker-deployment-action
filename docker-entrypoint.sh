#!/bin/sh
set -eu

execute_ssh(){
  echo "Execute Over SSH: $@"
  ssh -q -t -i "$HOME/.ssh/id_rsa" \
      -o UserKnownHostsFile=/dev/null \
      -o StrictHostKeyChecking=no "$INPUT_REMOTE_DOCKER_HOST" "$@"
}

if [ -z "$INPUT_REMOTE_DOCKER_HOST" ]; then
    echo "Input remote_docker_host is required!"
    exit 1
fi

if [ -z "$INPUT_SSH_PUBLIC_KEY" ]; then
    echo "Input ssh_public_key is required!"
    exit 1
fi

if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
    echo "Input ssh_private_key is required!"
    exit 1
fi

if [ -z "$INPUT_PROJECT_NAME" ]; then
    echo "Input project_name is required!"
    exit 1
fi

if [ -z "$INPUT_STACK_FILE_NAME" ]; then
  INPUT_STACK_FILE_NAME=docker-compose.yaml
fi

STACK_FILE=${INPUT_STACK_FILE_NAME}
DEPLOYMENT_COMMAND_OPTIONS=""

SSH_HOST=${INPUT_REMOTE_DOCKER_HOST#*@}

echo "Registering SSH keys..."

# register the private key with the agent.
mkdir -p "$HOME/.ssh"
printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > "$HOME/.ssh/id_rsa"
chmod 600 "$HOME/.ssh/id_rsa"
eval $(ssh-agent)
ssh-add "$HOME/.ssh/id_rsa"

echo "Add known hosts"
printf '%s %s\n' "$SSH_HOST" "$INPUT_SSH_PUBLIC_KEY" > /etc/ssh/ssh_known_hosts

if ! [ -z "$INPUT_DOCKER_PRUNE" ] && [ $INPUT_DOCKER_PRUNE = 'true' ] ; then
  yes | docker --log-level debug --host "ssh://$INPUT_REMOTE_DOCKER_HOST" system prune -a 2>&1
fi
  
echo "Connecting to $INPUT_REMOTE_DOCKER_HOST... Command: docker-compose --log-level debug --host ssh://$INPUT_REMOTE_DOCKER_HOST -f $STACK_FILE pull --ignore-pull-failures"
DOCKER_HOST="tcp://127.0.0.1:2375" docker-compose --log-level debug --host ssh://$INPUT_REMOTE_DOCKER_HOST -f $STACK_FILE pull --ignore-pull-failures 2>&1

echo "Connecting to $INPUT_REMOTE_DOCKER_HOST... Command: docker-compose -p ${INPUT_PROJECT_NAME} --log-level debug --host ssh://$INPUT_REMOTE_DOCKER_HOST -f $STACK_FILE up -d"
DOCKER_HOST="tcp://127.0.0.1:2375" docker-compose -p ${INPUT_PROJECT_NAME} --log-level debug --host ssh://$INPUT_REMOTE_DOCKER_HOST -f $STACK_FILE up -d 2>&1

