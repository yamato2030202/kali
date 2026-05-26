FROM docker.io/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV USER=railwayuser

# 1. تحديث النظام وتثبيت الواجهة الخفيفة والخوادم المطلوبة بدقة
RUN apt-get update && apt-get install -y --no-install-recommends \
    openbox \
    xrdp \
    xorg \
    tightvncserver \
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

# 2. تثبيت Tailscale يدويًا بشكل مستقر
RUN mkdir -p /usr/share/keyrings \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list \
    && apt-get update \
    && apt-get install -y tailscale \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 3. إنشاء المستخدم وصلاحيات الـ Sudo بالباسورد المعتمد
RUN useradd -m -s /bin/bash railwayuser && echo "railwayuser:railway123" | chpasswd \
    && usermod -aG sudo railwayuser

# 4. بناء ملفات الجلسة وتصاريح تشغيل Openbox لتفادي الشاشة السوداء نهائياً
RUN mkdir -p /home/railwayuser/.vnc \
    && echo "#!/bin/sh\nexport XKL_XMODMAP_DISABLE=1\nexec openbox-session &" > /home/railwayuser/.vnc/xstartup \
    && chmod +x /home/railwayuser/.vnc/xstartup \
    && echo "openbox-session" > /home/railwayuser/.xsession \
    && chmod +x /home/railwayuser/.xsession \
    && chown -R railwayuser:railwayuser /home/railwayuser

# ضبط إعدادات الـ RDP لتسريع النقل إلى أقصى حد وتخفيف الاستهلاك
RUN sed -i 's/max_bpp=32/max_bpp=16/g' /etc/xrdp/xrdp.ini \
    && echo "allow_channels=true" >> /etc/xrdp/xrdp.ini

EXPOSE 3389

# 5. سكربت التشغيل الذي يضمن إقلاع الـ VNC المحتجب أولاً ثم الـ RDP فوقه والـ Tailscale
RUN echo '#!/bin/sh\n\
tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1055 &\n\
sleep 2\n\
tailscale up --authkey=${TAILSCALE_AUTHKEY} --hostname=ubuntu-rdp\n\
USER=railwayuser vncserver :1 -geometry 1280x720 -depth 16 &\n\
sleep 2\n\
service xrdp start\n\
tail -f /dev/null' > /entrypoint.sh && chmod +x /entrypoint.sh

CMD ["/bin/sh", "/entrypoint.sh"]
