#!/usr/bin/env bash

# Получение директории скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DESKTOP_DIR="$HOME/.local/share/applications"

# Цвета
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Создание директории для десктоп файлов
mkdir -p "$DESKTOP_DIR"

# Проверка наличия иконок
ICON_MAIN="$SCRIPT_DIR/MAX-1024x1024.png"
ICON_DEBUG="$SCRIPT_DIR/MAX-DEBUG-TOOL.png"

if [ ! -f "$ICON_MAIN" ]; then
    log_warning "Иконка MAX-1024x1024.png не найдена, будет использована стандартная"
    ICON_MAIN=""
fi

if [ ! -f "$ICON_DEBUG" ]; then
    log_warning "Иконка MAX-DEBUG-TOOL.png не найдена, будет использована стандартная"
    ICON_DEBUG=""
fi

# 1. Создание десктоп файла для MAX Messenger
log_info "Создание ярлыка для MAX Messenger..."

cat > "$DESKTOP_DIR/max-messenger.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=MAX Messenger
GenericName=Messenger
Comment=Запуск мессенджера MAX в Docker (Wayland/X11)
Exec=${SCRIPT_DIR}/start-max.sh
Icon=${ICON_MAIN:-utilities-terminal}
Terminal=false
StartupNotify=true
StartupWMClass=max
Categories=Network;Chat;InstantMessaging;
Keywords=Messenger;VK;MAX;
MimeType=x-scheme-handler/max;
X-GNOME-Autostart-enabled=true
X-Desktop-File-Install-Version=0.26
EOF

# Проверка создания
if [ -f "$DESKTOP_DIR/max-messenger.desktop" ]; then
    chmod +x "$DESKTOP_DIR/max-messenger.desktop"
    log_success "Ярлык MAX Messenger создан: $DESKTOP_DIR/max-messenger.desktop"
else
    log_error "Не удалось создать ярлык MAX Messenger"
fi

# 2. Создание десктоп файла для MAX Debug Tool
log_info "Создание ярлыка для MAX Debug Tool..."

cat > "$DESKTOP_DIR/max-debug-tool.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=MAX Debug Tool
GenericName=Debug Tool
Comment=Диагностика и отладка MAX Messenger в Docker
Exec=${SCRIPT_DIR}/max-debug.sh
Icon=${ICON_DEBUG:-utilities-terminal}
Terminal=true
StartupNotify=true
StartupWMClass=max-debug
Categories=Development;Debugger;System;
Keywords=debug;max;messenger;diagnostic;
X-GNOME-Autostart-enabled=false
X-Desktop-File-Install-Version=0.26
EOF

# Проверка создания
if [ -f "$DESKTOP_DIR/max-debug-tool.desktop" ]; then
    chmod +x "$DESKTOP_DIR/max-debug-tool.desktop"
    log_success "Ярлык MAX Debug Tool создан: $DESKTOP_DIR/max-debug-tool.desktop"
else
    log_error "Не удалось создать ярлык MAX Debug Tool"
fi

# 3. Обновление базы десктоп файлов
log_info "Обновление базы десктоп файлов..."
update-desktop-database "$DESKTOP_DIR" 2>/dev/null

if [ $? -eq 0 ]; then
    log_success "База десктоп файлов обновлена"
else
    log_warning "Не удалось обновить базу (это не критично)"
fi

# 4. Проверка валидности (если установлен desktop-file-utils)
if command -v desktop-file-validate &> /dev/null; then
    log_info "Проверка валидности десктоп файлов..."

    if desktop-file-validate "$DESKTOP_DIR/max-messenger.desktop" 2>/dev/null; then
        log_success "Файл max-messenger.desktop валиден"
    else
        log_warning "Проблемы в max-messenger.desktop"
    fi

    if desktop-file-validate "$DESKTOP_DIR/max-debug-tool.desktop" 2>/dev/null; then
        log_success "Файл max-debug-tool.desktop валиден"
    else
        log_warning "Проблемы в max-debug-tool.desktop"
    fi
fi

echo ""
log_success "Установка завершена!"
echo ""
echo "Ярлыки установлены:"
echo "  📱 MAX Messenger: $DESKTOP_DIR/max-messenger.desktop"
echo "  🐛 MAX Debug Tool: $DESKTOP_DIR/max-debug-tool.desktop"
echo ""
echo "Теперь вы можете:"
echo "  1. Найти приложения в меню 'MAX Messenger' и 'MAX Debug Tool'"
echo "  2. Закрепить их на панели задач"
echo "  3. Добавить в избранное"
echo ""
echo "Для проверки запуска из терминала:"
echo "  gtk-launch max-messenger"
echo "  gtk-launch max-debug-tool"
