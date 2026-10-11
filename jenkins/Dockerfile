# Jenkins cho Bai 2 — CI/CD tren laptop
# Anh nay chi co `docker` CLI, dieu khien Docker Desktop cua may qua socket
# /var/run/docker.sock mount tu docker-compose.yml (kieu DooD — Docker outside of Docker).
# Khong dung jenkins/jenkins goc: anh goc khong co docker CLI → pipeline bao "docker: not found".
FROM jenkins/jenkins:lts-jdk17

USER root

# Docker CLI + compose plugin + cac cong cu can thiet (git, curl) cho pipeline
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
        https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin docker-buildx-plugin \
    && rm -rf /var/lib/apt/lists/*

USER jenkins

# Tat setup wizard cho nhanh (vao truc tiep giao dien, khong doi mat khau) — danh cho lab local.
# Plugin duoc cai truoc trong Dockerfile vi wizard da tat.
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

RUN jenkins-plugin-cli --plugins \
        git \
        workflow-aggregator \
        credentials-binding \
        plain-credentials \
        ssh-slaves \
        timestamper
