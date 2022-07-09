FROM nixos/nix:latest
RUN : \
    && nix-env -iA nixpkgs.gnused \
    && cp /etc/nix/nix.conf /etc/nix/nix.conf.bak \
    && chmod +w /etc/nix/nix.conf.bak \
    && echo "extra-platforms = x86_64-linux" >> /etc/nix/nix.conf.bak \
    && cp /etc/nix/nix.conf.bak /etc/nix/nix.conf \
    && mkdir -p /etc/ssh \
    && echo "sshd:x:498:65534::/var/empty:/run/current-system/sw/bin/nologin" >> /etc/passwd \
    && sed -i '/^root/d' /etc/passwd \
    && echo "root:x:0:0::/root:/root/.nix-profile/bin/bash" >> /etc/passwd \
    && cp /root/.nix-profile/etc/ssh/sshd_config /etc/ssh \
    && sed -i '/^PermitRootLogin/d' /etc/ssh/sshd_config \
    && sed -i '/^PubkeyAuthentication/d' /etc/ssh/sshd_config \
    && sed -i '/^PasswordAuthentication/d' /etc/ssh/sshd_config \
    && sed -i '/^UsePAM/d' /etc/ssh/sshd_config \
    && echo "PermitRootLogin without-password" >> /etc/ssh/sshd_config \
    && echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication no" >> /etc/ssh/sshd_config \
    && echo "UsePAM yes" >> /etc/ssh/sshd_config \
    && mkdir -p /etc/pam.d \
    && echo "account sufficient pam_unix.so" >> /etc/pam.d/other \
    && echo "auth sufficient pam_rootok.so" >> /etc/pam.d/other \
    && echo "password requisite pam_unix.so nullok sha512" >> /etc/pam.d/other \
    && echo "session required pam_unix.so" >> /etc/pam.d/other \
    && touch /etc/login.defs \
    && ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N "" -t rsa \
    && ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N "" -t dsa \
    && mkdir /var/empty \
    && mkdir /run \
    && mkdir -p /var/log \
    && touch /var/log/lastlog \
    && echo "export NIX_PATH=$NIX_PATH" >> /etc/bashrc \
    && echo "export NIX_SSL_CERT_FILE=$NIX_SSL_CERT_FILE" >> /etc/bashrc \
    && echo "export PATH=$PATH" >> /etc/bashrc \
    && echo "source /etc/bashrc" >> /etc/profile

ADD insecure_rsa /root/.ssh/id_rsa
ADD insecure_rsa.pub /root/.ssh/authorized_keys

EXPOSE 22

CMD /nix/store/ll2h79c4sa9sdybmdwkh5500via62hm1-openssh-8.6p1/bin/sshd -D -e
