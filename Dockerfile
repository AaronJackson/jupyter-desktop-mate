FROM quay.io/jupyter/base-notebook:2026-01-26

ARG DEBIAN_FRONTEND=noninteractive
ARG ACCEPT_EULA=Y

USER root

# hadolint ignore=DL3008
RUN apt-get update -y -q \
 && apt-get install -y -q --no-install-recommends \
        tigervnc-standalone-server \
        ubuntu-mate-desktop \
        # xclip is added so Playwright can test the clipboard
        xclip \
        # Useful command line tools
        curl \
        less \
        rsync \
        tmux \
        vim \
        # Selected recommends
        fonts-liberation2 \
        mate-applet-brisk-menu \
        mate-calc \
        mate-hud \
        mate-optimus \
        mate-sensors-applet \
        mate-system-monitor \
        mate-tweak \
        mate-user-admin \
        mate-window-buttons-applet \
        mate-window-menu-applet \
        mate-window-title-applet \
        tigervnc-tools \
        ubuntu-mate-artwork \
        xdg-desktop-portal-gtk \
 && add-apt-repository -y ppa:mozillateam/ppa \
 && printf 'Package: firefox*\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' > /etc/apt/preferences.d/firefox \
 && apt-get install -y -q --no-install-recommends --allow-downgrades firefox \
 && apt-get purge -y -q \
        blueman \
        mate-screensaver \
 && apt-get autoremove -y -q \
    # chown $HOME to workaround that the xorg installation creates a
    # /home/jovyan/.cache directory owned by root
    # Create /opt/install to ensure it's writable by pip
 && mkdir -p /opt/install "$HOME/.vnc" \
 && chown -R "$NB_UID:$NB_GID" "$HOME" /opt/install \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/microsoft/msodbcsql18/ && touch /opt/microsoft/msodbcsql18/ACCEPT_EULA && \
    apt update && apt install -y curl && \
    curl -sSL -O https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    apt update && apt install -y krb5-user mssql-tools18 unixodbc-dev emacs-nox

USER $NB_USER

# requirements.txt can be bumped by dependabot, convert to conda requirement
COPY --chown=$NB_UID:$NB_GID requirements.txt /tmp

# hadolint ignore=SC1091,SC2046
RUN . /opt/conda/bin/activate && \
    mamba install --no-allow-downgrade \
        "nodejs=24" \
        $(sed s/==/=/ /tmp/requirements.txt) && \
    mamba clean --all

COPY start-mate.sh start-tigervnc.sh /usr/local/bin/
# $HOME/.vnc/xstartup may be shadowed if the home directory is mounted
# https://github.com/jupyterhub/jupyter-remote-desktop-proxy/pull/134
RUN ln -sf /usr/local/bin/start-mate.sh /opt/conda/lib/python3.13/site-packages/jupyter_remote_desktop_proxy/share/xstartup

# Add some shortcuts to the desktop and make a copy of HOME in case it's shadowed by a mount
ENV HOME_TEMPLATE_DIR=/opt/install/home.template
RUN rsync -a "$HOME" "$HOME_TEMPLATE_DIR" && \
    mkdir "$HOME_TEMPLATE_DIR/Desktop" && \
    ln -s \
        /usr/share/applications/mate-terminal.desktop \
        /usr/share/applications/firefox.desktop \
        "$HOME_TEMPLATE_DIR/Desktop"
