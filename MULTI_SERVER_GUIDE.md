# Multi-Server Marzban Setup Guide

Полное руководство по настройке multi-server инфраструктуры Marzban для расширения геолокаций VPN.

## 🏗️ Архитектура

```
    [Главный сервер - Германия]
           |
    [Marzban Dashboard]
    https://yourdomain.com
           |
    ┌──────┼──────┬──────┐
    │      │      │      │
[Node 1] [Node 2] [Node 3] [Node 4]
  США     UK      JP     SG
```

## 🚀 Быстрый старт

### 1. Настройка главного сервера

```bash
# Полная установка с WebSocket VLESS
wget https://raw.githubusercontent.com/zooqqa/marzban-setup/main/install_marzban_complete.sh
chmod +x install_marzban_complete.sh
sudo ./install_marzban_complete.sh
```

### 2. Добавление дополнительных серверов (nodes)

На каждом новом сервере:

```bash
# Установка node
wget https://raw.githubusercontent.com/zooqqa/marzban-setup/main/add_marzban_node.sh
chmod +x add_marzban_node.sh
sudo ./add_marzban_node.sh
```

## 📋 Подробная настройка

### Шаг 1: Главный сервер

1. **Подготовьте домен:**
   - Купите домен или используйте бесплатный (duckdns.org)
   - Направьте A-запись на IP главного сервера

2. **Установите Marzban:**
   ```bash
   wget https://raw.githubusercontent.com/zooqqa/marzban-setup/main/install_marzban_complete.sh
   chmod +x install_marzban_complete.sh
   sudo ./install_marzban_complete.sh
   ```

3. **Создайте admin:**
   ```bash
   marzban cli admin create --sudo
   ```

4. **Настройте панель:**
   - Откройте https://yourdomain.com
   - Вставьте конфигурацию из вывода скрипта в Core Settings
   - Создайте Host Settings как показано в инструкции
   - Создайте тестового пользователя

### Шаг 2: Добавление Node серверов

Для каждого нового сервера (США, UK, Япония и т.д.):

1. **Подготовьте поддомен:**
   - `usa.yourdomain.com` → IP сервера в США
   - `uk.yourdomain.com` → IP сервера в UK
   - `jp.yourdomain.com` → IP сервера в Японии

2. **Установите node:**
   ```bash
   # На сервере в США
   wget https://raw.githubusercontent.com/zooqqa/marzban-setup/main/add_marzban_node.sh
   chmod +x add_marzban_node.sh
   sudo ./add_marzban_node.sh
   # Введите: usa-node и usa.yourdomain.com
   ```

3. **Подключите node к главному серверу:**
   - В главной панели: Node Settings → Add Node
   - Name: `usa-node`
   - Address: IP сервера в США
   - Port: `62050`
   - API Port: `62051`

### Шаг 3: Настройка пользователей для multi-server

1. **В Host Settings создайте записи для каждого сервера:**

   **Главный сервер (Германия):**
   - Remark: `Germany-VLESS`
   - Address: `yourdomain.com`
   - Port: `443`
   - Path: `/vless-ws`
   - Network: `ws`
   - Security: `tls`
   - SNI: `yourdomain.com`

   **Сервер США:**
   - Remark: `USA-VLESS`
   - Address: `usa.yourdomain.com`
   - Port: `443`
   - Path: `/vless-ws`
   - Network: `ws`
   - Security: `tls`
   - SNI: `usa.yourdomain.com`

   **И так для каждого сервера...**

2. **При создании пользователя:**
   - Выберите нужные inbound'ы (серверы)
   - Пользователь получит конфигурации для всех выбранных серверов

## 🔧 Управление серверами

### Команды главного сервера:
```bash
marzban status      # Статус
marzban logs        # Логи
marzban restart     # Перезапуск
marzban update      # Обновление
```

### Команды node серверов:
```bash
usa-node status     # Статус node
usa-node logs       # Логи node
usa-node restart    # Перезапуск node
uk-node status      # Для UK сервера
jp-node status      # Для японского сервера
```

### Мониторинг портов:
```bash
# Проверить WebSocket порт на любом сервере
ss -tlnp | grep 8443

# Проверить Marzban-node порт
ss -tlnp | grep 62050
```

## 📱 Как пользователи выбирают сервер

### Вариант 1: Subscription URL (рекомендуется)

Каждый пользователь получает subscription URL:
```
https://yourdomain.com/sub/USER_TOKEN
```

Этот URL содержит **все доступные серверы** пользователя. В клиентах V2Ray/VLESS пользователь видит список:
- Germany-VLESS (yourdomain.com)
- USA-VLESS (usa.yourdomain.com)  
- UK-VLESS (uk.yourdomain.com)
- Japan-VLESS (jp.yourdomain.com)

Пользователь просто **выбирает нужный сервер** в приложении.

### Вариант 2: Отдельные конфигурации

Можно выдавать отдельные конфигурации для каждого сервера:
- QR-код для Германии
- QR-код для США
- QR-код для UK
- QR-код для Японии

### Вариант 3: Автоматическое переключение

В продвинутых клиентах можно настроить:
- **Load balancing** - автоматическое распределение
- **Failover** - переключение при недоступности
- **Routing rules** - разные сайты через разные серверы

## 🌍 Рекомендуемые локации

### Популярные для VPN:
- 🇩🇪 **Германия** (главный) - хорошие законы о приватности
- 🇺🇸 **США** - доступ к американскому контенту
- 🇬🇧 **Великобритания** - английский контент
- 🇯🇵 **Япония** - азиатский контент, игры
- 🇸🇬 **Сингапур** - центр Азии
- 🇳🇱 **Нидерланды** - хорошие законы, быстрый интернет
- 🇨🇦 **Канада** - приватность + американский контент

### Облачные провайдеры:
- **Hetzner** (Германия) - дешево и надежно
- **DigitalOcean** - есть во многих странах
- **Vultr** - много локаций
- **Linode** - стабильный
- **AWS/GCP** - если нужна максимальная стабильность

## 🔐 Безопасность multi-server

### На каждом сервере:
```bash
# Настроить firewall
ufw allow ssh
ufw allow 443/tcp
ufw allow 62050/tcp  # только для node серверов
ufw enable

# Обновлять систему
apt update && apt upgrade -y

# Мониторить логи
tail -f /var/log/auth.log
```

### SSL сертификаты:
- Каждый сервер должен иметь свой SSL сертификат
- Автообновление настроено автоматически
- Проверять: `certbot certificates`

## 🚨 Troubleshooting

### Проблема: Node не подключается к главному серверу

```bash
# На node сервере
usa-node logs

# Проверить порты
ss -tlnp | grep 62050

# Проверить firewall
ufw status
```

### Проблема: Пользователи не могут подключиться к node

```bash
# Проверить WebSocket порт
ss -tlnp | grep 8443

# Проверить Nginx
nginx -t
systemctl status nginx

# Проверить SSL
curl -I https://usa.yourdomain.com
```

### Проблема: Subscription не обновляется

```bash
# Перезапустить главный Marzban
marzban restart

# Проверить статус всех node
usa-node status
uk-node status
jp-node status
```

## 📊 Мониторинг и статистика

### В панели Marzban вы можете видеть:
- **Трафик по серверам** - сколько используется каждый сервер
- **Онлайн пользователи** - кто и где подключен  
- **Статистику по странам** - популярные направления
- **Нагрузку на серверы** - для балансировки

### Команды для мониторинга:
```bash
# Использование системы
htop
df -h
free -h

# Сетевая статистика  
iftop
nethogs

# Логи подключений
marzban logs | grep "connected"
```

## ✅ Чек-лист multi-server

### Главный сервер:
- [ ] Marzban установлен и работает
- [ ] SSL сертификат получен
- [ ] WebSocket VLESS настроен
- [ ] Admin пользователь создан
- [ ] Тестовый пользователь работает

### Node серверы:
- [ ] Marzban-node установлен на каждом сервере
- [ ] SSL сертификаты получены для всех доменов
- [ ] WebSocket настроен на каждом node
- [ ] Node подключены к главному серверу
- [ ] Firewall настроен правильно

### Пользователи:
- [ ] Host Settings созданы для всех серверов
- [ ] Subscription URL работает
- [ ] Пользователи видят все серверы в клиенте
- [ ] Переключение между серверами работает
- [ ] Все серверы доступны и пингуются

Теперь у вас полноценная multi-server VPN инфраструктура! 🎉