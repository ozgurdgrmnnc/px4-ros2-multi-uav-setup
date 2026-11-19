# Kurulum Kılavuzu (Türkçe)

**Ubuntu 24.04 (WSL2 veya normal kurulum)** üzerinde PX4 + ROS 2 Jazzy + Gazebo Harmonic ile
çoklu İHA simülasyonu. Komutların hepsi Ubuntu terminaline yazılır (Windows'ta "Ubuntu" uygulaması).

## 1. Kurulum

```bash
git clone https://github.com/ozgurdgrmnnc/px4-ros2-multi-uav-setup.git
cd px4-ros2-multi-uav-setup
./install.sh
```

Script sırayla şunları kurar (sudo şifresi ister, başlamadan önce onay sorar):

1. **ROS 2 Jazzy + Gazebo köprüsü** (`ros-jazzy-desktop`, `ros-jazzy-ros-gz`, colcon)
2. **PX4-Autopilot**: klonlar, PX4'ün kendi `ubuntu.sh` scriptini çalıştırır (Gazebo Harmonic'i de kurar), SITL'i derler. İlk derleme uzun sürer.
3. **Micro XRCE-DDS Agent v2.4.3**: PX4 ile ROS 2 arasındaki köprü
4. **ROS 2 workspace** (`~/px4_ws`): `px4_msgs`'i indirir ve mesajları **senin PX4 sürümünden** kopyalayıp derler
5. `~/.bashrc`: her terminalde ROS 2 otomatik `source` edilir

İlk kurulumdan sonra terminali yeniden başlat. WSL kullanıyorsan Windows PowerShell'de `wsl --shutdown` yaz, Ubuntu'yu tekrar aç.

Tek bir adımı çalıştırmak için: `./install.sh ros`, `./install.sh px4`, `./install.sh agent`, `./install.sh ws`

## 2. Kontrol

```bash
./scripts/check_setup.sh
```

Eksik olan her şeyi `[MISS]` diye ve nasıl düzeltileceğiyle birlikte yazar. Hiçbir şeyi değiştirmez.

## 3. Çoklu İHA başlatma

```bash
./scripts/multi_uav.sh 3          # 3 drone (en fazla ~5 önerilir)
HEADLESS=1 ./scripts/multi_uav.sh 3   # Gazebo penceresi olmadan (WSL'de çok daha hızlı)
./scripts/stop_all.sh             # kapatmak için HER ZAMAN bunu kullan
```

- Her drone'un topic'leri `/uav_0/...`, `/uav_1/...` altında olur.
- Drone'lar 20-40 saniye içinde görünür: `ros2 topic list | grep uav_`
- Sadece tmux'u kapatmak yetmez: Gazebo arkada açık kalır ve bir sonraki açılışta çakışır.

### tmux tuşları
| Tuş | İş |
|---|---|
| `Ctrl+b n` / `Ctrl+b p` | sonraki / önceki pencere |
| `Ctrl+b 0` | agent penceresi |
| `Ctrl+b d` | tmux'tan çık (simülasyon arkada çalışır) |
| `tmux attach -t uavs` | tekrar bağlan |

## 4. Bilmen gereken 5 şey

1. **px4_msgs, PX4 sürümüyle eşleşmeli.** Eşleşmezse topic'ler hiç gelmez, hata da vermez. PX4'ü güncellediysen `./install.sh ws` tekrar çalıştır.
2. **QoS:** PX4 `/fmu/out/*` topic'lerini BEST_EFFORT yayınlar. Senin subscriber'ın da BEST_EFFORT olmalı.
3. **NED / ENU:** PX4'te z aşağı pozitif (NED), ROS/Gazebo'da z yukarı (ENU). Konum ve yaw'ı çevirmeyi unutma.
4. **Offboard:** `OffboardControlMode` + `TrajectorySetpoint` mesajlarını sürekli (en az 2 Hz, tercihen 10 Hz) gönder. Akış kesilirse PX4 failsafe'e geçer.
5. `NAV_DLL_ACT=0` ve `COM_RC_IN_MODE=4` yer istasyonu ve kumanda şartını kaldırır. **Sadece simülasyon için.**

## 5. Sorun giderme

| Sorun | Çözüm |
|---|---|
| `/uav_*` topic'i yok | agent penceresinde bağlantı var mı? (`Ctrl+b 0`) |
| Drone arm olmuyor | `px4_i` penceresinde `Preflight Fail` yazıyor mu? |
| `ros2 topic list` eski bilgi gösteriyor | `ros2 daemon stop` |
| "session already running" | `./scripts/stop_all.sh` |
| Simülasyon çok yavaş | `HEADLESS=1` ya da daha az drone |
