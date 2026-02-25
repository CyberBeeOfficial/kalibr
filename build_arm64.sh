#!/bin/bash
# Build script for Kalibr ARM64 Docker image with custom VINS-Mono tuning
# Usage: ./build_arm64.sh [--push]

set -e

DOCKER_REPO="maxcyberbee/kalibr"
IMAGE_TAG="arm64"
DOCKERFILE="Dockerfile_ros1_arm64_tuned"

echo "=== Kalibr ARM64 Docker Build (VINS-Mono Tuned) ==="
echo ""

# Check if we should push
PUSH=false
if [[ "$1" == "--push" ]]; then
    PUSH=true
    echo "Will push to $DOCKER_REPO:$IMAGE_TAG after build"
fi

# Ensure buildx is set up for ARM64
if ! docker buildx inspect arm64-builder &>/dev/null; then
    echo "Creating buildx builder for ARM64..."
    docker buildx create --name arm64-builder --platform linux/arm64,linux/amd64 --driver docker-container
fi
docker buildx use arm64-builder

echo ""
echo "Building ARM64 image with platform-aware tuning..."
echo "  ARM64: splineOrder=4, poseKnots/s=30, biasKnots/s=30 (memory-safe)"
echo "  x86:   splineOrder=6, poseKnots/s=50, biasKnots/s=50 (high-precision)"
echo "  Fine-tune ARM: poseKnots/s=20, biasKnots/s=20 (minimal problem)"
echo "  Optimized for 10-15Hz camera + 100Hz IMU + VINS-Mono"
echo ""

# Build the tuned image
docker buildx build \
    --platform linux/arm64 \
    -f "$DOCKERFILE" \
    -t "$DOCKER_REPO:$IMAGE_TAG" \
    --load \
    .

echo ""
echo "=== Build Complete ==="
echo "Image: $DOCKER_REPO:$IMAGE_TAG"

# Push if requested
if [[ "$PUSH" == true ]]; then
    echo ""
    echo "Pushing to Docker Hub..."
    docker push "$DOCKER_REPO:$IMAGE_TAG"
    echo "Pushed to: $DOCKER_REPO:$IMAGE_TAG"
fi

echo ""
echo "=== Usage ==="
echo "Pull on Pi 5:"
echo "  docker pull $DOCKER_REPO:$IMAGE_TAG"
echo ""
echo "Run calibration:"
echo "  docker run -it -v \$(pwd)/data:/data $DOCKER_REPO:$IMAGE_TAG"
echo "  rosrun kalibr kalibr_calibrate_imu_camera --bag /data/calib.bag --cam /data/cam.yaml --imu /data/imu.yaml --target /data/target.yaml"
