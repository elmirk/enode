# comments:
# erlang:alpine already have rebar3 inside
# multistaging dockerfile
# rebar3 could have some bug,maybe need patch
# should we turn off dev_mode in relx for production?
# dev stage run with console

#to build only DEV target use
#docker build --target dev -t enode:test2 .

FROM erlang:alpine as dev

#we use rebar 3.9.0, can check by rebar3 version
ENV REBAR3_VERSION="3.9.1"

LABEL author="Elmir Karimullin"

RUN set -xe \
	&& apk --no-cache --update add git tzdata \
        && cp /usr/share/zoneinfo/Europe/Moscow /etc/localtime \
        && echo "Europe/Moscow" >  /etc/timezone

COPY src /opt
WORKDIR /opt
RUN rebar3 release

CMD /opt/_build/default/rel/enode/bin/enode console

FROM erlang:alpine as prod

ENV TERM=xterm-256color

WORKDIR /opt

COPY --from=dev /etc/localtime /etc/localtime
COPY --from=dev /etc/timezone /etc/timezone
COPY --from=dev /opt/color_prompt.sh /etc/profile.d/
COPY --from=dev /opt/.shinit /root/
COPY --from=dev /opt/config /opt/config
COPY --from=dev /opt/_build /opt/_build

CMD /opt/_build/default/rel/enode/bin/enode foreground
