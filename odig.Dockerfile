FROM ubuntu
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y \
    rsync git m4 build-essential \
    patch unzip wget pkg-config \
    libgmp-dev libev-dev libhidapi-dev \
    libffi-dev jq libpcre3-dev \
    libsqlite3-dev zlib1g-dev \
    curl postgresql sudo \
    opam

RUN adduser --disabled-password --gecos '' docker
RUN adduser docker sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER docker

WORKDIR /home/docker

# TODO add to list
RUN sudo apt-get install -y autoconf

RUN opam init --bare --disable-sandboxing

RUN cd ../ && opam switch create 4.10.2 && opam install comby -y

RUN curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain 1.44.0 -y
ENV OPAMDEPEXTYES=true

RUN ocaml_version=4.10.2
RUN opam_version=2.0
RUN recommended_rust_version=1.44.0

## full_opam_repository is a commit hash of the public OPAM repository, i.e.
## https://github.com/ocaml/opam-repository
RUN full_opam_repository_tag=521b2b782c6e74f8e02e08b3bb4d7aef68428651

## opam_repository is an additional, tezos-specific opam repository.
## This value MUST be the same as `build_deps_image_version` in `.gitlab-ci.yml
ENV opam_repository_tag=8b65efc0fbe6a3c7f267516a764557df05bcc3fe
ENV opam_repository_url=https://gitlab.com/tezos/opam-repository.git
ENV opam_repository=$opam_repository_url\#$opam_repository_tag

## Other variables, used both in Makefile and scripts
ENV COVERAGE_OUTPUT=_coverage_output

RUN opam repository set-url tezos --dont-select $opam_repository || \
    opam repository add tezos --dont-select $opam_repository > /dev/null 2>&1

RUN opam update --repositories --development

RUN opam install odig -y

RUN opam exec -- odig odoc
RUN opam exec -- odoc support-files -o ~/.opam/4.10.2/var/cache/odig/html/_odoc-theme
RUN opam exec -- odig doc
