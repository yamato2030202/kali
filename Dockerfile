FROM docker.io/kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive

# 1. تهيئة المستودعات وتثبيت حزم أساسية فائقة الخفة (Openbox هو أخف مدير نوافذ)
RUN echo "deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware" > /etc/apt/sources.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    openbox \
    x11vnc \
    xvfb \
    xterm \
    sudo \
    curl \
    iptables \
    ca-certificates \
    gnupg \
    chromium \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. تثبيت Tailscale يدويًا
RUN mkdir -p /usr/share/keyrings \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list \
    && apt-get update \
    && apt-get install -y tailscale \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 3. إنشاء مستخدم عادي وصلاحيات كاملة
RUN useradd -m -s /bin/bash kaliuser && echo "kaliuser:kali123" | chpasswd \
    && usermod -aG sudo kaliuser

# 4. إعداد سكربت التشغيل لإنشاء شاشة افتراضية خفيفة جداً (Xvfb) تشغل المتصفح فوراً
RUN echo 'id\n\
Xvfb :1 -screen 0 1280x720x24 &\n\
export DISPLAY=:1\n\
sleep 2\n\
openbox-session &\n\
x11vnc -display :1 -nopw -listen localhost -forever &\n\
chromium --no-sandbox --disable-gpu --start-maximized &\n\
tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 &\n\
sleep 3\n\
tailscale up --authkey=${TAILSCALE_AUTHKEY} --hostname=kali-railway\n\
tail -f /dev/null' > /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 5900

CMD ["/bin/sh", "/entrypoint.sh"]
