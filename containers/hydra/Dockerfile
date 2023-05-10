# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2022-2023 Marko Lindqvist <marko.lindqvist@unikie.com>
# SPDX-FileCopyrightText: 2022-2023 Unikie
# SPDX-FileCopyrightText: 2022-2023 Technology Innovation Institute (TII)

# Container for the hydra

#FROM ubuntu
#RUN apt-get install cowsay
#RUN apt-get install gcc

FROM nixos/nix

RUN nix-build -A pythonFull '<nixpkgs>'

RUN mkdir -p /setup/
COPY channel.sh user.sh nix_conf.sh postgres.sh hydra.sh \
     populate.sh packages.lst upload.sh /setup/
COPY hydra_conf.sh postbuild.py /setup/
COPY pythonEnv.nix /setup/

RUN chmod +x /setup/*.sh

ARG CHANNEL
RUN /setup/channel.sh "$CHANNEL"

ARG HYDRA_UID
ARG HYDRA_GID
ARG HYDRA_REMOTE_BUILDERS
ARG PB_SRV

RUN nix-env -i hydra -i postgresql


#RUN nix-env -iA ../setup/pythonEnv
#RUN nix-env -i gcc
#RUN nix-env -i nano

RUN /setup/user.sh "$HYDRA_UID" "$HYDRA_GID" && \
    /setup/nix_conf.sh "$HYDRA_REMOTE_BUILDERS" && \
    /setup/hydra_conf.sh "$PB_SRV"

RUN mkdir -p /run/postgresql && chmod go+w /run/postgresql
COPY launch.sh run.sh /launch/
RUN chmod +x /launch/*.sh
RUN chown -R hydra:hydra /nix/var/nix
RUN rm -Rf /root/.cache

ARG CONTAINER_DEBUG=false
RUN touch /etc/container-debug-${CONTAINER_DEBUG}

#RUN python3 -m ensurepip --upgrade

#
#RUN python3 -m ensurepip --default-pip > INSTA.LOG

#RUN python3 -m pip3 install --upgrade pip
#RUN which pip3
#RUN /home/hydra/.local/bin/pip3 install slackclient

#
#RUN /root/.nix-profile/bin/python3 -m pip
#
#RUN /root/.nix-profile/bin/python3 -m pip install slackclient > SLACK.LOG

RUN chmod +x /setup/postbuild.py
#RUN /setup/postbuild.py

USER hydra

WORKDIR /launch
ENTRYPOINT /launch/launch.sh
