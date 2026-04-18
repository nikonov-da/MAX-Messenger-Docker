# 📱 Полная инструкция по развёртыванию MAX Messenger в Docker

## 📋 Содержание

1. [Требования к системе](#требования-к-системе)
2. [Установка Docker](#установка-docker)
3. [Установка NVIDIA Container Toolkit](#установка-nvidia-container-toolkit)
4. [Структура проекта](#структура-проекта)
5. [Создание Dockerfile](#создание-dockerfile)
6. [Создание скриптов](#создание-скриптов)
7. [Сборка Docker образа](#сборка-docker-образа)
8. [Настройка окружения](#настройка-окружения)
9. [Создание десктопных ярлыков](#создание-десктопных-ярлыков)
10. [Запуск мессенджера](#запуск-мессенджера)
11. [Диагностика и отладка](#диагностика-и-отладка)
12. [Устранение неполадок](#устранение-неполадок)
13. [Скрипты восстановления](#скрипты-восстановления)

---

## Требования к системе

### Минимальные требования
- **ОС**: Fedora 38+, Ubuntu 24.04/26.04
- **Docker**: версия 20.10+
- **ОЗУ**: 4 ГБ (рекомендуется 8 ГБ)
- **GPU**: NVIDIA (рекомендуется) с драйверами 550+
- **Интернет**: для скачивания образов

### Проверка системы
```bash
# Проверка версии ОС
cat /etc/os-release

# Проверка архитектуры
uname -m

# Проверка свободного места
df -h /
```

---

## Установка Docker

### Fedora Linux

```bash
# 1. Удаление старых версий
sudo dnf remove docker docker-client docker-client-latest docker-common \
    docker-latest docker-latest-logrotate docker-logrotate docker-engine

# 2. Установка репозитория Docker
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

# 3. Установка Docker
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 4. Запуск Docker
sudo systemctl start docker
sudo systemctl enable docker

# 5. Добавление пользователя в группу docker
sudo usermod -aG docker $USER

# 6. Перезагрузка сессии
newgrp docker

# 7. Проверка
docker --version
docker run hello-world
```

### Ubuntu 24.04/26.04

```bash
# 1. Обновление системы
sudo apt update && sudo apt upgrade -y

# 2. Установка зависимостей
sudo apt install -y ca-certificates curl gnupg lsb-release

# 3. Добавление GPG ключа Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 4. Добавление репозитория
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Установка Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. Запуск Docker
sudo systemctl start docker
sudo systemctl enable docker

# 7. Добавление пользователя в группу docker
sudo usermod -aG docker $USER
newgrp docker

# 8. Проверка
docker --version
docker run hello-world
```

---

## Установка NVIDIA Container Toolkit

### Для Fedora Linux

```bash
# 1. Добавление репозитория
curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
  sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo

# 2. Установка пакетов
sudo dnf install -y nvidia-container-toolkit libnvidia-container1

# 3. Настройка Docker
sudo nvidia-ctk runtime configure --runtime=docker

# 4. Перезапуск Docker
sudo systemctl restart docker

# 5. Проверка
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

### Для Ubuntu 24.04/26.04

```bash
# 1. Добавление репозитория
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# 2. Добавление репозитория для Ubuntu
echo "deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# 3. Установка
sudo apt update
sudo apt install -y nvidia-container-toolkit

# 4. Настройка Docker
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# 5. Проверка
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

---

## Структура проекта

```
/home/denis/max-messenger/
├── bin/
│   ├── start-max.sh              # Основной скрипт запуска
│   ├── max-debug.sh              # Диагностический инструмент
│   ├── fix-after-reboot.sh       # Восстановление окружения
│   ├── create-desktop-entries.sh # Создание ярлыков
│   ├── MAX-1024x1024.png         # Иконка приложения
│   ├── MAX-DEBUG-TOOL.png        # Иконка отладки
│   └── MAX-FIX-TOOL.png          # Иконка восстановления
├── docker/
│   └── Dockerfile                # Docker образ
└── logs/                         # Логи запусков
```

### Создание структуры

```bash
mkdir -p ~/max-messenger/{bin,docker,logs}
cd ~/max-messenger
```

---

## Создание Dockerfile

Создайте файл `~/max-messenger/docker/Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1
FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=ru_RU.UTF-8 \
    LANG=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru

# 1. Базовый слой
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg2 \
    locales \
    dbus \
    dbus-x11 \
    gnome-keyring \
    libpam-gnome-keyring \
    && locale-gen ru_RU.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 2. Репозиторий MAX
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.max.ru/linux/deb/public.asc | gpg --dearmor -o /etc/apt/keyrings/max.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/max.gpg] https://download.max.ru/linux/deb stable main" \
    > /etc/apt/sources.list.d/max.list

# 3. Основные зависимости
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    max \
    mesa-utils \
    libgl1-mesa-dri \
    libglx-mesa0 \
    libegl-mesa0 \
    libglx0 \
    libegl1 \
    libgl1 \
    libva2 \
    libva-drm2 \
    libva-x11-2 \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    libvulkan1 \
    mesa-vulkan-drivers \
    vulkan-tools \
    libgbm1 \
    libwayland-client0 \
    libwayland-egl1 \
    libdrm2 \
    libxcb-cursor0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-render-util0 \
    libxcb-xinerama0 \
    libxcb-xinput0 \
    libxcb-shape0 \
    libxkbcommon-x11-0 \
    libgtk-3-0 \
    libpango-1.0-0 \
    libcairo2 \
    libfontconfig1 \
    fonts-liberation \
    libnss3 \
    libasound2t64 \
    libpulse0 \
    libdbus-1-3 \
    libsecret-1-0 \
    libpci3 \
    libxtst6 \
    libxss1 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2t64 \
    libxkbfile1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libx11-xcb1 \
    libpipewire-0.3-0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 4. Скрипт запуска
RUN printf '#!/bin/bash\n\
USER_ID=${HOST_UID:-1000}\n\
USER_NAME=${HOST_USER:-maxuser}\n\
\n\
if ! id -u "$USER_ID" >/dev/null 2>&1; then\n\
    useradd -u "$USER_ID" -m -s /bin/bash "$USER_NAME" 2>/dev/null\n\
fi\n\
\n\
USER_NAME=$(id -nu "$USER_ID" 2>/dev/null || echo "$USER_NAME")\n\
mkdir -p /run/user/"$USER_ID"\n\
chown "$USER_NAME" /run/user/"$USER_ID"\n\
\n\
export LIBGL_ALWAYS_SOFTWARE=0\n\
export MESA_GL_VERSION_OVERRIDE=4.5\n\
export MESA_GLES_VERSION_OVERRIDE=3.2\n\
export __GL_SYNC_TO_VBLANK=0\n\
export __GL_SHADER_DISK_CACHE=1\n\
export vblank_mode=0\n\
\n\
su -c "dbus-launch --exit-with-session \\\n\
    gnome-keyring-daemon --start --components=secrets \\\n\
    && export GNOME_KEYRING_CONTROL \\\n\
    && export SSH_AUTH_SOCK \\\n\
    && /usr/bin/max --no-sandbox $*" "$USER_NAME"\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

# 5. Настройка окружения
ENV QT_QPA_PLATFORM=xcb \
    QT_X11_NO_MITSHM=1 \
    LIBGL_ALWAYS_SOFTWARE=0 \
    ELECTRON_NO_SANDBOX=1 \
    NO_AT_BRIDGE=1 \
    SECRETS_SERVICE_IGNORE=1 \
    MESA_GL_VERSION_OVERRIDE=4.5 \
    MESA_GLES_VERSION_OVERRIDE=3.2 \
    __GL_SYNC_TO_VBLANK=0 \
    __GL_SHADER_DISK_CACHE=1 \
    vblank_mode=0

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--use-gl=egl"]
```

---

## Создание скриптов

### 1. Основной скрипт запуска `start-max.sh`

Создайте файл `~/max-messenger/bin/start-max.sh` (полный код из вашего сообщения).

### 2. Диагностический скрипт `max-debug.sh`

Создайте файл `~/max-messenger/bin/max-debug.sh` (полный код из вашего сообщения).

### 3. Скрипт восстановления `fix-after-reboot.sh`

Создайте файл `~/max-messenger/bin/fix-after-reboot.sh` (полный код из вашего сообщения).

### 4. Скрипт создания ярлыков `create-desktop-entries.sh`

```bash
#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$HOME/.local/share/applications"

mkdir -p "$DESKTOP_DIR"

# Ярлык для MAX Messenger
cat > "$DESKTOP_DIR/max-messenger.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=MAX Messenger
GenericName=Messenger
Comment=Запуск мессенджера MAX в Docker
Exec=${SCRIPT_DIR}/start-max.sh
Icon=${SCRIPT_DIR}/MAX-1024x1024.png
Terminal=false
StartupNotify=true
Categories=Network;Chat;InstantMessaging;
Keywords=Messenger;MAX;
EOF

# Ярлык для Debug Tool
cat > "$DESKTOP_DIR/max-debug-tool.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=MAX Debug Tool
Comment=Диагностика MAX Messenger
Exec=${SCRIPT_DIR}/max-debug.sh
Icon=${SCRIPT_DIR}/MAX-DEBUG-TOOL.png
Terminal=true
Categories=Development;Debugger;
EOF

# Ярлык для Fix Tool
cat > "$DESKTOP_DIR/max-fix-tool.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=MAX Fix Tool
Comment=Восстановление окружения MAX Messenger
Exec=${SCRIPT_DIR}/fix-after-reboot.sh
Icon=${SCRIPT_DIR}/MAX-FIX-TOOL.png
Terminal=true
Categories=System;Utility;
EOF

update-desktop-database "$DESKTOP_DIR" 2>/dev/null
chmod +x "$DESKTOP_DIR"/*.desktop

echo "✓ Десктопные ярлыки созданы"
```

### Установка прав

```bash
chmod +x ~/max-messenger/bin/*.sh
```

---

## Сборка Docker образа

```bash
cd ~/max-messenger/docker

# Сборка образа
docker build --no-cache -t max-messenger:latest .

# Проверка
docker images | grep max-messenger
```

**Ожидаемый вывод:**
```
max-messenger   latest    [hash]    1.5GB
```

---

## Настройка окружения

### Для Fedora

```bash
# Установка пакетов
sudo dnf install -y xorg-x11-server-utils mesa-demos gnome-keyring

# Настройка X11
xhost +

# Добавление переменных
cat >> ~/.profile << 'EOF'

# MAX Messenger GPU settings
export LIBGL_ALWAYS_SOFTWARE=0
export MESA_GL_VERSION_OVERRIDE=4.5
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export NVIDIA_VISIBLE_DEVICES=all
EOF

source ~/.profile
```

### Для Ubuntu

```bash
# Установка пакетов
sudo apt install -y x11-xserver-utils mesa-utils gnome-keyring

# Настройка X11
xhost +

# Добавление переменных
cat >> ~/.profile << 'EOF'

# MAX Messenger GPU settings
export LIBGL_ALWAYS_SOFTWARE=0
export MESA_GL_VERSION_OVERRIDE=4.5
export NVIDIA_VISIBLE_DEVICES=all
EOF

source ~/.profile
```

---

## Создание десктопных ярлыков

```bash
# Запуск скрипта
~/max-messenger/bin/create-desktop-entries.sh

# Проверка
ls -la ~/.local/share/applications/max-*.desktop
```

### Добавление в автозагрузку Fix Tool

```bash
cp ~/.local/share/applications/max-fix-tool.desktop ~/.config/autostart/
```

---

## Запуск мессенджера

### Из терминала

```bash
# Обычный запуск
~/max-messenger/bin/start-max.sh

# Создание алиаса
echo "alias max='~/max-messenger/bin/start-max.sh'" >> ~/.bashrc
echo "alias max-debug='~/max-messenger/bin/max-debug.sh'" >> ~/.bashrc
echo "alias max-fix='~/max-messenger/bin/fix-after-reboot.sh'" >> ~/.bashrc
source ~/.bashrc

# Теперь можно запускать
max
```

### Из меню приложений

1. Откройте меню приложений (Super ключ)
2. Найдите "MAX Messenger"
3. Нажмите для запуска

---

## Диагностика и отладка

### Быстрая диагностика

```bash
max-debug
```

### Проверка GPU

```bash
# Проверка NVIDIA GPU
nvidia-smi

# Проверка OpenGL
glxinfo | grep "OpenGL renderer"

# Проверка GPU в Docker
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

### Просмотр логов

```bash
# Последние логи
tail -f ~/max-messenger/logs/console_*.log

# Поиск ошибок
grep -i error ~/max-messenger/logs/console_*.log

# Логи запуска
cat ~/max-messenger/logs/launch_*.log
```

---

## Скрипты восстановления

### fix-after-reboot.sh

Запускается после перезагрузки для восстановления окружения:

```bash
max-fix
```

Что делает:
- Настраивает права X11
- Проверяет и настраивает NVIDIA GPU
- Восстанавливает DBus
- Запускает GNOME Keyring
- Очищает блокировки
- Проверяет Docker образ

---

## Устранение неполадок

### Проблема: libsecret unavailable

**Решение:**
```bash
# Добавлено в Dockerfile
ENV SECRETS_SERVICE_IGNORE=1
```

### Проблема: Высокая нагрузка на CPU

**Решение:**
```bash
# Проверка использования GPU
nvidia-smi

# Если видите "llvmpipe" - переустановите драйверы
sudo dnf reinstall akmod-nvidia  # Fedora
sudo apt reinstall nvidia-driver-550  # Ubuntu
```

### Проблема: Ошибка подключения к дисплею

**Решение:**
```bash
# Настройка X11
xhost +

# Проверка DISPLAY
export DISPLAY=:0
```

### Проблема: NVIDIA GPU не видна в контейнере

**Решение:**
```bash
# Переустановка NVIDIA Container Toolkit
sudo dnf reinstall nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Проблема: После перезагрузки не работает

**Решение:**
```bash
# Запуск восстановления
max-fix

# Или добавьте в автозагрузку
cp ~/.local/share/applications/max-fix-tool.desktop ~/.config/autostart/
```

### Полная переустановка

```bash
# Остановка и удаление
docker stop max_messenger 2>/dev/null
docker rm max_messenger 2>/dev/null
docker rmi max-messenger:latest

# Очистка конфигурации
rm -rf ~/.max/Cache ~/.max/Singleton*

# Пересборка
cd ~/max-messenger/docker
docker build --no-cache -t max-messenger:latest .

# Запуск
max
```

---

## Заключение

После выполнения всех шагов вы получите:

- ✅ Полностью работающий MAX Messenger в Docker
- ✅ Поддержку аппаратного ускорения NVIDIA GPU
- ✅ Десктопные ярлыки для удобного запуска
- ✅ Инструменты диагностики и восстановления
- ✅ Автоматическое восстановление после перезагрузки

### Быстрый запуск:

```bash
# После перезагрузки
max-fix

# Запуск мессенджера
max

# При проблемах
max-debug
```

**Успешной работы с MAX Messenger в Docker!** 🚀
