# syntax=docker/dockerfile:1

FROM ubuntu:latest AS builder

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get install -y \
        tzdata \
        curl \
        openjdk-25-jdk \
        unzip \
        gpg

WORKDIR /root

# Android SDK
ENV ANDROID_HOME=/android/sdk
RUN mkdir -p /android/sdk/cmdline-tools
ARG COMMANDLINETOOLS_NAME=commandlinetools-linux-13114758_latest
RUN curl -fSLO https://dl.google.com/android/repository/${COMMANDLINETOOLS_NAME}.zip \
    && unzip -q ${COMMANDLINETOOLS_NAME}.zip \
    && mv cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm ${COMMANDLINETOOLS_NAME}.zip
ENV PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH
RUN yes | sdkmanager --licenses

# Android NDK
ARG NDK_VERSION=27.3.13750724
RUN sdkmanager "ndk;${NDK_VERSION}"
ENV ANDROID_NDK_HOME=${ANDROID_HOME}/ndk/${NDK_VERSION}

# JDK
# ENVコマンドではサブシェルを利用出来ずアーキテクチャ判定が出来ないため、シンボリックリンクを利用
RUN ln -s $(ls -d /usr/lib/jvm/java-25-openjdk-*) /usr/lib/jvm/java
ENV JAVA_HOME=/usr/lib/jvm/java

# Swiftly
RUN curl -O https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz \
    && tar zxf swiftly-$(uname -m).tar.gz \
    && ./swiftly init --assume-yes --no-modify-profile --skip-install --quiet-shell-followup
ENV SWIFTLY_HOME_DIR=/root/.local/share/swiftly
ENV SWIFTLY_BIN_DIR=$SWIFTLY_HOME_DIR/bin
ENV SWIFTLY_TOOLCHAINS_DIR=$SWIFTLY_HOME_DIR/toolchains
ENV PATH=$SWIFTLY_BIN_DIR:$PATH

ENV SWIFT_VERSION=swift-6.3-DEVELOPMENT-SNAPSHOT-2026-01-03-a
RUN swiftly install \
        ${SWIFT_VERSION} \
        --post-install-file swiftly-postinstall.sh \
    && apt-get -q update \
    && bash swiftly-postinstall.sh

# Swift SDK for Android
# https://www.swift.org/install/linux/ からインストールコマンドを取得
RUN swift sdk install https://download.swift.org/swift-6.3-branch/android-sdk/swift-6.3-DEVELOPMENT-SNAPSHOT-2026-01-03-a/swift-6.3-DEVELOPMENT-SNAPSHOT-2026-01-03-a_android.artifactbundle.tar.gz --checksum ca7cc00ca7483cbb8b2005f864d33975177c8d2ca34d59ac841c9545916c302f
ENV SWIFT_SDK_NAME=swift-6.3-DEVELOPMENT-SNAPSHOT-2026-01-03-a_android.artifactbundle

# Swift SDK for AndroidとNDKをリンクさせるセットアップ
RUN ${HOME}/.swiftpm/swift-sdks/${SWIFT_SDK_NAME}/swift-android/scripts/setup-android-sdk.sh
