FROM ocaml/opam:ubuntu-21.04-ocaml-4.10
ARG DEBIAN_FRONTEND=noninteractive

ENV OPAMYES=true
ENV OPAMDEPEXTYES=true

RUN opam switch create . ocaml-base-compiler.4.10.2
RUN opam depext conf-pkg-config conf-m4 conf-libssl conf-rust conf-gmp conf-libffi conf-libev

# RUN curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain 1.44.0 -y

ENV ocaml_version=4.10.2
ENV opam_version=2.0
ENV recommended_rust_version=1.44.0

## full_opam_repository is a commit hash of the public OPAM repository, i.e.
## https://github.com/ocaml/opam-repository
ENV full_opam_repository_tag=521b2b782c6e74f8e02e08b3bb4d7aef68428651

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

RUN opam pin add odoc https://github.com/ocaml/odoc.git#2.0.0-beta3 -y
RUN opam install odig -y

COPY ./src ./src

#RUN opam pin add tezos-protocol-alpha ./src/proto_alpha/lib_protocol/tezos-protocol-alpha.opam -y
RUN opam install ./src/proto_alpha/lib_protocol/tezos-protocol-alpha.opam -y

RUN opam exec -- odig odoc

ENTRYPOINT [ "/bin/sh" ]
