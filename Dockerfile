FROM docker.io/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. تحديث النظام وتثبيت خادم RDP والواجهة الفائقة الخفة مع الأدوات الأساسية
RUN apt-get update && apt-get install -y --no-install-recommends \
    openbox \
    xrdp \
    xorg \
    dbus-x11 \
    sudo \
    curl \
    iptables \
    ca-certificates \
    gnupg \
    chromium-browser \
    xterm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. تثبيت Tailscale يدويًا بشكل مستقر لبيئة حاويات Railway
RUN mkdir -p /usr/share/keyrings \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list \
    && apt-get update \
    && apt-get install -y tailscale \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 3. إنشاء مستخدم الـ RDP وصلاحيات الـ Sudo
RUN useradd -m -s /bin/bash railwayuser && echo "railwayuser:railway123" | chpasswd \
    && usermod -aG sudo railwayuser

# 4. ضبط توجيه الواجهة الرسومية الخفيفة (Openbox) للمستخدم عند الاتصال بـ RDP
RUN echo "openbox-session" > /home/railwayuser/.xsession \
    && chown railwayuser:railwayuser /home/railwayuser/.xsession

# منع xrdp من استخدام نظام الصوت الافتراضي لتسريع الأداء وتقليل استهلاك الرام
RUN sed -i 's/max_bpp=32/max_bpp=16/g' /etc/xrdp/xrdp.ini

EXPOSE 3389

# 5. تشغيل شبكة Tailscale وخادم RDP معاً في الخلفية
CMD ["/bin/sh", "-c", "tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 & sleep 3 && tailscale up --authkey=${TAILSCALE_AUTHKEY} --hostname=ubuntu-rdp & service xrdp start && tail -f /dev/null"]
