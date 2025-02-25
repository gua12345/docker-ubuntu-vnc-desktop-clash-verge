# Built with arch: arm64 flavor: lxde image: ubuntu:20.04

################################################################################
# base system
################################################################################
# qemu helper for arm build
FROM ubuntu:20.04 as amd64
RUN apt update && apt install -y qemu-user-static

FROM arm64v8/ubuntu:20.04 as system
COPY --from=amd64 /usr/bin/qemu-aarch64-static /usr/bin/
RUN sed -i 's#http://archive.ubuntu.com/ubuntu/#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list

# built-in packages
ENV DEBIAN_FRONTEND noninteractive
RUN apt update \
    && apt install -y --no-install-recommends software-properties-common curl apache2-utils \
    && apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        supervisor nginx sudo net-tools zenity xz-utils \
        dbus-x11 x11-utils alsa-utils \
        mesa-utils libgl1-mesa-dri \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# 安装额外的应用程序
RUN apt update \
    && apt install -y --no-install-recommends \
        xvfb x11vnc \
        vim-tiny firefox chromium-browser ttf-ubuntu-font-family ttf-wqy-zenhei \
    && add-apt-repository -r ppa:fcwu-tw/apps \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN apt update \
    && apt install -y --no-install-recommends \
        lxde gtk2-engines-murrine gnome-themes-standard gtk2-engines-pixbuf gtk2-engines-murrine arc-theme \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# 安装 Clash Verge 的依赖包
RUN apt-get update && apt-get install -y --no-install-recommends \
    libayatana-appindicator3-1 \
    libwebkit2gtk-4.0-37 \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 下载并安装 Clash Verge 的 .deb 包
RUN wget https://github.com/clash-verge-rev/clash-verge-rev/releases/download/v1.7.7/clash-verge_1.7.7_arm64.deb -O /tmp/clash-verge_1.7.7_arm64.deb \
    && dpkg -i /tmp/clash-verge_1.7.7_arm64.deb \
    && apt-get install -f -y \
    && rm /tmp/clash-verge_1.7.7_arm64.deb

# Additional packages require ~600MB
# libreoffice pinta language-pack-zh-hant language-pack-gnome-zh-hant firefox-locale-zh-hant libreoffice-l10n-zh-tw
# tini for subreap
ARG TINI_VERSION=v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-arm64 /bin/tini
RUN chmod +x /bin/tini

# ffmpeg
RUN apt update \
    && apt install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /usr/local/ffmpeg \
    && ln -s /usr/bin/ffmpeg /usr/local/ffmpeg/ffmpeg

# python library
COPY rootfs/usr/local/lib/web/backend/requirements.txt /tmp/
RUN apt-get update \
    && dpkg-query -W -f='${Package}\n' > /tmp/a.txt \
    && apt-get install -y python3-pip python3-dev build-essential \
    && pip3 install setuptools wheel && pip3 install -r /tmp/requirements.txt \
    && ln -s /usr/bin/python3 /usr/local/bin/python \
    && dpkg-query -W -f='${Package}\n' > /tmp/b.txt \
    && apt-get remove -y `diff --changed-group-format='%>' --unchanged-group-format='' /tmp/a.txt /tmp/b.txt | xargs` \
    && apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* /tmp/a.txt /tmp/b.txt

################################################################################
# builder
################################################################################
FROM ubuntu:20.04 as builder
RUN sed -i 's#http://archive.ubuntu.com/ubuntu/#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates gnupg patch

# nodejs
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - \
    && apt-get install -y nodejs

# yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn

# build frontend
COPY web /src/web
RUN cd /src/web \
    && yarn \
    && yarn build \
    && echo "---- 构建输出目录 ----" \
    && ls -R /src/web/dist

# 检查是否生成了 novnc/app/ui.js
RUN if [ -f /src/web/dist/static/novnc/app/ui.js ]; then \
        echo "文件存在，继续执行 sed 和 patch"; \
    else \
        echo "错误: /src/web/dist/static/novnc/app/ui.js 不存在" && exit 1; \
    fi

RUN sed -i 's#app/locale/#novnc/app/locale/#' /src/web/dist/static/novnc/app/ui.js \
    && cd /src/web/dist/static/novnc \
    && patch -p0 < /src/web/novnc-armhf-1.patch

################################################################################
# merge
################################################################################
FROM system
LABEL maintainer="fcwu.tw@gmail.com"

COPY --from=builder /src/web/dist/ /usr/local/lib/web/frontend/
COPY rootfs /

RUN ln -sf /usr/local/lib/web/frontend/static/websockify /usr/local/lib/web/frontend/static/novnc/utils/websockify && \
    chmod +x /usr/local/lib/web/frontend/static/websockify/run

EXPOSE 80
WORKDIR /root
ENV HOME=/home/ubuntu \
    SHELL=/bin/bash

HEALTHCHECK --interval=30s --timeout=5s CMD curl --fail http://127.0.0.1:6079/api/health

ENTRYPOINT ["/startup.sh"]
