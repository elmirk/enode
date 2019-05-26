# comments:
# erlang:alpine already have rebar3 inside
# multistaging dockerfile
# rebar3 could have some bug,maybe need patch
# should we turn off dev_mode in relx for production?
# dev stage run with console

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

# WORKDIR /opt/rebar3
# RUN ["/opt/rebar3/bootstrap"]
# RUN install -v ./rebar3 /usr/local/bin/

#CMD erl -name enode@localhost -setcookie smsrouter
CMD /opt/_build/default/rel/enode/bin/enode console

FROM erlang:alpine as prod

ENV TERM=xterm

WORKDIR /opt
COPY --from=dev /opt/_build /opt/_build
COPY --from=dev /opt/config /opt/config
COPY --from=dev /etc/localtime /etc/localtime
COPY --from=dev /etc/timezone /etc/timezone

CMD /opt/_build/default/rel/enode/bin/enode foreground
