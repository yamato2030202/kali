FROM docker.io/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. تحديث النظام وتثبيت بيئة واجهة مستخدم متكاملة عبر الويب (Xfce + noVNC)
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-goodies \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    sudo \
    curl \
    iptables \
    ca-certificates \
    gnupg \
    chromium-browser \
    xterm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. تثبيت Tailscale يدويًا بشكل مستقر
RUN mkdir -p /usr/share/keyrings \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list \
    && apt-get update \
    && apt-get install -y tailscale \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 3. إنشاء المستخدم وصلاحيات الـ Sudo
RUN useradd -m -s /bin/bash railwayuser && echo "railwayuser:railway123" | chpasswd \
    && usermod -aG sudo railwayuser

# 4. تجهيز منافذ البث (noVNC يعمل على منفذ 6080)
EXPOSE 6080

# 5. سكربت التشغيل الذكي لإقلاع الشاشة الافتراضية وبثها فوراً عبر الويب وتفعيل Tailscale
RUN echo '#!/bin/sh\n\
tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 &\n\
sleep 2\n\
tailscale up --authkey=${TAILSCALE_AUTHKEY} --hostname=ubuntu-desktop\n\
# إنشاء شاشة عرض وهمية مستقرة\n\
Xvfb :1 -screen 0 1280x720x16 &\n\
export DISPLAY=:1\n\
sleep 2\n\
# تشغيل الواجهة الرسومية خفيفة الوزن\n\
startxfce4 &\n\
sleep 2\n\
# تشغيل خادم البث الداخلي بدون باسورد\n\
x11vnc -display :1 -nopw -forever -listen localhost &\n\
sleep 2\n\
# تحويل البث إلى صفحة ويب HTML5 على منفذ 6080\n\
websockify --web /usr/share/novnc/ 6080 localhost:5900 &\n\
tail -f /dev/null' > /entrypoint.sh && chmod +x /entrypoint.sh

CMD ["/bin/sh", "/entrypoint.sh"]
