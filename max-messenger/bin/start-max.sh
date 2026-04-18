#!/usr/bin/env bash

# Получение директории скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="${PROJECT_DIR}/docker"

# Конфигурация
IMAGE="max-messenger:latest"
CONTAINER="max_messenger"
CONFIG_DIR="$HOME/.max"
LOG_DIR="${PROJECT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

mkdir -p "$CONFIG_DIR" "$LOG_DIR"

# Проверка Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker не установлен"
    exit 1
fi

# Проверка образа
if ! sudo docker image inspect "$IMAGE" &> /dev/null; then
    log_error "Образ $IMAGE не найден"
    log_info "Выполните сборку: cd ${DOCKER_DIR} && sudo docker build -t ${IMAGE} ."
    exit 1
fi

log_info "Подготовка окружения для MAX Messenger"

# 1. Очистка старых сессий
if [ "$(sudo docker ps -q -f name=^/${CONTAINER}$)" ]; then
    log_warning "Остановка запущенного контейнера..."
    sudo docker stop "${CONTAINER}" >/dev/null 2>&1
fi

if [ "$(sudo docker ps -aq -f name=^/${CONTAINER}$)" ]; then
    log_warning "Удаление старых ресурсов контейнера..."
    sudo docker rm -f "${CONTAINER}" >/dev/null 2>&1
fi

# 2. Очистка файлов блокировки
if [ -d "$CONFIG_DIR" ]; then
    log_info "Сброс файлов блокировки мессенджера..."
    find "$CONFIG_DIR" -name "SingletonLock" -delete 2>/dev/null
    find "$CONFIG_DIR" -name "*.lock" -delete 2>/dev/null
    find "$CONFIG_DIR" -name "SingletonSocket" -delete 2>/dev/null
    find "$CONFIG_DIR" -name "SingletonCookie" -delete 2>/dev/null
fi

# 3. Принудительное использование X11 (обход Wayland проблем)
log_info "Принудительное использование X11 (обход проблем Wayland)"
export DISPLAY=":0"
DISPLAY_TYPE="x11"

# 4. Настройка прав доступа к X11
if command -v xhost &> /dev/null; then
    xhost + 2>/dev/null
    if [ $? -eq 0 ]; then
        log_success "Права X11 настроены (режим: xhost +)"
    else
        xhost +SI:localuser:root 2>/dev/null
        log_success "Права X11 настроены (режим: localuser:root)"
    fi
else
    log_warning "xhost не установлен"
fi

# Проверка доступности дисплея
if command -v xdpyinfo &> /dev/null; then
    if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
        log_success "Дисплей $DISPLAY доступен"
    else
        log_warning "Дисплей $DISPLAY не доступен, попытка исправить..."
        for d in :0 :1 :2; do
            if xdpyinfo -display "$d" >/dev/null 2>&1; then
                export DISPLAY="$d"
                log_success "Используется дисплей $DISPLAY"
                break
            fi
        done
    fi
fi

# 5. Проверка GPU (NVIDIA или Intel/AMD)
GPU_ARGS=""
GPU_TYPE=""

# Проверка NVIDIA GPU через nvidia-smi
if command -v nvidia-smi &> /dev/null; then
    NVIDIA_GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    if [ -n "$NVIDIA_GPU" ]; then
        GPU_TYPE="nvidia"
        GPU_ARGS="--gpus all"
        log_success "NVIDIA GPU найдена: $NVIDIA_GPU"
        log_success "Аппаратное ускорение NVIDIA будет использовано"
    fi
fi

# Если NVIDIA не найдена, проверяем Intel/AMD через /dev/dri
if [ -z "$GPU_ARGS" ] && [ -e /dev/dri ]; then
    GPU_TYPE="dri"
    GPU_ARGS="--device /dev/dri:/dev/dri"
    log_success "GPU устройства найдены (Intel/AMD)"

    if [ -e /dev/dri/renderD128 ]; then
        log_info "Render устройство: /dev/dri/renderD128"
        GPU_ARGS="$GPU_ARGS --device /dev/dri/renderD128:/dev/dri/renderD128"
    fi
    if [ -e /dev/dri/card0 ]; then
        log_info "Карта: /dev/dri/card0"
    fi
fi

if [ -z "$GPU_ARGS" ]; then
    log_warning "GPU не найдены, запуск без аппаратного ускорения"
fi

# 6. Проверка звука
AUDIO_DEVICES=""
if [ -e /dev/snd ]; then
    AUDIO_DEVICES="--device /dev/snd:/dev/snd"
    log_success "Звуковые устройства найдены"
fi

# 7. Настройка DBus
DBUS_ARGS=()
DBUS_ENV=""
DBUS_SOCKET=""

if [ -e "/run/user/1000/bus" ]; then
    DBUS_SOCKET="/run/user/1000/bus"
    DBUS_ARGS+=(-v "$DBUS_SOCKET:$DBUS_SOCKET:ro")
    DBUS_ENV="unix:path=$DBUS_SOCKET"
    log_success "DBus сокет найден: $DBUS_SOCKET"
elif [ -e "/run/user/$(id -u)/bus" ]; then
    DBUS_SOCKET="/run/user/$(id -u)/bus"
    DBUS_ARGS+=(-v "$DBUS_SOCKET:$DBUS_SOCKET:ro")
    DBUS_ENV="unix:path=$DBUS_SOCKET"
    log_success "DBus сокет найден: $DBUS_SOCKET"
else
    log_warning "DBus сокет не найден"
    DBUS_ENV="autolaunch:"
fi

if [ -n "$DBUS_ENV" ]; then
    DBUS_ARGS+=(-e "DBUS_SESSION_BUS_ADDRESS=$DBUS_ENV")
fi

# 8. Параметры запуска (только X11 режим)
DOCKER_RUN_ARGS=(
    --name "${CONTAINER}"
    --rm
    --security-opt label=disable
    --shm-size=4g
    --net=host
    -e DISPLAY="$DISPLAY"
    -e QT_QPA_PLATFORM="xcb"
    -e QT_X11_NO_MITSHM=1
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw
    -v "$CONFIG_DIR:/home/maxuser/.config/max:rw"
    -v /etc/localtime:/etc/localtime:ro
    -v "$LOG_DIR:/home/maxuser/logs:rw"
    --group-add video
    --group-add audio
)

# Добавляем DBus аргументы
if [ ${#DBUS_ARGS[@]} -gt 0 ]; then
    DOCKER_RUN_ARGS+=("${DBUS_ARGS[@]}")
fi

# Добавляем GPU аргументы
if [ -n "$GPU_ARGS" ]; then
    # Разбиваем GPU_ARGS на отдельные аргументы
    for arg in $GPU_ARGS; do
        DOCKER_RUN_ARGS+=("$arg")
    done
fi

# Добавляем звук если есть
if [ -n "$AUDIO_DEVICES" ]; then
    DOCKER_RUN_ARGS+=(--device /dev/snd:/dev/snd)
fi

# Базовые переменные окружения
DOCKER_RUN_ARGS+=(
    -e LIBGL_ALWAYS_SOFTWARE=0
    -e GDK_BACKEND=x11
    -e NO_AT_BRIDGE=1
    -e ELECTRON_NO_SANDBOX=1
    -e SECRETS_SERVICE_IGNORE=1
)

# Переменные в зависимости от типа GPU
if [ "$GPU_TYPE" = "nvidia" ]; then
    # NVIDIA оптимизации
    DOCKER_RUN_ARGS+=(
        -e NVIDIA_VISIBLE_DEVICES=all
        -e NVIDIA_DRIVER_CAPABILITIES=all
        -e __GLX_VENDOR_LIBRARY_NAME=nvidia
        -e __GL_SYNC_TO_VBLANK=0
        -e __GL_SHADER_DISK_CACHE=1
        -e __GL_YIELD=USLEEP
        -e vblank_mode=0
    )
else
    # Intel/AMD оптимизации
    DOCKER_RUN_ARGS+=(
        -e MESA_GL_VERSION_OVERRIDE=4.5
        -e MESA_GLES_VERSION_OVERRIDE=3.2
        -e __GL_SYNC_TO_VBLANK=0
        -e __GL_SHADER_DISK_CACHE=1
        -e vblank_mode=0
        -e CLUTTER_BACKEND=x11
        -e COGL_DRIVER=gl
    )
fi

# 9. Функция для graceful shutdown
cleanup() {
    log_warning "Получен сигнал завершения, останавливаем контейнер..."
    sudo docker stop "${CONTAINER}" >/dev/null 2>&1
    if command -v xhost &> /dev/null; then
        xhost - 2>/dev/null
    fi
    log_success "Очистка завершена"
    exit 0
}

trap cleanup SIGINT SIGTERM

# 10. Запуск мессенджера
log_info "Запуск MAX Messenger..."
echo "---"

# Логирование запуска
LAUNCH_LOG="$LOG_DIR/launch_$TIMESTAMP.log"
{
    echo "=== MAX Messenger Launch ==="
    echo "Timestamp: $(date)"
    echo "Display type: $DISPLAY_TYPE"
    echo "DISPLAY: $DISPLAY"
    echo "User: $(whoami)"
    echo "UID: $(id -u)"
    echo "Docker image: $IMAGE"
    echo "Config dir: $CONFIG_DIR"
    echo "Log dir: $LOG_DIR"
    echo "DBus socket: ${DBUS_SOCKET:-not found}"
    echo "DBus address: ${DBUS_ENV:-not set}"
    echo "GPU type: ${GPU_TYPE:-none}"
    echo "GPU args: ${GPU_ARGS:-none}"
    echo "Command: sudo docker run ${DOCKER_RUN_ARGS[*]} $IMAGE"
    echo "============================"
} >> "$LAUNCH_LOG"

log_info "Лог запуска: $LAUNCH_LOG"

# Запуск
CONSOLE_LOG="$LOG_DIR/console_$TIMESTAMP.log"
if ! sudo docker run "${DOCKER_RUN_ARGS[@]}" "$IMAGE" 2>&1 | tee -a "$CONSOLE_LOG"; then
    EXIT_CODE=$?
    echo ""
    log_error "MAX Messenger завершился с ошибкой (код: $EXIT_CODE)"

    log_warning "Последние строки лога:"
    tail -20 "$CONSOLE_LOG"

    # Анализ ошибки
    if grep -q "libGL" "$CONSOLE_LOG" 2>/dev/null; then
        log_error "Проблема с OpenGL библиотеками"
        if [ "$GPU_TYPE" = "nvidia" ]; then
            log_info "Проверьте установку NVIDIA драйверов: nvidia-smi"
        else
            log_info "Установите mesa-utils: sudo dnf install mesa-utils"
        fi
    fi

    # Очистка прав
    if command -v xhost &> /dev/null; then
        xhost - 2>/dev/null
    fi

    exit $EXIT_CODE
fi

# Успешное завершение
if command -v xhost &> /dev/null; then
    xhost - 2>/dev/null
fi

log_success "Сессия MAX Messenger завершена"
echo "---"
echo "Логи сохранены в: $LOG_DIR"
