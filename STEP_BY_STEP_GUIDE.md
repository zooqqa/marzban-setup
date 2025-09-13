# Пошаговое руководство по установке Marzban VPN

## 🎯 Что вам нужно сделать

### Этап 1: Подготовка основного сервера

1. **Подключитесь к серверу Hetzner:**
   ```bash
   ssh root@YOUR_HETZNER_SERVER_IP
   ```

2. **Скачайте скрипт установки:**
   ```bash
   wget https://raw.githubusercontent.com/yourusername/marzban-setup/main/install_marzban.sh
   chmod +x install_marzban.sh
   ```

3. **Запустите установку:**
   ```bash
   sudo ./install_marzban.sh
   ```

4. **Во время установки вас попросят:**
   - Создать имя admin пользователя
   - Создать пароль (запишите его!)
   - Подтвердить пароль

### Этап 2: Первоначальная настройка

1. **Откройте браузер и перейдите:**
   ```
   https://YOUR_HETZNER_SERVER_IP:8000/dashboard/
   ```

2. **Войдите с созданными учетными данными**

3. **Создайте первый Inbound (VLESS):**
   - Перейдите в раздел "Inbounds"
   - Нажмите "Add Inbound"
   - Выберите протокол: VLESS
   - Порт: 443
   - Настройте security (TLS рекомендуется)

4. **Создайте первого пользователя:**
   - Перейдите в "Users"
   - Нажмите "Add User"
   - Укажите username
   - Установите лимиты трафика
   - Выберите созданный Inbound

### Этап 3: Добавление дополнительных серверов

Для каждого нового сервера (США, Англия, Япония и т.д.):

1. **Создайте новый сервер** в облачном провайдере

2. **Подключитесь к новому серверу:**
   ```bash
   ssh root@NEW_SERVER_IP
   ```

3. **Скачайте и запустите скрипт node:**
   ```bash
   wget https://raw.githubusercontent.com/yourusername/marzban-setup/main/install_marzban_node.sh
   chmod +x install_marzban_node.sh
   sudo ./install_marzban_node.sh
   ```

4. **Введите имя для node** (например: usa-node, uk-node)

5. **Добавьте node в основную панель:**
   - Войдите в основную панель Marzban
   - Перейдите в "Nodes"
   - Нажмите "Add Node"
   - Введите:
     - Name: usa-node (ваше имя)
     - Address: IP_НОВОГО_СЕРВЕРА
     - Port: 8000
     - Usage coefficient: 1.0

### Этап 4: Настройка пользователей для multi-server

1. **Создайте или отредактируйте пользователя:**
   - Перейдите в "Users"
   - Выберите пользователя или создайте нового
   - В настройках выберите нужные nodes
   - Пользователь сможет подключаться через любой выбранный сервер

### Этап 5: Получение конфигураций

1. **Для каждого пользователя:**
   - Перейдите в список пользователей
   - Нажмите на иконку "Subscribe" или "Config"
   - Скопируйте конфигурацию VLESS
   - Отправьте клиенту

## 🔧 Решение проблем

### Проблема: Не могу подключиться к панели управления
```bash
# Проверьте статус сервиса
marzban status

# Проверьте логи
marzban logs

# Перезапустите сервис
marzban restart
```

### Проблема: Node не подключается
```bash
# На node сервере проверьте статус
marzban-node-NAME status

# Проверьте логи node
marzban-node-NAME logs

# Убедитесь что порты открыты
sudo ufw status
```

### Проблема: Клиент не может подключиться
1. Проверьте правильность конфигурации
2. Убедитесь что порт 443 открыт
3. Проверьте статус Inbound в панели

## 📱 Настройка клиентов

### Для Android:
- Скачайте v2rayNG
- Импортируйте конфигурацию через QR-код или текст

### Для iOS:
- Скачайте Shadowrocket или FairVPN
- Импортируйте конфигурацию

### Для Windows:
- Скачайте v2rayN
- Импортируйте конфигурацию

### Для macOS:
- Скачайте V2rayU или ClashX
- Импортируйте конфигурацию

## 🚨 Важные команды

### Управление основным сервером:
```bash
marzban status          # Статус
marzban logs           # Логи
marzban restart        # Перезапуск
marzban update         # Обновление
marzban down           # Остановка
```

### Управление node:
```bash
marzban-node-usa status    # Статус node (замените 'usa' на ваше имя)
marzban-node-usa logs      # Логи node
marzban-node-usa restart   # Перезапуск node
```

### Создание admin пользователя:
```bash
marzban cli admin create --sudo
```

### Бэкап базы данных:
```bash
cp /var/lib/marzban/marzban.db /root/marzban_backup_$(date +%Y%m%d).db
```

## 🌐 Архитектура после установки

```
    [Ваш основной сервер Hetzner - Германия]
                    |
              [Marzban Dashboard]
            https://IP:8000/dashboard/
                    |
        ┌───────────┼───────────┐
        │           │           │
   [Node USA]  [Node UK]  [Node JP]
     VLESS      VLESS      VLESS
    Port 443   Port 443   Port 443
```

Пользователи смогут выбирать любой из серверов для подключения!

## 📞 Где получить помощь

- **GitHub Issues:** https://github.com/Gozargah/Marzban/issues
- **Документация:** https://gozargah.github.io/marzban/
- **Telegram:** @MarzbanVPN

## ✅ Чек-лист завершения

- [ ] Основной сервер установлен и работает
- [ ] Создан admin аккаунт
- [ ] Настроен первый Inbound (VLESS)
- [ ] Создан тестовый пользователь
- [ ] Проверено подключение клиента
- [ ] Установлены дополнительные nodes
- [ ] Nodes добавлены в панель управления
- [ ] Протестированы подключения через разные серверы