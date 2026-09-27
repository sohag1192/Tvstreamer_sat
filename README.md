# TVStreammerSAT5

**Languages / Языки:** [English](#english) | [Русский](#русский) | [README_RU.md](README_RU.md)

---

<a id="english"></a>
## English

**Version: 203.73**

TVStreammerSAT5 is a TV stream routing, monitoring, and conversion server built on C++17 and GStreamer. The application ingests network and satellite sources, generates one or more outputs for each channel, and is managed via an integrated Russian/English web control panel.

![TVStreammerSAT5 Main Dashboard](./docs/screenshots/dashboard.png)

![OSCam-mini Management](./docs/screenshots/oscam-mini.png)

### Features

- Create, edit, start, stop, and delete streams directly from the web browser;
- Primary and backup sources with automatic failover and recovery;
- Multiple independent outputs per stream;
- MPEG-TS passthrough or audio/video transcoding;
- CBR/VBR transport stream generation, PCR control, and continuity counter checks;
- Remapping of SID, video/audio PID, Service Name, and Provider;
- DVB-S/S2 scanning with adapter, frontend, transponder, and service selection;
- Shared use of a single DVB frontend by channels on the same transponder;
- Support for FTA and local Conditional Access via CA plugin and OSCam-mini;
- Monitoring of input/output bitrate, errors, DVB signal/quality, and network interface load;
- Subscriber management, IP filtering, and active session display;
- Telegram alerts on stream state changes;
- Built-in test pattern generator and replacement/fallback file library;
- HTTP Basic Authentication and panel password encryption in configuration.

### Architecture

Standard streams are processed in-process without mandatory transcoding.
For each channel, an input protocol is selected first, followed by the creation of a passthrough or remap pipeline and one primary or several secondary outputs.

```text
Input Protocol
      |
      +-- passthrough/remap ----------------------> Output Protocol
      |
      +-- Optional GStreamer transcoder
              |
              +-- decode
              +-- deinterlace / scale / frame rate
              +-- H.264 + AAC/MP3
              +-- output module
```

Protocol source code is organized into modular directories:

```text
src/protocols/inputs/          Transcoder input URI modules
src/protocols/outputs/         Transcoder output URI modules
src/protocols/stream/inputs/   Standard streaming pipeline inputs
src/protocols/stream/outputs/  Standard streaming pipeline outputs
```

### Supported Protocols

#### Inputs

| Source | Examples and Modes |
| --- | --- |
| UDP MPEG-TS | Unicast, multicast, input network interface selection |
| RTP MPEG-TS | Unicast and multicast |
| SRT | Caller and Listener modes |
| HTTP MPEG-TS | Single stream over HTTP/HTTPS |
| HLS | Master/media playlists, segments, Header or Query access key |
| RTSP | IP cameras and media servers |
| RTMP | RTMP sources |
| File | Local file, including loop-playback replacement/fallback files |
| DVB-S/S2 | Linux DVB frontend via `dvbsrc` |
| Test Signal | Built-in `test://bars` |

#### Outputs

| Output | Description / Purpose |
| --- | --- |
| UDP MPEG-TS VBR | Transmits original transport stream |
| UDP MPEG-TS CBR | Transport stream with specified target bitrate |
| RTP MPEG-TS | Delivers MPEG-TS over RTP |
| SRT | Caller or Listener mode |
| HTTP TS | Continuous MPEG-TS over HTTP |
| HLS | Live playlist and MPEG-TS segments |
| RTSP Push | Publishes stream to an external RTSP server |
| RTMP Push | Publishes stream to an RTMP server or YouTube |

For a single channel, you can configure a primary output and multiple secondary outputs of different protocol types.

H.264 transcoding supports CPU-based `x264enc` and hardware-accelerated NVIDIA NVENC via GStreamer `nvh264enc`. In `Auto` mode, the application prioritizes NVENC when the `nvh264enc` element is available, and automatically falls back to `x264enc` otherwise. NVENC requires a functional proprietary NVIDIA driver with NVENC support and GStreamer `nvcodec`; verify server availability using `nvidia-smi` and `gst-inspect-1.0 nvh264enc`.

### Web Control Panel

After launching, the web interface is accessible at:

```text
http://SERVER_IP:9000/
```

Initial default credentials on first launch:

```text
login: admin
password: admin
```

Change the password immediately in the settings. The password is stored encrypted in `tvstreammersat5-config.json` using AES-256-GCM, and the local encryption key is generated adjacent to the configuration file in `tvstreammersat5-ui.key` with `0600` permissions.

The main dashboard displays channel cards, source status, active input, bitrate, output mode, MPEG-TS errors, DVB metrics, and decoding state. Application settings, subscribers, CA clients, and the About modal are accessible from the top navigation bar.

### Subscribers and Connection Monitoring

The **Subscribers** modal shows active stream connections over HTTP, HLS, and SRT. For each client IP, the stream ID, stream name, protocol, and number of connections are displayed. For registered subscribers, the active stream numbers appear in the session column.

An unregistered IP can immediately be:

- Added as a subscriber with access to the selected stream;
- Blocked independently of the global IP filtering state;
- Subsequently unblocked from the blocked address list.

The blocked list is stored in `tvstreammersat5-subscribers.json` under the `blocked_ips` field. Note that UDP does not establish a bidirectional client session; therefore, the application cannot track UDP unicast/multicast recipients. Monitoring UDP receivers requires network switches and IGMP snooping diagnostics.

### DVB-S/S2

The satellite channel configuration dialog supports:

- Selection of `/dev/dvb/adapterN/frontendN`;
- DVB-S and DVB-S2 standards;
- Frequency, symbol rate, polarization, FEC, and modulation;
- DiSEqC and LNB LOF parameters;
- DVB-S2 stream ID (multistream);
- Real-time display of LOCK status, signal power, and signal quality;
- Scanning of PAT/PMT/SDT tables and selection of discovered services;
- Automatic saving of SID, PMT, PCR, and elementary stream PIDs.

Channels located on the same transponder can share a single physical frontend. To tune into another transponder simultaneously, a separate frontend device is required, or existing channels on that device must be stopped.

The running process user must have read and write permissions to `/dev/dvb/*`.

### Conditional Access and OSCam-mini

The project features:

- Versioned in-process `CaBackend` ABI;
- `tvstreammersat5-ca-newcamd.so` plugin;
- Automatic detection of Phoenix/SmartMouse USB card readers;
- Binding of encrypted channels to specific CA clients;
- Service count limits and live descrambling status on channel cards;
- Vendored OSCam-mini with Newcamd, Irdeto, Viaccess, and Phoenix support.

OSCam-mini is compiled as part of the unified CMake target and managed at:

```text
http://SERVER_IP:9000/oscam-mini
```

For detailed configuration instructions, see [OSCAM_MINI.md](OSCAM_MINI.md). The plugin interface is documented in [docs/CA_BACKEND_PLUGIN_API.md](docs/CA_BACKEND_PLUGIN_API.md), and Phoenix serial transport in [docs/PHOENIX_SERIAL_TRANSPORT.md](docs/PHOENIX_SERIAL_TRANSPORT.md).

*Notice: Use Conditional Access exclusively with equipment, smartcards, and services for which you possess legal and authorized access rights.*

### System Requirements

- Ubuntu 24.04 or compatible Debian/Ubuntu distribution;
- CMake 3.10 or newer;
- C++17 compliant compiler;
- GStreamer 1.0 along with Base, Good, Bad, Ugly, and Libav plugin sets;
- Boost Thread/System, JsonCpp, libcurl, OpenSSL, and libdvbcsa;
- Linux DVB and Phoenix/SmartMouse hardware (required only when utilizing respective features).

### Automated Installation (Ubuntu / Debian)

The easiest way to install TVStreammerSAT5 on Ubuntu (20.04 / 22.04 / 24.04 LTS) or Debian is using the all-in-one installation script:

```bash
sudo bash install.sh
```

This single command automatically:
1. Installs all required packages via `apt` (build tools, GStreamer, Boost, libdvbcsa, pcscd, codecs).
2. Tunes kernel network socket buffers (`/etc/sysctl.d/99-tvstreammer-udp.conf`) for high-bitrate streaming without packet drop.
3. Ensures browser streaming assets (`hls.js`, `mpegts.js`) are present in `web/vendor/`.
4. Compiles the application and plugins with CMake.
5. Deploys binary, web UI, and plugins to `/opt/TVStreammerSAT5`.
6. Configures, enables, and starts the `tvstreammersat5.service` systemd service.

Installer options:
- `sudo bash install.sh --with-oscam` — Also builds and deploys vendored OSCam-mini.
- `sudo bash install.sh --no-start` — Deploys without immediately starting the service.
- `sudo bash install.sh -y` — Runs non-interactively.

---

### Manual Building

Install dependencies:

```bash
chmod +x install_deps.sh
sudo ./install_deps.sh
```

Build the application, Newcamd CA plugin, and OSCam-mini:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
```

Primary build artifacts:

```text
build/TVStreammerSAT5
build/tvstreammersat5-ca-newcamd.so
build/oscam-mini/oscam-mini
```

### Running

The program reads its configuration from the current working directory. On initial launch, default files are generated automatically.

```bash
mkdir -p ~/tvstreammersat5-data
cd ~/tvstreammersat5-data
/path/to/project/build/TVStreammerSAT5
```

The application logs will print the active HTTP port (default: `9000`). To terminate the server, press `Ctrl+C` or use standard service manager controls.

Install compiled components system-wide:

```bash
sudo cmake --install build
```

### Running as a systemd Service

Install the executable and create a dedicated working directory for configuration:

```bash
sudo mkdir -p /opt/tvstreammersat5
sudo install -m 755 build/TVStreammerSAT5 /opt/tvstreammersat5/TVStreammerSAT5
```

Example `/etc/systemd/system/tvstreammersat5.service`:

```ini
[Unit]
Description=TVStreammerSAT5
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/tvstreammersat5
ExecStart=/opt/tvstreammersat5/TVStreammerSAT5
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Activate and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tvstreammersat5
sudo systemctl status tvstreammersat5 --no-pager --full
```

### Configuration Files

All mutable runtime files reside in the working directory of the process:

```text
tvstreammersat5-config.json       Main settings, channel configurations, and outputs
tvstreammersat5-ui.key            AES key for web UI password encryption
tvstreammersat5-subscribers.json  Subscribers database and IP filter rules
backup-files/                     Uploaded replacement/fallback media files
```

Always back up these files prior to upgrading. Keep your configuration secure: it may contain sensitive network IP addresses, Telegram bot tokens, and CA client credentials.

### UDP and PCR Settings

For standard UDP output, the application buffers 1500 ms of stream data and begins transmission aligned with the nearest independently decodable video keyframe (IDR). If a legacy receiver requires the earlier 5-second initial buffer, set the environment variable:

```bash
TVS_UDP_STARTUP_BUFFER_MS=5000
```

Supported buffer range: `250` to `30000` ms. Pass this variable to the process or container via `docker run -e TVS_UDP_STARTUP_BUFFER_MS=5000 ...`.

For continuous DVB/IP MPEG-TS streams, CBR output preserves the original input PCR timestamps so that PCR, PTS, and DTS stay on a synchronized timeline. Synthetic continuous PCR is generated automatically for segmented HLS. You can force legacy synthetic PCR mode via:

```bash
TVS_UDP_FORCE_SYNTHETIC_PCR=1
```

### Docker

Building and running under Docker utilizes host networking to enable multicast, RTP, SRT listener, and network interface binding.

#### Building the Image

```bash
docker build --pull -t tvstreammersat5:202.28 .
```

For a complete rebuild without using cached layers:

```bash
docker build --pull --no-cache -t tvstreammersat5:202.28 .
```

#### Background Execution

Specify a persistent data directory on the host. If the default `tvstreammersat5-config.json` does not exist, the server will create it on initial start.

```bash
cd ~/Tvstreamer_sat
mkdir -p /opt/tvstreammersat5

CONTAINER_NAME=tvstreammersat5 DETACH=1 RECREATE=1 IMAGE_NAME=tvstreammersat5:202.28 CONFIG_FILE=/opt/tvstreammersat5/tvstreammersat5-config.json bash ./scripts/run_container.sh

docker ps --filter name=tvstreammersat5
docker logs --tail 100 tvstreammersat5
```

The script verifies image availability before deleting any existing container and prints the created container ID. `RECREATE=1` enables recreating an existing container or launching a new one in a single step. Background mode runs with the `unless-stopped` restart policy. The script attaches host networking, mounts the persistent data directory, and forwards detected `/dev/dvb` devices into the container.

A newly initialized configuration contains no channels and defaults to `admin` / `admin`. Change the password upon first logging in.

Interactive temporary execution is available by omitting `DETACH=1`:

```bash
IMAGE_NAME=tvstreammersat5:202.28 CONFIG_FILE=/opt/tvstreammersat5/tvstreammersat5-config.json ./scripts/run_container.sh
```

#### Container Management

`docker restart` restarts an existing container running the current image. When rebuilding the image, recreation is required:

```bash
# Container status
docker ps -a --filter name=tvstreammersat5

# View last 200 log lines
docker logs --tail 200 tvstreammersat5
docker logs --tail 200 -f tvstreammersat5

# Restart container
docker restart tvstreammersat5

# Stop and start
docker stop tvstreammersat5
docker start tvstreammersat5

# Inspect container state and configuration
docker inspect tvstreammersat5
```

#### Updating and Rebuilding

Execute all commands from the repository root. The new Docker image is fully built and verified before the helper script replaces the active container.

```bash
cd ~/Tvstreamer_sat

git pull origin main
docker build --pull -t tvstreammersat5:202.28 .

CONTAINER_NAME=tvstreammersat5 DETACH=1 RECREATE=1 IMAGE_NAME=tvstreammersat5:202.28 CONFIG_FILE=/opt/tvstreammersat5/tvstreammersat5-config.json bash ./scripts/run_container.sh

# Verify container is running (Up)
docker ps --filter name=tvstreammersat5   --format 'table {{.Names}}	{{.Status}}	{{.Image}}'

# Verify application health
docker logs --tail 100 tvstreammersat5
curl --fail http://127.0.0.1:9000/health
```

If the script fails before reaching the `Removing existing container` step, the existing container remains unharmed. Error output will explain the failure reason (e.g. missing image or invalid path).

The configuration file, UI encryption key, subscriber database, and fallback files remain safely stored on the host in the directory containing `CONFIG_FILE`.

Verification after rebuild:

```bash
docker ps -a --filter name=tvstreammersat5
docker ps --filter name=tvstreammersat5
docker logs --tail 100 tvstreammersat5
curl --fail http://127.0.0.1:9000/health
```

### Testing and Diagnostics

Verify HTTP server response without authentication:

```bash
curl http://127.0.0.1:9000/health
```

Verify GStreamer plugin availability:

```bash
./scripts/check_transcoder_plugins.sh
gst-inspect-1.0 dvbsrc
gst-inspect-1.0 mpegtsmux
```

For detailed GStreamer debug logs:

```bash
GST_DEBUG=2 ./build/TVStreammerSAT5
```

If a DVB frontend is locked or busy, check other processes and ensure channels sharing the same frontend belong to the same transponder. If transcoding is not functioning, run `scripts/check_transcoder_plugins.sh` to verify that supported video and audio encoder elements are installed.

### Third-Party Component Licenses

OSCam-mini source code is located in `third_party/oscam-mini` along with its license files and upstream revision notes. Licenses for other dependencies are governed by their respective system packages.

### Contacts

Support: [monkipnet@gmail.com](mailto:monkipnet@gmail.com)

---

<a id="русский"></a>
## Русский (Оригинальная версия)

[English](#english) | **Русский**

---

**Версия: 203.73**

TVStreammerSAT5 - сервер маршрутизации, мониторинга и преобразования телевизионных потоков на базе C++17 и GStreamer. Программа принимает сетевые и спутниковые источники, формирует один или несколько выходов для каждого канала и управляется через встроенную русско-английскую веб-панель.

![Основная панель TVStreammerSAT5](./docs/screenshots/dashboard.png)

![Управление OSCam-mini](./docs/screenshots/oscam-mini.png)

## Возможности

- создание, редактирование, запуск, остановка и удаление потоков из браузера;
- основной и резервный источник с автоматическим переключением и возвратом;
- несколько независимых выходов у одного потока;
- MPEG-TS passthrough или транскодирование видео и аудио;
- CBR/VBR-формирование транспортного потока, контроль PCR и continuity counter;
- переназначение SID, video/audio PID, Service Name и Provider;
- DVB-S/S2 сканирование с выбором адаптера, frontend, транспондера и сервисов;
- совместное использование одного DVB frontend каналами одного транспондера;
- работа с FTA и локальной Conditional Access через CA-плагин и OSCam-mini;
- мониторинг входного/выходного битрейта, ошибок, DVB signal/quality и загрузки интерфейсов;
- список абонентов, фильтрация по IP и отображение активных сессий;
- Telegram-уведомления о состоянии потоков;
- встроенный тестовый источник и библиотека файлов замены;
- Basic Authentication и шифрование пароля панели в конфигурации.

## Архитектура

Обычные потоки обрабатываются внутри процесса без обязательного транскодирования.
Для каждого канала сначала выбирается входной протокол, затем создаётся passthrough
или remap-путь и один основной либо несколько дополнительных выходов.

```text
Входной протокол
      |
      +-- passthrough/remap ----------------------> выходной протокол
      |
      +-- опциональный GStreamer transcoder
              |
              +-- decode
              +-- deinterlace / scale / frame rate
              +-- H.264 + AAC/MP3
              +-- выходной модуль
```

Код протоколов разделён по каталогам:

```text
src/protocols/inputs/          URI-модули входов транскодера
src/protocols/outputs/         URI-модули выходов транскодера
src/protocols/stream/inputs/   входы обычного поточного пути
src/protocols/stream/outputs/  выходы обычного поточного пути
```

## Поддерживаемые протоколы

### Входы

| Источник | Примеры и режимы |
| --- | --- |
| UDP MPEG-TS | unicast, multicast, выбор входного интерфейса |
| RTP MPEG-TS | unicast и multicast |
| SRT | Caller и Listener |
| HTTP MPEG-TS | одиночный поток по HTTP/HTTPS |
| HLS | master/media playlist, сегменты, Header или Query access key |
| RTSP | сетевые камеры и медиасерверы |
| RTMP | RTMP-источники |
| Файл | локальный файл, в том числе файл замены с циклическим воспроизведением |
| DVB-S/S2 | Linux DVB frontend через `dvbsrc` |
| Тестовый сигнал | встроенный `test://bars` |

### Выходы

| Выход | Назначение |
| --- | --- |
| UDP MPEG-TS VBR | передача исходного транспортного потока |
| UDP MPEG-TS CBR | транспортный поток с заданным целевым битрейтом |
| RTP MPEG-TS | доставка MPEG-TS поверх RTP |
| SRT | Caller или Listener |
| HTTP TS | непрерывный MPEG-TS по HTTP |
| HLS | live playlist и MPEG-TS сегменты |
| RTSP Push | публикация на внешний RTSP-сервер |
| RTMP Push | публикация на RTMP-сервер или YouTube |

Для одного канала можно настроить основной и дополнительные выходы разных типов.

H.264-транскодирование поддерживает CPU `x264enc` и NVIDIA NVENC через GStreamer
`nvh264enc`. В режиме `Auto` программа предпочитает NVENC, если элемент `nvh264enc`
доступен, и автоматически использует `x264enc` иначе. Для NVENC требуется рабочий
проприетарный драйвер NVIDIA с поддержкой NVENC и GStreamer `nvcodec`; проверить
сервер можно командами `nvidia-smi` и `gst-inspect-1.0 nvh264enc`.

## Веб-панель

После запуска панель доступна по адресу:

```text
http://SERVER_IP:9000/
```

Начальные учётные данные при первом запуске:

```text
login: admin
password: admin
```

Сразу измените пароль в настройках. Он хранится в `tvstreammersat5-config.json` в зашифрованном виде AES-256-GCM, а локальный ключ создаётся рядом с конфигурацией в файле `tvstreammersat5-ui.key` с правами `0600`.

Основная панель показывает карточки каналов, состояние источника, активный вход, битрейт, режим выхода, ошибки MPEG-TS, DVB-метрики и состояние декодирования. Настройки программы, абоненты, CA-клиенты и окно «О программе» доступны из верхней панели.

## Абоненты и мониторинг подключений

Окно **Абоненты** показывает активные подключения к потокам по HTTP, HLS и SRT. Для каждого IP отображаются номер и название потока, протокол и количество соединений. У зарегистрированного абонента текущие номера потоков видны в колонке сессии.

Незарегистрированный IP можно сразу:

- добавить в абоненты с доступом к выбранному потоку;
- заблокировать независимо от состояния общей IP-фильтрации;
- позднее разблокировать в списке заблокированных адресов.

Список блокировок хранится в `tvstreammersat5-subscribers.json` в поле `blocked_ips`. UDP не устанавливает клиентскую сессию, поэтому приложение не может определить получателей UDP unicast/multicast; для их контроля нужен мониторинг IGMP и сетевого оборудования.

## DVB-S/S2

Диалог добавления спутниковых каналов поддерживает:

- выбор `/dev/dvb/adapterN/frontendN`;
- DVB-S и DVB-S2;
- частоту, symbol rate, поляризацию, FEC и модуляцию;
- DiSEqC и параметры LNB LOF;
- DVB-S2 stream ID;
- просмотр LOCK, signal и quality;
- сканирование PAT/PMT/SDT и выбор найденных сервисов;
- автоматическое сохранение SID, PMT, PCR и elementary PID.

Каналы одного транспондера могут использовать общий физический frontend. Для одновременного приёма другого транспондера требуется другой frontend или остановка текущих каналов на этом устройстве.

Пользователь процесса должен иметь доступ на чтение и запись к `/dev/dvb/*`.

## Conditional Access и OSCam-mini

Проект включает:

- версионированный in-process `CaBackend` ABI;
- плагин `tvstreammersat5-ca-newcamd.so`;
- обнаружение Phoenix/SmartMouse USB reader;
- привязку зашифрованного канала к конкретному CA-клиенту;
- ограничения количества сервисов и состояние декодирования в карточке канала;
- vendored OSCam-mini с Newcamd, Irdeto, Viaccess и Phoenix.

OSCam-mini собирается общей целью CMake и управляется на странице:

```text
http://SERVER_IP:9000/oscam-mini
```

Подробная настройка описана в [OSCAM_MINI.md](OSCAM_MINI.md). Интерфейс плагина описан в [docs/CA_BACKEND_PLUGIN_API.md](docs/CA_BACKEND_PLUGIN_API.md), транспорт Phoenix - в [docs/PHOENIX_SERIAL_TRANSPORT.md](docs/PHOENIX_SERIAL_TRANSPORT.md).

Используйте Conditional Access только с оборудованием, картами и сервисами, для которых у вас есть законные права доступа.

## Системные требования

- Ubuntu 24.04 или совместимая Debian/Ubuntu система;
- CMake 3.10 или новее;
- компилятор с поддержкой C++17;
- GStreamer 1.0 и наборы Base/Good/Bad/Ugly/Libav;
- Boost Thread/System, JsonCpp, libcurl, OpenSSL и libdvbcsa;
- Linux DVB и Phoenix/SmartMouse устройства - только для соответствующих функций.

## Сборка

Установите зависимости:

```bash
chmod +x install_deps.sh
sudo ./install_deps.sh
```

Соберите приложение, Newcamd CA-плагин и OSCam-mini:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
```

Основные артефакты:

```text
build/TVStreammerSAT5
build/tvstreammersat5-ca-newcamd.so
build/oscam-mini/oscam-mini
```

## Запуск

Программа читает конфигурацию из текущего рабочего каталога. При первом запуске она создаётся автоматически.

```bash
mkdir -p ~/tvstreammersat5-data
cd ~/tvstreammersat5-data
/path/to/project/build/TVStreammerSAT5
```

В журнале появится адрес HTTP-порта, по умолчанию `9000`. Для остановки используйте `Ctrl+C` или штатное управление сервисом.

Установка собранных компонентов:

```bash
sudo cmake --install build
```

## Запуск как systemd-сервис

Установите бинарник и создайте отдельный рабочий каталог для конфигурации:

```bash
sudo mkdir -p /opt/tvstreammersat5
sudo install -m 755 build/TVStreammerSAT5 /opt/tvstreammersat5/TVStreammerSAT5
```

Пример `/etc/systemd/system/tvstreammersat5.service`:

```ini
[Unit]
Description=TVStreammerSAT5
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/tvstreammersat5
ExecStart=/opt/tvstreammersat5/TVStreammerSAT5
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Активируйте сервис:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tvstreammersat5
sudo systemctl status tvstreammersat5 --no-pager --full
```

## Конфигурационные файлы

Все изменяемые данные находятся в рабочем каталоге процесса:

```text
tvstreammersat5-config.json       основные настройки и потоки
tvstreammersat5-ui.key            ключ шифрования пароля панели
tvstreammersat5-subscribers.json  абоненты и IP-фильтрация
backup-files/                     загруженные файлы замены
```

Перед обновлением сохраняйте эти файлы. Не публикуйте конфигурацию: она может содержать сетевые адреса, Telegram token и параметры CA-клиентов.

## Параметры UDP и PCR

Для обычного UDP-выхода программа накапливает 1500 мс данных и начинает передачу
с ближайшего независимо декодируемого видеокадра. Если конкретному приёмнику нужен
прежний пятисекундный стартовый запас, задайте переменную окружения:

```bash
TVS_UDP_STARTUP_BUFFER_MS=5000
```

Допустимый диапазон: от `250` до `30000` мс. Переменную следует передать процессу
программы или контейнеру через `docker run -e TVS_UDP_STARTUP_BUFFER_MS=5000 ...`.

Для непрерывных DVB/IP MPEG-TS потоков CBR-выход сохраняет исходный PCR, чтобы
PCR и PTS/DTS оставались в одной временной шкале. Синтетический непрерывный PCR
используется автоматически для сегментированного HLS. Старый режим синтетического
PCR можно принудительно включить переменной:

```bash
TVS_UDP_FORCE_SYNTHETIC_PCR=1
```

## Docker

Сборка и запуск в Docker используют host networking, чтобы корректно работали
multicast, RTP, SRT listener и привязка к сетевым интерфейсам.

### Сборка образа

```bash
docker build --pull -t tvstreammersat5:202.28 .
```

Для полной пересборки без использования слоёв кеша:

```bash
docker build --pull --no-cache -t tvstreammersat5:202.28 .
```

### Фоновый запуск

Укажите постоянный каталог данных на хосте. Если стандартного файла
`tvstreammersat5-config.json` ещё нет, программа создаст его при первом запуске.

```bash
cd ~/Tvstreamer_sat
mkdir -p /opt/tvstreammersat5

CONTAINER_NAME=tvstreammersat5 \
DETACH=1 \
RECREATE=1 \
IMAGE_NAME=tvstreammersat5:202.28 \
CONFIG_FILE=/opt/tvstreammersat5/tvstreammersat5-config.json \
bash ./scripts/run_container.sh

docker ps --filter name=tvstreammersat5
docker logs --tail 100 tvstreammersat5
```

Скрипт проверяет наличие образа до удаления прежнего контейнера и выводит
идентификатор созданного контейнера. `RECREATE=1` позволяет одной командой
заменить существующий контейнер либо создать его, если контейнера ещё нет.
В фоновом режиме действует политика `unless-stopped`. Скрипт использует host
networking, подключает каталог данных и автоматически передаёт найденные
`/dev/dvb` устройства в контейнер.

Новая конфигурация создаётся без каналов с учётными данными `admin` / `admin`.
После первого входа сразу измените пароль.

Интерактивный временный запуск остаётся доступен без `DETACH=1`:

```bash
IMAGE_NAME=tvstreammersat5:202.28 \
CONFIG_FILE=/opt/tvstreammersat5/tvstreammersat5-config.json \
./scripts/run_container.sh
```

### Управление контейнером

`docker restart` перезапускает уже существующий контейнер с тем же образом.
После пересборки образа эту команду использовать недостаточно: контейнер нужно
удалить и создать заново по инструкции следующего раздела.

```bash
# Состояние контейнера
docker ps -a --filter name=tvstreammersat5

# Текущие и последние 200 строк журнала
docker logs --tail 200 tvstreammersat5
docker logs --tail 200 -f tvstreammersat5

# Перезапуск
docker restart tvstreammersat5

# Остановка и повторный запуск
docker stop tvstreammersat5
docker start tvstreammersat5

# Проверка параметров и состояния
docker inspect tvstreammersat5
```

### Обновление и пересборка проекта

Выполняйте весь блок из корня репозитория. Новый образ сначала полностью
собирается и проверяется Docker, и только затем скрипт заменяет контейнер.

```bash
cd ~/Tvstreamer_sat

git pull origin main
docker build --pull -t tvstreammersat5:202.28 .

CONTAINER_NAME=tvstreammersat5 \
DETACH=1 \
RECREATE=1 \
IMAGE_NAME=tvstreammersat5:202.28 \
CONFIG_FILE=/opt/tvstreammersat5/tvstreammersat5-config.json \
bash ./scripts/run_container.sh

# Контейнер должен иметь состояние Up
docker ps --filter name=tvstreammersat5 \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'

# Проверка запуска программы
docker logs --tail 100 tvstreammersat5
curl --fail http://127.0.0.1:9000/health
```

Если скрипт завершился ошибкой до строки `Removing existing container`, старый
контейнер остаётся на месте. Сообщение укажет причину, например недоступный образ
или некорректный путь пользовательского конфигурационного файла.

Конфигурация, ключ UI, список абонентов и файлы замены сохраняются на хосте в
каталоге рядом с `CONFIG_FILE`, поэтому удаление и повторное создание контейнера
их не удаляет.

Проверка после пересборки:

```bash
docker ps -a --filter name=tvstreammersat5
docker ps --filter name=tvstreammersat5
docker logs --tail 100 tvstreammersat5
curl --fail http://127.0.0.1:9000/health
```

## Проверка и диагностика

Проверка HTTP-сервера без авторизации:

```bash
curl http://127.0.0.1:9000/health
```

Проверка GStreamer:

```bash
./scripts/check_transcoder_plugins.sh
gst-inspect-1.0 dvbsrc
gst-inspect-1.0 mpegtsmux
```

Для подробного журнала GStreamer:

```bash
GST_DEBUG=2 ./build/TVStreammerSAT5
```

Если DVB frontend занят, проверьте другие процессы и убедитесь, что каналы на одном физическом frontend настроены на один транспондер. Если нет транскодирования, запустите `scripts/check_transcoder_plugins.sh` и проверьте наличие подходящих видео- и аудиоэнкодеров.

## Лицензии сторонних компонентов

Исходники OSCam-mini находятся в `third_party/oscam-mini` вместе с собственными файлами лицензии и сведениями об upstream revision. Лицензии остальных библиотек определяются установленными системными пакетами.

## Контакты

Поддержка: [monkipnet@gmail.com](mailto:monkipnet@gmail.com)
