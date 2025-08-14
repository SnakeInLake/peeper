#!/bin/bash
# Указываем, что скрипт должен выполняться с помощью bash.
set -eu
# 'set -e' означает, что скрипт немедленно завершится, если какая-либо команда вернет ошибку.
# 'set -u' означает, что скрипт завершится, если будет использована неопределенная переменная.

# -------------------- ansi escape codes for colors ---------------------------
# Определяем переменные для цветного вывода в консоли для лучшей читаемости.
readonly black='\033[0;30m'
readonly red='\033[0;31m'
readonly green='\033[0;32m'
readonly yellow='\033[0;33m'
readonly blue='\033[0;34m'
readonly magenta='\033[0;35m'
readonly cyan='\033[0;36m'
readonly white='\033[0;37m'
readonly nc='\033[0m' # No Color - сбрасывает цвет к стандартному.
# -------------------- ansi escape codes for colors ---------------------------

# -------------------- environment variables ----------------------------------
# Определяем и экспортируем переменные окружения, которые будут доступны для docker-compose.
export DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
# Получаем GID (ID группы) файла сокета Docker для корректного доступа к Docker API из контейнеров.

# --- НОВОЕ: Интерактивный ввод имени хоста ---
# Получаем системное имя хоста по умолчанию.
default_hostname="$(hostname -s)"
# Запрашиваем у пользователя ввод нового имени, показывая ему значение по умолчанию.
read -p "Enter a user defined host name for [${default_hostname}]: " user_hostname
# Экспортируем переменную HOSTNAME. Если пользователь ничего не ввел (user_hostname пустое),
# то используется значение по умолчанию (default_hostname).
export HOSTNAME="${user_hostname:-${default_hostname}}"
# -------------------- environment variables ----------------------------------

# -------------------- script variables ---------------------------------------
# Определяем переменные, используемые только внутри этого скрипта.
# --- НОВОЕ: Список доступных профилей ("приложений") ---
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
# 'readonly' делает переменную неизменяемой. Здесь создается массив с именами профилей.
readonly no_provision="none"
# Специальное ключевое слово для запуска без подготовки (provisioning).
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
# Текст справки. Часть со списком приложений генерируется динамически
# с помощью цикла 'for', который проходит по массиву 'apps'.
readonly version="0.5"
# -------------------- script variables ---------------------------------------

# -------------------- main ---------------------------------------------------
# Главная функция, точка входа в скрипт.
function main {
  local script_dir="$(dirname "$(readlink -f "$0")")"
  local images_dir="${script_dir}/images"
  local timestamp="$(date --iso-8601=seconds)"

  # Инициализируем переменные-флаги.
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

  # --- ИЗМЕНЕНИЕ: Парсинг опции -i с аргументом ---
  # Двоеточие после 'i' (в "hi:lpsuv") означает, что опция -i требует аргумента.
  while getopts "?hi:lpsuv" opt; do
    case "${opt}" in
      i)
        app="${OPTARG}" # Значение аргумента для -i сохраняется в специальную переменную OPTARG.
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

  # Проверяем флаги и выполняем соответствующие функции.
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
  # --- НОВОЕ: Логика установки с профилями ---
  "${opt_i}" && {
    # Проверяем, есть ли введенное имя приложения в нашем массиве 'apps'.
    # Конструкция " ${apps[*]} " создает строку " eccm elis elph ... "
    # и ищет в ней точное совпадение " ${app} ".
    if [[ " ${apps[*]} " =~ [[:space:]]${app}[[:space:]] ]]; then

      echo -e "${yellow}Peeper started with automatic provision: ${app}.${nc}\n"
      # Копируем все файлы из директории выбранного приложения в директорию 'provisioning'.
      # Это и есть процесс "подготовки" (provisioning) - подкладывание нужных конфигов.
      cp -r "$(pwd)/${app}/"* "$(pwd)/provisioning/"
#      ln -snf "$(pwd)/${app}"/* "$(pwd)/provisioning" # Закомментированная альтернатива: создание символических ссылок вместо копирования.
    # Проверяем, не ввел ли пользователь специальное слово 'none'.
    elif [[ " ${no_provision} " =~ [[:space:]]${app}[[:space:]] ]]; then
      echo -e "${yellow}Peeper started without automatic provision.${nc}\n"
    # Если введено что-то другое, показываем справку.
    else
      usage
    fi
    # Запускаем установку только если проверка прошла успешно.
    install
  }
}
# -------------------- main ---------------------------------------------------

# -------------------- load_images (docker load) ------------------------------
# Функция для загрузки Docker-образов из tar.gz архивов (для оффлайн-установки).
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
# Функция для сохранения Docker-образов в tar.gz архивы (для подготовки к оффлайн-установке).
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

# Функция для полной очистки Docker от неиспользуемых ресурсов.
function docker_prune {
  docker system prune -af --volumes && \
  docker volume prune -af
}

# Функция для установки/запуска приложения.
function install {
  docker compose up \
    --detach \
    --force-recreate \
    --pull always \
    --remove-orphans
}

# Функция для полного удаления приложения.
function uninstall {
  docker compose rm \
    --force \
    --stop \
    --volumes
}

# Функция для вывода справки.
function usage {
  echo -e "${usage}\n"
  exit
}

# Функция для вывода версии.
function version {
  echo -e "${yellow}Peeper version: ${version}.${nc}\n"
}

# Вызываем главную функцию, передавая ей все аргументы ($@),
# с которыми был запущен сам скрипт.
main "$@"
