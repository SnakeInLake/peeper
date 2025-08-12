#!/bin/bash
set -eu

# -------------------- ansi escape codes for colors ---------------------------
readonly black='\033[0;30m'
readonly red='\033[0;31m'
readonly green='\033[0;32m'
readonly yellow='\033[0;33m'
readonly blue='\033[0;34m'
readonly magenta='\033[0;35m'
readonly cyan='\033[0;36m'
readonly white='\033[0;37m'
readonly nc='\033[0m' # No Color - resets to default
# -------------------- ansi escape codes for colors ---------------------------

# -------------------- environment variables ----------------------------------
export DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"

default_hostname="$(hostname -s)"
read -p "Enter a user defined host name for [${default_hostname}]: " user_hostname
export HOSTNAME="${user_hostname:-${default_hostname}}"
# -------------------- environment variables ----------------------------------

# -------------------- script variables ---------------------------------------
readonly apps=(
  "eccm"
  "elis"
  "elph"
  "evi"
  "naice"
  "softswitch"
  "softwlc"
  "my-first-app"
)
readonly no_provision="none"
readonly usage="
Usage: $(basename "$0") [OPTIONS]

Options:
  -?,-h     print help
  -i <app>  install peeper with automatic provision,
              apps:
$(for app in ${apps[@]}; do echo -e "\t\t${app}"; done)
  -i none   install peeper without automatic provision
  -l        load standalone docker images (offline)
  -p        make docker prune
  -s        save standalone docker images (offline)
  -u        uninstall peeper
  -v        print current version

Multiple options can be used, for example -ui will reinstall peeper."
readonly version="0.5"
# -------------------- script variables ---------------------------------------

# -------------------- main ---------------------------------------------------
function main {
  local script_dir="$(dirname "$(readlink -f "$0")")"
  local images_dir="${script_dir}/images"

  local timestamp="$(date --iso-8601=seconds)"

  # Default values:
  local opt_i=false
  local opt_l=false
  local opt_p=false
  local opt_s=false
  local opt_u=false
  local opt_v=false

  echo -e "Hostname: ${HOSTNAME}"
  echo -e "Script directory: ${script_dir}"
  echo -e "Timestamp: ${timestamp}\n"

  if [ $# -lt 1 ]; then
    usage
  fi

  while getopts "?hi:lpsuv" opt; do
    case "${opt}" in
      i)
        app="${OPTARG}"
        opt_i=true
        ;;
      l)
        opt_l=true
        ;;
      p)
        opt_p=true
        ;;
      s)
        opt_s=true
        ;;
      u)
        opt_u=true
        ;;
      v)
        opt_v=true
        ;;
      *)
        usage
        ;;
    esac
  done

  shift "$(( OPTIND - 1 ))"

  "${opt_v}" && {
    version
  }
  "${opt_l}" && {
    load_images "Peeper" "images"
    exit
  }
  "${opt_s}" && {
    save_images "Peeper" "--file compose.yaml --env-file .env" "images"
    exit
  }
  "${opt_u}" && {
    uninstall
    "${opt_p}" && {
      docker_prune
    }
  }
  "${opt_i}" && {
    if [[ " ${apps[*]} " =~ [[:space:]]${app}[[:space:]] ]]; then

      echo -e "${yellow}Peeper started with automatic provision: ${app}.${nc}\n"
      cp -r "$(pwd)/${app}/"* "$(pwd)/provisioning/"
#      ln -snf "$(pwd)/${app}"/* "$(pwd)/provisioning"
    elif [[ " ${no_provision} " =~ [[:space:]]${app}[[:space:]] ]]; then
      echo -e "${yellow}Peeper started without automatic provision.${nc}\n"
    else
      usage
    fi
    install
  }
}
# -------------------- main ---------------------------------------------------

# -------------------- load_images (docker load) ------------------------------
function load_images {
  if [[ "$#" -eq 2 ]]; then
    local app="$1"
    local images_dir="$2"
    if [[ ! -d "${images_dir}" ]]; then
      echo -e "${yellow}Warning: ${images_dir} does not exist. Skipping...${nc}"
      return
    fi
    for image_file in ${images_dir}/*.tar.gz; do
      echo -en "Loading ${white}${app}${nc} image from ${cyan}${image_file}${nc} ... "
      docker load --input "${image_file}" --quiet > /dev/null
      echo -e "${white}done${nc}"
    done
  else
    echo -e "${red}Error: the number of \"load_images\" arguments is not equal 2.${nc}"
    exit 1
  fi
}
# -------------------- load_images (docker load) ------------------------------

# -------------------- save_images (docker save) ------------------------------
function save_images {
  if [ "$#" -eq 3 ]; then
    local app="$1"
    local compose="$2"
    local images_dir="$3"
    mkdir --parents "${images_dir}"
    for image in $(docker compose ${compose} config --images); do
      echo -en "Saving ${white}${app}${nc} image ${cyan}${image}${nc} to ${cyan}${images_dir}${nc} ... "
      local image_file="$(echo "${image##*/}" | tr ':' '-').tar.gz"
      docker save "${image}" | gzip -f > "${images_dir}/${image_file}"
      echo -e "${white}done${nc}"
    done
  else
    echo -e "${red}Error: the number of \"save_images\" arguments is not equal 3.${nc}"
    exit 1
  fi
}
# -------------------- save_images (docker save) ------------------------------

function docker_prune {
  docker system prune -af --volumes && \
  docker volume prune -af
}

function install {
  docker compose up \
    --detach \
    --force-recreate \
    --pull always \
    --remove-orphans
}

function uninstall {
  docker compose rm \
    --force \
    --stop \
    --volumes
}

function usage {
  echo -e "${usage}\n"
  exit
}

function version {
  echo -e "${yellow}Peeper version: ${version}.${nc}\n"
}

main "$@"
