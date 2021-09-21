FROM golang:1.12-alpine as builder
RUN apk update && apk add build-base git
WORKDIR /app
COPY go.mod .
COPY go.sum .
RUN go mod download
COPY . .
RUN GOOS=linux GOARCH=amd64 go build -ldflags '-linkmode=external "-extldflags=-static"'
RUN cp docker-userland /bin

FROM debian:buster
LABEL maintainers "Martin Koppehel <mkoppehel@embedded.enterprises>, Jasper Orschulko <jasper@orschulko.eu>"
RUN set -ex \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && apt-get update \
    && apt-get install -y \
        locales \
        man-db \
    && locale-gen \
    && groupadd -g 1000 user \
    && useradd -d /home/user -g 1000 -u 1000 -o -m -s /bin/zsh user \
    && apt-get install -y \
        zsh \
        tmux \
        vim \
        emacs-nox \
        ti \
        nano \
        less \
        git \
    && su user -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"' \
    && sed -i s/robbyrussell/gianu/g /home/user/.zshrc \
    && apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
    && curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose \
    && chmod +x "$_" \
    && apt-get purge curl --autoremove -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /bin/docker-userland /bin/docker-userland

USER user
WORKDIR /home/user
ADD ./setup-userland.sh .
RUN sh ./setup-userland.sh && rm ./setup-userland.sh
WORKDIR /
USER root
RUN mv /home/user /home/user-template

ADD ./start-userland.sh /start-userland.sh
USER root
WORKDIR /home/user

ENTRYPOINT ["/bin/sh"]
CMD ["/start-userland.sh"]
