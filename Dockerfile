FROM nvidia/cuda:11.6.1-devel-ubuntu20.04 AS build-stage

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

RUN apt-get update && apt-get -y install \
    autoconf \
    automake \
    build-essential \
    cmake \
    git-core \
    libass-dev \
    libfreetype6-dev \
    libgnutls28-dev \
    libmp3lame-dev \
    libsdl2-dev \
    libtool \
    libva-dev \
    libvdpau-dev \
    libvorbis-dev \
    libxcb1-dev \
    libxcb-shm0-dev \
    libxcb-xfixes0-dev \
    meson \
    ninja-build \
    pkg-config \
    texinfo \
    wget \
    yasm \
    zlib1g-dev \
    libunistring-dev \
    nasm \
    python3-pip \
    apt-utils

WORKDIR /root
RUN mkdir -p ffmpeg_sources bin output

# libdav1d 
RUN pip3 install --user meson && \
    cd /root/ffmpeg_sources && \
    git -C dav1d pull 2> /dev/null || git clone --depth 1 https://code.videolan.org/videolan/dav1d.git && \
    mkdir -p dav1d/build && \
    cd dav1d/build && \
    meson setup -Denable_tools=false -Denable_tests=false --default-library=static .. --prefix "/root/ffmpeg_build" --libdir="/root/ffmpeg_build/lib" && \
    ninja && \
    ninja install

# libvmaf
RUN cd /root/ffmpeg_sources && \
    wget https://github.com/Netflix/vmaf/archive/v2.1.1.tar.gz && \
    tar xvf v2.1.1.tar.gz && \
    mkdir -p vmaf-2.1.1/libvmaf/build &&\
    cd vmaf-2.1.1/libvmaf/build && \
    meson setup -Denable_tests=false -Denable_docs=false --buildtype=release --default-library=static .. --prefix "/root/ffmpeg_build" --bindir="../bin" --libdir="/root/ffmpeg_build/lib" && \
    ninja && \
    ninja install

# libzimg
RUN cd /root/ffmpeg_sources && \
    wget https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.2.tar.gz && \
    tar xvf release-3.0.2.tar.gz && \
    cd zimg-release-3.0.2 && \
    ./autogen.sh && \
    ./configure --prefix="/root/ffmpeg_build" --enable-static --enable-shared=no && \
    make && \
    make install

# ffnvcodec
RUN cd /root/ffmpeg_sources && \
    git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git && \
    cd nv-codec-headers && make install

# build ffmpeg
RUN apt-get install -y frei0r-plugins-dev libopencore-amrwb-dev libopenjp2-7-dev librubberband-dev libsoxr-dev \
    libx264-dev libx265-dev libvpx-dev libopus-dev libaom-dev libxml2-dev liblzma-dev\
    libspeex-dev libsrt-dev libssl-dev libtheora-dev libvidstab-dev libvo-amrwbenc-dev \
    libwebp-dev libxvidcore-dev libzvbi-dev libgme-dev libopencore-amrnb-dev \
    libc6 libc6-dev unzip libnuma1 libnuma-dev

ENV PATH="/root/bin:$PATH"
ENV PKG_CONFIG_PATH="/root/ffmpeg_build/lib/pkgconfig"
RUN cd /root/ffmpeg_sources && \
    wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
    tar xjvf ffmpeg-snapshot.tar.bz2 && \
    cd ffmpeg && \
    ./configure \
    --prefix="/root/output" \
    --pkg-config-flags="--static" \
    --extra-cflags="-I/root/ffmpeg_build/include -I/usr/local/cuda/include" \
    --extra-ldflags="-L/root/ffmpeg_build/lib -L/usr/local/cuda/lib64" \
    --extra-libs="-lpthread -lm" \
    --ld="g++" \
    --enable-gpl \
    --enable-version3 \
    --enable-static \
    --disable-debug \
    --disable-ffplay \
    --disable-indev=sndio \
    --disable-outdev=sndio \
    --cc=gcc \
    --enable-fontconfig \
    --enable-gnutls \
    --enable-gmp \
    --enable-frei0r \
    --enable-libgme \
    --enable-gray \
    --enable-libaom \
    --enable-libfribidi \
    --enable-libass \
    --enable-libvmaf \
    --enable-libfreetype \
    --enable-libmp3lame \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libopenjpeg \
    --enable-librubberband \
    --enable-libsoxr \
    --enable-libspeex \
    --enable-libsrt \
    --enable-libvorbis \
    --enable-libopus \
    --enable-libtheora \
    --enable-libvidstab \
    --enable-libvo-amrwbenc \
    --enable-libvpx \
    --enable-libwebp \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libxml2 \
    --enable-libdav1d \
    --enable-libxvid \
    --enable-libzvbi \
    --enable-libzimg \
    --enable-nonfree \
    --enable-cuda-nvcc \
    --enable-libnpp && \
    PATH="$HOME/bin:$PATH" make && \
    make install

RUN mv output ffmpeg-with-gpu && tar -zcvf ffmpeg-with-gpu.tar.gz ffmpeg-with-gpu

FROM scratch AS export-stage
COPY --from=build-stage /root/ffmpeg-with-gpu.tar.gz /
