-module(subscribers).
-author('elmir.karimullin@gmail.com').


-export([start/0,
         get_cnum/1]).

-record(mv, {tarantool}).

start()->
    case taran:connect() of
                {ok, TTconn} -> put(mv_subscribers,#mv{tarantool = TTconn});
                _Other -> put(mv_subscribers, #mv{tarantool = fail})
            end
    .

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
        {ok,Out}
        ->
            ok,
            [16#0b, 16#91] ++ Out;
        Other->
            io:format("reply = ~p~n",[Other]),
            check_local_db(Msisdn)
    end.

%%
%%    ets:insert(subscribers, {<<16#91, 16#97, 16#80, 16#33, 16#47, 16#33, 16#f9>>,
%%			     <<16#0b, 16#91, 16#97, 16#06, 16#30, 16#05, 16#00, 16#f0>>}),

check_local_db(Msisdn)->
    [{_, Tp_da}] = ets:lookup(subscribers, list_to_binary(Msisdn)),
    binary_to_list(Tp_da).
