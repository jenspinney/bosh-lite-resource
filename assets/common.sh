export TMPDIR=${TMPDIR:-/tmp}
export GIT_CRYPT_KEY_PATH=~/git-crypt.key

load_pubkey() {
  local private_key_path=$TMPDIR/git-resource-private-key

  (jq -r '.source.private_key // empty' < $1) > $private_key_path

  if [ -s $private_key_path ]; then
    chmod 0600 $private_key_path

    eval $(ssh-agent) >/dev/null 2>&1
    trap "kill $SSH_AGENT_PID" 0

    SSH_ASKPASS=$(dirname $0)/askpass.sh DISPLAY= ssh-add $private_key_path >/dev/null

    mkdir -p ~/.ssh
    cat > ~/.ssh/config <<EOF
StrictHostKeyChecking no
LogLevel quiet
EOF
    chmod 0600 ~/.ssh/config
  fi
}

configure_git_global() {
  local git_config_payload="$1"
  eval $(echo "$git_config_payload" | \
    jq -r ".[] | \"git config --global '\\(.name)' '\\(.value)'; \"")
}

add_git_metadata_basic() {
  local commit=$(git rev-parse HEAD | jq -R .)
  local author=$(git log -1 --format=format:%an | jq -s -R .)
  local author_date=$(git log -1 --format=format:%ai | jq -R .)

  jq ". + [
    {name: \"commit\", value: ${commit}},
    {name: \"author\", value: ${author}},
    {name: \"author_date\", value: ${author_date}, type: \"time\"}
  ]"
}

add_git_metadata_committer() {
  local author=$(git log -1 --format=format:%an | jq -s -R .)
  local author_date=$(git log -1 --format=format:%ai | jq -R .)
  local committer=$(git log -1 --format=format:%cn | jq -s -R .)
  local committer_date=$(git log -1 --format=format:%ci | jq -R .)

  if [ "$author" = "$committer" ] && [ "$author_date" = "$committer_date" ]; then
    jq ". + [
      {name: \"committer\", value: ${committer}},
      {name: \"committer_date\", value: ${committer_date}, type: \"time\"}
    ]"
  else
    cat
  fi
}

add_git_metadata_branch() {
  local branch=$(git show-ref --heads | \
    sed -n "s/^$(git rev-parse HEAD) refs\/heads\/\(.*\)/\1/p" |  \
    jq -R  ". | select(. != \"\")" | jq -r -s "map(.) | join (\",\")")

  if [ -n "${branch}" ]; then
    jq ". + [
      {name: \"branch\", value: \"${branch}\"}
    ]"
  else
    cat
  fi
}

add_git_metadata_tags() {
  local tags=$(git tag --points-at HEAD | \
    jq -R  ". | select(. != \"\")" | \
    jq -r -s "map(.) | join(\",\")")

  if [ -n "${tags}" ]; then
    jq ". + [
      {name: \"tags\", value: \"${tags}\"}
    ]"
  else
    cat
  fi
}

add_git_metadata_message() {
  local message=$(git log -1 --format=format:%B | jq -s -R .)

  jq ". + [
    {name: \"message\", value: ${message}, type: \"message\"}
  ]"
}

git_metadata() {
  jq -n "[]" | \
    add_git_metadata_basic | \
    add_git_metadata_committer | \
    add_git_metadata_branch | \
    add_git_metadata_tags | \
    add_git_metadata_message
}

load_git_crypt_key() {
  local git_crypt_tmp_key_path=$TMPDIR/git-resource-git-crypt-key

  (jq -r '.source.git_crypt_key // empty' < $1) > $git_crypt_tmp_key_path

  if [ -s $git_crypt_tmp_key_path ]; then
      cat $git_crypt_tmp_key_path | tr ' ' '\n' | base64 -d > $GIT_CRYPT_KEY_PATH
  fi
}