# docker-ubuntu-vnc-desktop

[![Docker Pulls](https://img.shields.io/docker/pulls/dorowu/ubuntu-desktop-lxde-vnc.svg)](https://hub.docker.com/r/dorowu/ubuntu-desktop-lxde-vnc/)
[![Docker Stars](https://img.shields.io/docker/stars/dorowu/ubuntu-desktop-lxde-vnc.svg)](https://hub.docker.com/r/dorowu/ubuntu-desktop-lxde-vnc/)

docker-ubuntu-vnc-desktop 是一个 Docker 镜像，提供了基于 Web 的 VNC 界面以访问 Ubuntu LXDE/LxQT 桌面环境。

<!-- @import "[TOC]" {cmd="toc" depthFrom=2 depthTo=2 orderedList=false} -->

<!-- code_chunk_output -->

- [快速开始](#快速开始)
- [VNC 查看器](#vnc-查看器)
- [HTTP 基础认证](#http-基础认证)
- [SSL](#ssl)
- [屏幕分辨率](#屏幕分辨率)
- [默认桌面用户](#默认桌面用户)
- [部署到子目录（相对 URL 根路径）](#部署到子目录相对-url-根路径)
- [声音（预览版，仅限 Linux）](#声音预览版仅限-linux)
- [从 jinja 模板生成 Dockerfile](#从-jinja-模板生成-dockerfile)
- [故障排查和常见问题](#故障排查和常见问题)
- [许可证](#许可证)

<!-- /code_chunk_output -->

## 快速开始

运行 Docker 容器并通过端口 `6080` 访问：

```shell
docker run -p 6080:80 -v /dev/shm:/dev/shm dorowu/ubuntu-desktop-lxde-vnc
```

浏览器访问 [http://127.0.0.1:6080/](http://127.0.0.1:6080/)

<img src="https://raw.github.com/fcwu/docker-ubuntu-vnc-desktop/master/screenshots/lxde.png?v1" width=700/>

### Ubuntu 版本

通过 [tags](https://hub.docker.com/r/dorowu/ubuntu-desktop-lxde-vnc/tags/) 选择你喜欢的 Ubuntu 版本：

- focal: Ubuntu 20.04（最新）
- focal-lxqt: Ubuntu 20.04 LXQt
- bionic: Ubuntu 18.04
- bionic-lxqt: Ubuntu 18.04 LXQt
- xenial: Ubuntu 16.04（已弃用）
- trusty: Ubuntu 14.04（已弃用）

## VNC 查看器

通过以下命令将 VNC 服务端口 5900 转发到主机：

```shell
docker run -p 6080:80 -p 5900:5900 -v /dev/shm:/dev/shm dorowu/ubuntu-desktop-lxde-vnc
```

然后，打开 VNC 查看器并连接到端口 5900。如果需要为 VNC 服务设置密码，可以设置环境变量 `VNC_PASSWORD`，例如：

```shell
docker run -p 6080:80 -p 5900:5900 -e VNC_PASSWORD=mypassword -v /dev/shm:/dev/shm dorowu/ubuntu-desktop-lxde-vnc
```

在浏览器或 VNC 查看器中会提示输入密码。

## HTTP 基础认证

通过设置 `HTTP_PASSWORD` 环境变量实现 HTTP 的基础访问认证：

```shell
docker run -p 6080:80 -e HTTP_PASSWORD=mypassword -v /dev/shm:/dev/shm dorowu/ubuntu-desktop-lxde-vnc
```

## SSL

如果没有 SSL 证书，可先生成自签名的 SSL 证书：

```shell
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl/nginx.key -out ssl/nginx.crt
```

通过设置 `SSL_PORT` 指定 SSL 端口，将证书路径挂载到 `/etc/nginx/ssl`，并将其转发到 6081：

```shell
docker run -p 6081:443 -e SSL_PORT=443 -v ${PWD}/ssl:/etc/nginx/ssl -v /dev/shm:/dev/shm dorowu/ubuntu-desktop-lxde-vnc
```

## 屏幕分辨率

虚拟桌面的分辨率在首次连接服务器时会自动适配浏览器窗口大小。可以通过设置 `RESOLUTION` 环境变量指定固定分辨率，例如：

```shell
docker run -p 6080:80 -e RESOLUTION=1920x1080 -v /dev/shm:/dev/shm dorowu/ubuntu-desktop-lxde-vnc
```

## 默认桌面用户

默认用户是 `root`。可以通过 `USER` 和 `PASSWORD` 环境变量分别修改用户和密码，例如：

```shell
docker run -p 6080:80 -e USER=doro -e PASSWORD=password -v /dev/shm:/dev/shm dorowu/ubuntu-desktop-lxde-vnc
```

## 部署到子目录（相对 URL 根路径）

可以将此应用程序部署到一个子目录，例如 `/some-prefix/`。然后可通过 `http://127.0.0.1:6080/some-prefix/` 访问应用程序。使用 `RELATIVE_URL_ROOT` 配置选项指定子目录路径，例如：

```shell
docker run -p 6080:80 -e RELATIVE_URL_ROOT=some-prefix dorowu/ubuntu-desktop-lxde-vnc
```

注意：此变量不应包含前导和尾随斜杠（/）。

## 声音（预览版，仅限 Linux）

仅在 Linux 系统中可用。

首先插入内核模块 `snd-aloop` 并将声音环回设备的索引指定为 `2`：

```shell
sudo modprobe snd-aloop index=2
```

启动容器：

```shell
docker run -it --rm -p 6080:80 --device /dev/snd -e ALSADEV=hw:2,0 dorowu/ubuntu-desktop-lxde-vnc
```

`--device /dev/snd -e ALSADEV=hw:2,0` 表示将声音设备授权给容器并设置基础 ALSA 配置以使用设备卡 2。

打开浏览器访问 [http://127.0.0.1:6080/#/?video](http://127.0.0.1:6080/#/?video)，`video` 表示以视频模式启动。现在可以从开始菜单（Internet -> Chromium Web Browser Sound）启动 Chromium 浏览器并尝试播放一些视频。

以下是这些操作的屏幕录像。请在视频末尾打开声音！

[![演示视频](http://img.youtube.com/vi/Kv9FGClP1-k/0.jpg)](http://www.youtube.com/watch?v=Kv9FGClP1-k)

## 从 jinja 模板生成 Dockerfile

警告：已弃用

可通过模板生成 Dockerfile 和配置。

- arch：`amd64` 或 `armhf`
- flavor：参见 flavor/`flavor`.yml 文件
- image：基础镜像
- desktop：桌面环境，已在 flavor 中设置
- addon_package：需要安装的 Debian 包，已在 flavor 中设置

Dockerfile 和配置若不存在会自动重新生成。或者，可以通过 `make clean` 命令强制重新生成。

## 故障排查和常见问题

1. boot2docker 连接问题，https://github.com/fcwu/docker-ubuntu-vnc-desktop/issues/2
2. 多语言支持，https://github.com/fcwu/docker-ubuntu-vnc-desktop/issues/80
3. 自动启动，https://github.com/fcwu/docker-ubuntu-vnc-desktop/issues/85#issuecomment-466778407
4. x11vnc 参数（multiptr），https://github.com/fcwu/docker-ubuntu-vnc-desktop/issues/101
5. Firefox/Chrome 崩溃（/dev/shm），https://github.com/fcwu/docker-ubuntu-vnc-desktop/issues/112
6. 在不销毁容器的情况下调整显示大小，https://github.com/fcwu/docker-ubuntu-vnc-desktop/issues/115#issuecomment-522426037

## 许可证

详情请参阅 LICENSE 文件。
```
