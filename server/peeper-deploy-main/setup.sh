#!/bin/bash
# Указываем, что скрипт должен выполняться с помощью bash.
set -eu
# 'set -e' означает, что скрипт немедленно завершится, если какая-либо команда вернет ошибку.
# 'set -u' означает, что скрипт завершится, если будет использована неопределенная переменная.
# Это хорошие практики для написания надежных скриптов.

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
# Получаем GID (ID группы) файла сокета Docker. Это нужно, чтобы передать его в контейнеры
# для корректного доступа к Docker API (например, для Telegraf или VictoriaMetrics).
export HOSTNAME="$(hostname -s)"
# Получаем короткое имя хост-машины (без домена). Будет использоваться как переменная
# окружения для контейнеров, чтобы они знали, на каком хосте запущены.
# -------------------- environment variables ----------------------------------

# -------------------- script variables ---------------------------------------
# Определяем переменные, используемые только внутри этого скрипта.
readonly usage="
Usage: $(basename "$0") [OPTIONS]

Options:
  -?,-h     print help
  -i        install peeper
  -l        load standalone docker images (offline)
  -p        make docker prune
  -s        save standalone docker images (offline)
  -u        uninstall peeper
  -v        print current version

Multiple options can be used, for example -ui will reinstall peeper."
# 'usage' — это многострочная переменная, которая хранит текст справки по использованию скрипта.
readonly version="0.5"
# 'version' — переменная для хранения версии скрипта.
# -------------------- script variables ---------------------------------------

# -------------------- main ---------------------------------------------------
# Главная функция, точка входа в скрипт, которая управляет всей логикой.
function main {
  # Определяем директорию, в которой находится сам скрипт.
  local script_dir="$(dirname "$(readlink -f "$0")")"
  # Задаем путь к папке с образами для оффлайн-установки.
  local images_dir="${script_dir}/images"

  # Фиксируем время запуска.
  local timestamp="$(date --iso-8601=seconds)"

  # Инициализируем переменные-флаги для опций. По умолчанию все выключены (false).
  local opt_i=false
  local opt_l=false
  local opt_p=false
  local opt_s=false
  local opt_u=false
  local opt_v=false

  echo -e "Script directory: ${script_dir}"
  echo -e "Timestamp: ${timestamp}\n"

  # Если скрипт запущен без аргументов, показать справку и выйти.
  if [ $# -lt 1 ]; then
    usage
  fi

  # Запускаем цикл для парсинга опций командной строки (например, -i, -u, -p).
  while getopts "?hilpsuv" opt; do
    # Внутри цикла, в зависимости от найденной опции, устанавливаем соответствующий флаг в 'true'.
    case "${opt}" in
      i)
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

  # Сдвигаем позиционные параметры, чтобы убрать уже обработанные опции.
  shift "$(( OPTIND - 1 ))"

  # Проверяем флаги и выполняем соответствующие функции.
  # Конструкция "${flag}" && { command } — это короткая запись для "if [ "$flag" = true ]; then command; fi".
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
    # Если флаг -p был использован вместе с -u, то после удаления выполнить очистку.
    "${opt_p}" && {
      docker_prune
    }
  }
  "${opt_i}" && {
    install
  }
}
# -------------------- main ---------------------------------------------------

# -------------------- load_images (docker load) ------------------------------
# Функция для загрузки Docker-образов из tar.gz архивов (для оффлайн-установки).
function load_images {
  # Проверяем, что функции передано ровно 2 аргумента.
  if [[ "$#" -eq 2 ]]; then
    local app="$1"
    local images_dir="$2"
    # Если директория с образами не существует, выводим предупреждение и выходим из функции.
    if [[ ! -d "${images_dir}" ]]; then
      echo -e "${yellow}Warning: ${images_dir} does not exist. Skipping...${nc}"
      return
    fi
    # В цикле проходим по всем файлам *.tar.gz в указанной директории.
    for image_file in ${images_dir}/*.tar.gz; do
      echo -en "Loading ${white}${app}${nc} image from ${cyan}${image_file}${nc} ... "
      # Загружаем образ в Docker. '--quiet' подавляет лишний вывод.
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
    # Создаем директорию для образов, если она не существует.
    mkdir --parents "${images_dir}"
    # Получаем список всех образов, используемых в compose.yaml.
    for image in $(docker compose ${compose} config --images); do
      echo -en "Saving ${white}${app}${nc} image ${cyan}${image}${nc} to ${cyan}${images_dir}${nc} ... "
      # Генерируем имя файла из имени образа, заменяя ':' на '-'.
      local image_file="$(echo "${image##*/}" | tr ':' '-').tar.gz"
      # Сохраняем образ и сразу же сжимаем его с помощью gzip.
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
# ВНИМАНИЕ: Эта команда удаляет ВСЕ неиспользуемые контейнеры, образы и тома,
# а не только те, что относятся к этому проекту.
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
    # Использует 'docker compose up' с набором "правильных" флагов:
    # --detach: фоновый режим.
    # --force-recreate: всегда пересоздавать контейнеры.
    # --pull always: всегда пытаться скачать свежие версии образов.
    # --remove-orphans: удалять "осиротевшие" контейнеры.
}

# Функция для полного удаления приложения.
function uninstall {
  docker compose rm \
    --force \
    --stop \
    --volumes
    # Использует 'docker compose rm' (в новых версиях это 'down'), чтобы:
    # --force: не задавать вопросов.
    # --stop: остановить контейнеры перед удалением.
    # --volumes: удалить и связанные с ними тома (данные).
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
