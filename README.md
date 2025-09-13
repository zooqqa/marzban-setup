# Marzban VPN Setup Guide

Полное руководство по установке и настройке Marzban VPN с поддержкой VLESS WebSocket и multi-server инфраструктуры.

## 🚀 Быстрый старт

### 1. Установка основного сервера (Complete Setup)

**Полная установка с рабочим VLESS WebSocket:**

```bash
# Полная установка с правильной конфигурацией
wget https://raw.githubusercontent.com/zooqqa/marzban-setup/main/install_marzban_complete.sh
chmod +x install_marzban_complete.sh
sudo ./install_marzban_complete.sh
```

### 2. Добавление дополнительных серверов (Nodes)

На каждом новом сервере для расширения ГЕО:

```bash
# Установка и настройка node сервера
wget https://raw.githubusercontent.com/zooqqa/marzban-setup/main/add_marzban_node.sh
chmod +x add_marzban_node.sh
sudo ./add_marzban_node.sh
```

### 3. Альтернативные скрипты

```bash
# Базовая установка (если нужна кастомизация)
wget https://raw.githubusercontent.com/zooqqa/marzban-setup/main/install_marzban.sh

# Продакшн установка (SSL + Nginx)
wget https://raw.githubusercontent.com/zooqqa/marzban-setup/main/setup_production.sh

# Настройка WebSocket (если установлен базовый Marzban)
wget https://raw.githubusercontent.com/zooqqa/marzban-setup/main/setup_vless_websocket.sh
```

## 📋 Подробная инструкция

### Подготовка сервера Ubuntu

1. **Подключитесь к серверу через SSH:**
   ```bash
   ssh root@YOUR_SERVER_IP
   ```

2. **Обновите систему:**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

3. **Установите необходимые пакеты:**
   ```bash
   sudo apt install -y curl wget git ufw
   ```

### Установка основного сервера Marzban

1. **Загрузите и выполните скрипт:**
   ```bash
   wget -O install_marzban.sh https://raw.githubusercontent.com/yourusername/marzban-setup/main/install_marzban.sh
   chmod +x install_marzban.sh
   sudo ./install_marzban.sh
   ```

2. **Создайте админа (будет запрошено во время установки):**
   - Введите имя пользователя
   - Введите пароль
   - Подтвердите пароль

3. **Доступ к панели управления:**
   - URL: `https://YOUR_SERVER_IP:8000/dashboard/`
   - Используйте созданные учетные данные для входа

### Настройка VLESS

1. **Войдите в панель управления**
2. **Создайте новый Inbound:**
   - Protocol: VLESS
   - Port: 443 (рекомендуется)
   - Settings: настройте по необходимости

3. **Создайте пользователей:**
   - Добавьте пользователей через интерфейс
   - Настройте лимиты трафика и времени

### Добавление дополнительных серверов

Для каждого нового сервера (например, в других странах):

1. **Создайте новый сервер** в облаке
2. **Выполните установку node:**
   ```bash
   wget -O install_marzban_node.sh https://raw.githubusercontent.com/yourusername/marzban-setup/main/install_marzban_node.sh
   chmod +x install_marzban_node.sh
   sudo ./install_marzban_node.sh
   ```

3. **Добавьте node в основную панель:**
   - Войдите в основную панель Marzban
   - Перейдите в раздел "Nodes"
   - Добавьте новый node с IP адресом нового сервера

## 🔧 Управление сервисами

### Основные команды Marzban:
```bash
marzban status    # Проверить статус
marzban logs      # Просмотр логов
marzban restart   # Перезапустить
marzban update    # Обновить
marzban down      # Остановить
```

### Команды для node:
```bash
marzban-node-NAME status    # Проверить статус (где NAME - имя вашего node)
marzban-node-NAME logs      # Просмотр логов
marzban-node-NAME restart   # Перезапустить
marzban-node-NAME update    # Обновить
```

## 🛠️ Важные файлы и директории

- **Конфигурация Marzban:** `/opt/marzban/.env`
- **Данные:** `/var/lib/marzban/`
- **Логи:** используйте `marzban logs`
- **Конфигурация node:** `/opt/NODE_NAME/.env`

## 🔐 Безопасность

1. **Настройте UFW (firewall):**
   ```bash
   sudo ufw allow ssh
   sudo ufw allow 8000/tcp  # Панель управления
   sudo ufw allow 443/tcp   # VLESS
   sudo ufw enable
   ```

2. **Используйте SSL сертификаты** для панели управления

3. **Регулярно обновляйте** систему и Marzban

## 🌍 Multi-Server архитектура

```
[Основной сервер - Германия]
         |
    [Dashboard]
         |
    ┌────┼────┐
    │    │    │
[Node1] [Node2] [Node3]
  США   Англия  Япония
```

## 📞 Поддержка

- **Официальная документация:** [Marzban Docs](https://gozargah.github.io/marzban/)
- **GitHub Issues:** [Marzban Issues](https://github.com/Gozargah/Marzban/issues)
- **Telegram:** @MarzbanVPN

## ⚠️ Важные заметки

- **Порт 8000** должен быть открыт для доступа к панели
- **Порт 443** рекомендуется для VLESS соединений
- Используйте **сильные пароли** для admin аккаунта
- Регулярно делайте **бэкапы** базы данных
- Мониторьте **использование ресурсов** на серверах