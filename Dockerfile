FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive

# تحديث وتثبيت الحد الأدنى والأساسي جداً للواجهة لمنع استهلاك الذاكرة OOM
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# تثبيت أداة Tailscale
RUN curl -fsSL https://tailscale.com/install.sh | sh

# إعداد مستخدم الـ RDP الخفيف
RUN useradd -m -s /bin/bash kaliuser && echo "kaliuser:kali123" | chpasswd
RUN usermod -aG sudo kaliuser

# إجبار التوزيعة على استخدام واجهة xfce النظيفة
RUN echo "startxfce4" > /home/kaliuser/.xsession && chown kaliuser:kaliuser /home/kaliuser/.xsession

EXPOSE 3389

# تشغيل شبكة التونل الافتراضية لـ Tailscale ثم تشغيل الـ RDP
CMD tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 & \
    sleep 3 && \
    tailscale up --authkey=${TAILSCALE_AUTHKEY} --hostname=kali-railway & \
    service xrdp start && \
    tail -f /dev/null
