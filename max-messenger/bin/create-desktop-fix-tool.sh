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

# Проверка наличия иконки
ICON_FIX="$SCRIPT_DIR/MAX-FIX-TOOL.png"
if [ ! -f "$ICON_FIX" ]; then
    log_warning "Иконка MAX-FIX-TOOL.png не найдена, будет использована стандартная"
    ICON_FIX=""
fi

# Проверка наличия скрипта
FIX_SCRIPT="$SCRIPT_DIR/fix-after-reboot.sh"
if [ ! -f "$FIX_SCRIPT" ]; then
    log_error "Скрипт fix-after-reboot.sh не найден!"
    exit 1
fi

# Создание десктоп файла для MAX Fix Tool
log_info "Создание ярлыка для MAX Fix Tool..."

cat > "$DESKTOP_DIR/max-fix-tool.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=MAX Fix Tool
GenericName=Fix Tool
Comment=Восстановление окружения после перезагрузки для MAX Messenger
Exec=${FIX_SCRIPT}
Icon=${ICON_FIX:-utilities-terminal}
Terminal=true
StartupNotify=true
StartupWMClass=max-fix
Categories=System;Settings;Utility;
Keywords=fixed;restore;max;messenger;diagnostic;
X-GNOME-Autostart-enabled=false
X-Desktop-File-Install-Version=0.26
EOF

# Проверка создания
if [ -f "$DESKTOP_DIR/max-fix-tool.desktop" ]; then
    chmod +x "$DESKTOP_DIR/max-fix-tool.desktop"
    log_success "Ярлык MAX Fix Tool создан: $DESKTOP_DIR/max-fix-tool.desktop"
else
    log_error "Не удалось создать ярлык MAX Fix Tool"
    exit 1
fi

# Обновление базы десктоп файлов
log_info "Обновление базы десктоп файлов..."
update-desktop-database "$DESKTOP_DIR" 2>/dev/null

if [ $? -eq 0 ]; then
    log_success "База десктоп файлов обновлена"
else
    log_warning "Не удалось обновить базу (это не критично)"
fi

# Проверка валидности
if command -v desktop-file-validate &> /dev/null; then
    log_info "Проверка валидности десктоп файла..."
    if desktop-file-validate "$DESKTOP_DIR/max-fix-tool.desktop" 2>/dev/null; then
        log_success "Файл max-fix-tool.desktop валиден"
    else
        log_warning "Проблемы в max-fix-tool.desktop"
    fi
fi

echo ""
log_success "Установка завершена!"
echo ""
echo "Ярлык установлен:"
echo "  🔧 MAX Fix Tool: $DESKTOP_DIR/max-fix-tool.desktop"
echo ""
echo "Теперь вы можете:"
echo "  1. Найти приложение в меню 'MAX Fix Tool'"
echo "  2. Закрепить на панели задач"
echo "  3. Запускать для восстановления окружения после перезагрузки"
echo ""
echo "Для проверки запуска из терминала:"
echo "  gtk-launch max-fix-tool"
echo "  или"
echo "  ${FIX_SCRIPT}"
