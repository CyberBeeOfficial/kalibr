# Kalibr ARM64 Docker Usage Guide

Docker image for IMU-Camera calibration optimized for VINS-Mono on ARM64 (Raspberry Pi 5).

**Docker Hub:** `maxcyberbee/kalibr:arm64`

---

## Table of Contents
- [Quick Start](#quick-start)
- [Volume Mounting](#volume-mounting)
- [Running Modes](#running-modes)
- [Calibration Modes](#calibration-modes)
- [Docker Compose](#docker-compose)
- [Command Reference](#command-reference)
- [Configuration Files](#configuration-files)
- [Workflows](#workflows)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

```bash
# Pull the image
docker pull maxcyberbee/kalibr:arm64

# Run calibration (automatic mode)
docker run -it -v $(pwd)/data:/data maxcyberbee/kalibr:arm64 \
    rosrun kalibr kalibr_calibrate_imu_camera \
    --bag /data/calib.bag \
    --cams /data/camchain.yaml \
    --imu /data/imu.yaml \
    --target /data/target.yaml
```

---

## Volume Mounting

### Basic Volume Mount
```bash
# Mount local ./data folder to /data inside container
docker run -it -v $(pwd)/data:/data maxcyberbee/kalibr:arm64
```

### Multiple Volumes
```bash
docker run -it \
    -v $(pwd)/bags:/bags \
    -v $(pwd)/configs:/configs \
    -v $(pwd)/results:/results \
    maxcyberbee/kalibr:arm64
```

### Read-Only Configs (Recommended for Production)
```bash
docker run -it \
    -v $(pwd)/bags:/bags:ro \
    -v $(pwd)/configs:/configs:ro \
    -v $(pwd)/results:/results \
    maxcyberbee/kalibr:arm64
```

### Recommended Directory Structure
```
project/
├── data/
│   ├── bags/           # ROS bag files
│   │   └── calib.bag
│   ├── configs/        # Configuration files
│   │   ├── camchain.yaml
│   │   ├── imu.yaml
│   │   └── target.yaml
│   └── results/        # Output files (auto-generated)
│       ├── calib-camchain-imucam.yaml
│       ├── calib-imu.yaml
│       └── calib-report-imucam.pdf
└── docker-compose.yml
```

---

## Running Modes

### Mode 1: Automatic (Single Command)

Run calibration and exit automatically:

```bash
docker run --rm -v $(pwd)/data:/data maxcyberbee/kalibr:arm64 \
    rosrun kalibr kalibr_calibrate_imu_camera \
    --bag /data/bags/calib.bag \
    --cams /data/configs/camchain.yaml \
    --imu /data/configs/imu.yaml \
    --target /data/configs/target.yaml \
    --dont-show-report
```

**Use case:** CI/CD pipelines, batch processing, automated calibration stations.

### Mode 2: Interactive Shell

Enter container and run commands manually:

```bash
# Start interactive shell
docker run -it -v $(pwd)/data:/data maxcyberbee/kalibr:arm64

# Inside container - you now have full control
rosrun kalibr kalibr_calibrate_imu_camera --help

# Run calibration manually
rosrun kalibr kalibr_calibrate_imu_camera \
    --bag /data/bags/calib.bag \
    --cams /data/configs/camchain.yaml \
    --imu /data/configs/imu.yaml \
    --target /data/configs/target.yaml

# Inspect results
cat /data/bags/calib-camchain-imucam.yaml

# Exit when done
exit
```

**Use case:** Development, debugging, exploring options, manual inspection.

### Mode 3: Background/Detached

Run calibration in background:

```bash
# Start in background
docker run -d --name kalibr_calib \
    -v $(pwd)/data:/data \
    maxcyberbee/kalibr:arm64 \
    rosrun kalibr kalibr_calibrate_imu_camera \
    --bag /data/calib.bag \
    --cams /data/camchain.yaml \
    --imu /data/imu.yaml \
    --target /data/target.yaml \
    --dont-show-report

# Check progress
docker logs -f kalibr_calib

# Wait for completion
docker wait kalibr_calib

# Clean up
docker rm kalibr_calib
```

**Use case:** Long-running calibrations, remote servers, unattended operation.

### Mode 4: With Display (GUI)

For viewing reports and visualizations:

```bash
# Linux with X11
docker run -it \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v $(pwd)/data:/data \
    maxcyberbee/kalibr:arm64

# macOS with XQuartz
xhost +localhost
docker run -it \
    -e DISPLAY=host.docker.internal:0 \
    -v $(pwd)/data:/data \
    maxcyberbee/kalibr:arm64
```

---

## Calibration Modes

### Standard Calibration (Full)

For first-time calibration of a new sensor setup:

```bash
docker run -it -v $(pwd)/data:/data maxcyberbee/kalibr:arm64 \
    rosrun kalibr kalibr_calibrate_imu_camera \
    --bag /data/calib.bag \
    --cams /data/camchain.yaml \
    --imu /data/imu.yaml \
    --target /data/target.yaml \
    --max-iter 50
```

### Fine-Tune Mode

For refining an existing calibration (e.g., client site adjustments):

```bash
docker run -it -v $(pwd)/data:/data maxcyberbee/kalibr:arm64 \
    rosrun kalibr kalibr_calibrate_imu_camera \
    --bag /data/client_data.bag \
    --cams /data/baseline_calibration.yaml \
    --imu /data/imu.yaml \
    --target /data/target.yaml \
    --fine-tune
```

### Fine-Tune with Locked Extrinsics

When only time offset needs adjustment (fixed physical mounting):

```bash
docker run -it -v $(pwd)/data:/data maxcyberbee/kalibr:arm64 \
    rosrun kalibr kalibr_calibrate_imu_camera \
    --bag /data/client_data.bag \
    --cams /data/baseline_calibration.yaml \
    --imu /data/imu.yaml \
    --target /data/target.yaml \
    --fine-tune \
    --lock-imu-cam-extrinsics
```

### Comparison Table

| Mode | Time Offset Range | IMU-Cam Extrinsics | Max Iterations | Use Case |
|------|------------------|-------------------|----------------|----------|
| Standard | 30ms | Estimated | 300 | New setup |
| Fine-Tune | 5ms | Estimated | 50 | Client refinement |
| Fine-Tune + Lock | 5ms | Locked | 50 | Time drift only |

---

## Docker Compose

### docker-compose.yml

```yaml
version: '3.8'

services:
  # Interactive calibration shell
  kalibr:
    image: maxcyberbee/kalibr:arm64
    container_name: kalibr_interactive
    stdin_open: true
    tty: true
    volumes:
      - ./data:/data
    working_dir: /data

  # Automatic full calibration
  calibrate-full:
    image: maxcyberbee/kalibr:arm64
    container_name: kalibr_full_calib
    volumes:
      - ./data:/data
    command: >
      rosrun kalibr kalibr_calibrate_imu_camera
      --bag /data/bags/calib.bag
      --cams /data/configs/camchain.yaml
      --imu /data/configs/imu.yaml
      --target /data/configs/target.yaml
      --max-iter 50
      --dont-show-report

  # Fine-tune calibration
  calibrate-finetune:
    image: maxcyberbee/kalibr:arm64
    container_name: kalibr_finetune
    volumes:
      - ./data:/data
    command: >
      rosrun kalibr kalibr_calibrate_imu_camera
      --bag /data/bags/calib.bag
      --cams /data/configs/baseline.yaml
      --imu /data/configs/imu.yaml
      --target /data/configs/target.yaml
      --fine-tune
      --dont-show-report

  # Time-offset only calibration
  calibrate-timeonly:
    image: maxcyberbee/kalibr:arm64
    container_name: kalibr_timeonly
    volumes:
      - ./data:/data
    command: >
      rosrun kalibr kalibr_calibrate_imu_camera
      --bag /data/bags/calib.bag
      --cams /data/configs/baseline.yaml
      --imu /data/configs/imu.yaml
      --target /data/configs/target.yaml
      --fine-tune
      --lock-imu-cam-extrinsics
      --dont-show-report

  # Camera-only calibration
  calibrate-camera:
    image: maxcyberbee/kalibr:arm64
    container_name: kalibr_camera
    volumes:
      - ./data:/data
    command: >
      rosrun kalibr kalibr_calibrate_cameras
      --bag /data/bags/calib.bag
      --topics /camera/image_raw
      --models pinhole-radtan
      --target /data/configs/target.yaml
      --dont-show-report
```

### Docker Compose Usage

```bash
# Interactive mode
docker-compose run kalibr

# Run full calibration
docker-compose up calibrate-full

# Run fine-tune calibration
docker-compose up calibrate-finetune

# Run time-offset only calibration
docker-compose up calibrate-timeonly

# Run camera-only calibration
docker-compose up calibrate-camera

# Run in background
docker-compose up -d calibrate-full
docker-compose logs -f calibrate-full

# Clean up
docker-compose down
```

---

## Command Reference

### Dataset Options
| Option | Description |
|--------|-------------|
| `--bag FILE` | ROS bag file with camera and IMU data |
| `--bag-from-to START END` | Use only data from START to END seconds |
| `--bag-freq HZ` | Feature extraction frequency |

### Configuration Files
| Option | Description |
|--------|-------------|
| `--cams FILE` | Camera chain YAML (from kalibr_calibrate_cameras) |
| `--imu FILE` | IMU noise parameters YAML |
| `--target FILE` | Calibration target YAML (AprilGrid/Checkerboard) |

### Optimization Options
| Option | Default | Description |
|--------|---------|-------------|
| `--max-iter N` | 30 | Maximum optimization iterations |
| `--no-time-calibration` | off | Disable temporal calibration |
| `--timeoffset-padding SEC` | 0.03 | Time offset search range |
| `--recover-covariance` | off | Compute parameter uncertainties |

### Fine-Tuning Options
| Option | Default | Description |
|--------|---------|-------------|
| `--fine-tune` | off | Enable fine-tune mode |
| `--lock-imu-cam-extrinsics` | off | Lock IMU-camera transform |
| `--fine-tune-timeoffset-padding` | 0.005 | Tighter time bounds (5ms) |
| `--fine-tune-max-iter` | 50 | Fewer iterations needed |

### Output Options
| Option | Description |
|--------|-------------|
| `--verbose` | Detailed output |
| `--show-extraction` | Show target detection |
| `--dont-show-report` | Skip PDF report display |
| `--export-poses` | Export optimized poses to CSV |

---

## Configuration Files

### IMU Configuration (imu.yaml)
```yaml
# For typical consumer MEMS IMU (MPU6050, ICM20948, BMI088)
# Run Allan variance analysis on YOUR IMU for accurate values!
accelerometer_noise_density: 0.01      # [m/s^2/sqrt(Hz)]
accelerometer_random_walk: 0.0002      # [m/s^3/sqrt(Hz)]
gyroscope_noise_density: 0.001         # [rad/s/sqrt(Hz)]
gyroscope_random_walk: 2.0e-05         # [rad/s^2/sqrt(Hz)]
update_rate: 100.0                     # [Hz]
rostopic: /imu/data
```

### Camera Configuration (camchain.yaml)
```yaml
cam0:
  camera_model: pinhole
  intrinsics: [458.654, 457.296, 367.215, 248.375]  # fx, fy, cx, cy
  distortion_model: radtan
  distortion_coeffs: [-0.28340811, 0.07395907, 0.00019359, 1.76187114e-05]
  resolution: [752, 480]
  rostopic: /camera/image_raw
```

### AprilGrid Target (target.yaml)
```yaml
target_type: 'aprilgrid'
tagCols: 6
tagRows: 6
tagSize: 0.088          # [m] - size of one tag
tagSpacing: 0.3         # ratio of spacing to tag size
```

---

## Workflows

### Workflow 1: Factory Calibration + Client Fine-Tuning

**Step 1: Factory Full Calibration**
```bash
docker-compose run kalibr

# Inside container:
rosrun kalibr kalibr_calibrate_imu_camera \
    --bag /data/bags/factory_calib.bag \
    --cams /data/configs/camchain.yaml \
    --imu /data/configs/imu.yaml \
    --target /data/configs/target.yaml \
    --max-iter 100 \
    --recover-covariance

# Copy result as baseline
cp /data/bags/factory_calib-camchain-imucam.yaml /data/configs/baseline.yaml
```

**Step 2: Client Site Fine-Tuning**
```bash
docker-compose up calibrate-finetune
```

### Workflow 2: Automated Batch Calibration

```bash
#!/bin/bash
# batch_calibrate.sh

for bagfile in data/bags/*.bag; do
    echo "Processing: $bagfile"
    docker run --rm -v $(pwd)/data:/data maxcyberbee/kalibr:arm64 \
        rosrun kalibr kalibr_calibrate_imu_camera \
        --bag /data/bags/$(basename $bagfile) \
        --cams /data/configs/camchain.yaml \
        --imu /data/configs/imu.yaml \
        --target /data/configs/target.yaml \
        --fine-tune \
        --dont-show-report
done
```

### Workflow 3: CI/CD Integration

```yaml
# .github/workflows/calibrate.yml
name: Calibration
on: [push]
jobs:
  calibrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run calibration
        run: |
          docker run --rm \
            -v ${{ github.workspace }}/data:/data \
            maxcyberbee/kalibr:arm64 \
            rosrun kalibr kalibr_calibrate_imu_camera \
            --bag /data/calib.bag \
            --cams /data/camchain.yaml \
            --imu /data/imu.yaml \
            --target /data/target.yaml \
            --dont-show-report
      - uses: actions/upload-artifact@v3
        with:
          name: calibration-results
          path: data/*-camchain-imucam.yaml
```

---

## Output Files

After calibration, these files are generated in the same directory as the bag file:

| File | Description |
|------|-------------|
| `*-camchain-imucam.yaml` | Camera chain with IMU-camera extrinsics |
| `*-imu.yaml` | IMU calibration parameters |
| `*-results-imucam.txt` | Detailed calibration results |
| `*-report-imucam.pdf` | Visual report with plots |

---

## Raspberry Pi 5 Specific

### Memory Management
```bash
# Add swap before calibration (4GB Pi)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Run with memory limit
docker run -it --memory=3g -v $(pwd)/data:/data maxcyberbee/kalibr:arm64
```

### Headless Operation
```bash
docker run --rm -v $(pwd)/data:/data maxcyberbee/kalibr:arm64 \
    rosrun kalibr kalibr_calibrate_imu_camera \
    --bag /data/calib.bag \
    --cams /data/camchain.yaml \
    --imu /data/imu.yaml \
    --target /data/target.yaml \
    --dont-show-report
```

---

## Troubleshooting

### Permission Issues
```bash
# Run with your user ID
docker run -it --user $(id -u):$(id -g) -v $(pwd)/data:/data maxcyberbee/kalibr:arm64
```

### Entrypoint Issues
```bash
# Bypass entrypoint for debugging
docker run -it --entrypoint="" -v $(pwd)/data:/data maxcyberbee/kalibr:arm64 bash
source /opt/ros/noetic/setup.bash
source /catkin_ws/devel/setup.bash
rosrun kalibr kalibr_calibrate_imu_camera --help
```

### Out of Memory
```bash
# Reduce parallelism in calibration
docker run -it --memory=3g -v $(pwd)/data:/data maxcyberbee/kalibr:arm64 \
    rosrun kalibr kalibr_calibrate_imu_camera \
    --bag /data/calib.bag \
    --cams /data/camchain.yaml \
    --imu /data/imu.yaml \
    --target /data/target.yaml \
    --bag-freq 5  # Lower frequency reduces memory
```

### View Container Logs
```bash
docker logs kalibr_calib
docker logs -f kalibr_calib  # Follow logs
```

---

## Building the Image

### Quick Build (From Pre-built Base)
```bash
./build_arm64.sh --push
```

### Full Build (From Scratch)
```bash
docker buildx build --platform linux/arm64 \
    -f Dockerfile_ros1_arm64 \
    -t kalibr:arm64-full \
    --load .
```
