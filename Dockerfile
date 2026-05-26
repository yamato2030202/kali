FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive

# 1. تحديث وتثبيت أدوات الواجهة الخفيفة والاعتماديات الأساسية
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-goodies \
    xrdp \
    xorg \
    dbus-x11 \
    sudo \
    curl \
    iptables \
    ca-certificates \
    gnupg \
    && apt-get clean

# 2. تثبيت Tailscale يدوياً (عبر الـ Package Manager لتجنب مشكلة systemd)
RUN mkdir -p /usr/share/keyrings \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list \
    && apt-get update \
    && apt-get install -y tailscale \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 3. إعداد مستخدم الـ RDP الخفيف
RUN useradd -m -s /bin/bash kaliuser && echo "kaliuser:kali123" | chpasswd \
    && usermod -aG sudo kaliuser

# 4. إجبار التوزيعة على استخدام واجهة xfce النظيفة
RUN echo "startxfce4" > /home/kaliuser/.xsession && chown kaliuser:kaliuser /home/kaliuser/.xsession

EXPOSE 3389

# 5. تشغيل خادم الـ Tailscale يدوياً في الخلفية (userspace-networking ليتوافق مع الحاويات) ثم الـ RDP
CMD tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 & \
    sleep 3 && \
    tailscale up --authkey=${TAILSCALE_AUTHKEY} --hostname=kali-railway & \
    service xrdp start && \
    tail -f /dev/null
