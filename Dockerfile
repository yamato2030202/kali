FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive

# تثبيت التحديثات، الواجهة الخفيفة، وخادم RDP وأداة الـ Tailscale
RUN apt-get update && apt-get install -y \
    kali-desktop-xfce \
    xrdp \
    xorg \
    dbus-x11 \
    sudo \
    curl \
    iptables \
    && apt-get clean

# تثبيت Tailscale رسميًا
RUN curl -fsSL https://tailscale.com/install.sh | sh

# إعداد مستخدم جديد للـ RDP
RUN useradd -m -s /bin/bash kaliuser && echo "kaliuser:kali123" | chpasswd
RUN usermod -aG sudo kaliuser

# إعداد الـ XRDP ليستخدم واجهة XFCE الخفيفة
RUN echo "xfce4-session" > /home/kaliuser/.xsession && chown kaliuser:kaliuser /home/kaliuser/.xsession

EXPOSE 3389

# سكربت التشغيل لربط Tailscale ثم تشغيل الـ RDP
CMD tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 & \
    sleep 2 && \
    tailscale up --authkey=${TAILSCALE_AUTHKEY} --hostname=kali-railway & \
    service xrdp start && \
    tail -f /dev/null
