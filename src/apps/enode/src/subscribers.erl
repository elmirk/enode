-module(subscribers).
-author('elmir.karimullin@gmail.com').


-export([start/0,
         stop/0,
         get_cnum/1]).

-record(mv, {tarantool}).

start()->
    case taran:connect() of
                {ok, TTconn} -> put(mv_subscribers,#mv{tarantool = TTconn});
                _Other -> put(mv_subscribers, #mv{tarantool = fail})
            end
    .

stop() ->
    Mv = get(mv_subscribers),
    TTconn = Mv#mv.tarantool,
    taran:connect_close(TTconn).

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%% incoming Msisdn with first technickal digits,
%% thats why we should drop Head of list and use Tail
%%--------------------------------------------------------------------

get_cnum([_H | Msisdn])->
    Mv = get(mv_subscribers),
    case catch taran:call(Mv#mv.tarantool,get_num, [Msisdn]) of
        {ok,Out}->
            [16#0b, 16#91] ++ Out;
        Other->
            lager:error("taran returned:~p",[Other]),
            []
    end.
