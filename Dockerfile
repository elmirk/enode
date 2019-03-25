FROM erlang:alpine as DEV

#we use rebar 3.9.0, can check by rebar3 version
ENV REBAR3_VERSION="3.9.1"

LABEL author="Elmir Karimullin"

RUN set -xe \
	&& apk --no-cache --update add git 
#	&& mkdir -vp /opt/smsrouter

# no need to add this lines to dockerfile, because rebar3 already in erlang:alpine!!!
COPY src /opt
WORKDIR /opt
RUN rebar3 release

# WORKDIR /opt/rebar3
# RUN ["/opt/rebar3/bootstrap"]
# RUN install -v ./rebar3 /usr/local/bin/

#CMD erl -name enode@localhost -setcookie smsrouter
#run release with console
CMD /opt/_build/default/rel/enode/bin/enode console
