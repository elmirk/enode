%%%-------------------------------------------------------------------
%%% @author root <>
%%% @copyright (C) 2019, root
%%% @doc
%%%
%%% @end
%%% Created :  6 Jun 2019 by root <>
%%% scheduler_usage function copied from recon utility, fred herbert
%%%-------------------------------------------------------------------
-module(maintainer).

-behaviour(gen_server).

%% API
-export([start_link/0]).

-export([check_enode/0,
         scheduler_usage/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3, format_status/2]).

-define(SERVER, ?MODULE).

%%-record(state, {}).

-record(state,
        {cur_cid, %%currently used cid
         o_dialogs,
         tabs,
         limit = 0,
         sup,
         c_node}).


%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> {ok, Pid :: pid()} |
                      {error, Error :: {already_started, pid()}} |
                      {error, Error :: term()} |
                      ignore.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).


check_enode() ->

    Mem = erlang:memory(),
    Tot = proplists:get_value(total, Mem),
    ProcM = proplists:get_value(processes_used,Mem),
    Atom = proplists:get_value(atom_used,Mem),
    Bin = proplists:get_value(binary, Mem),
    Ets = proplists:get_value(ets, Mem),

    io:format("total memory(bytes)   = ~p~n",[Tot]),
    io:format("processes_used(bytes) = ~p~n", [ProcM]),
    io:format("used by atoms(bytes)  = ~p~n", [Atom]),
    io:format("used by binary(bytes) = ~p~n", [Bin]),
    io:format("used by ets(bytes)    = ~p~n", [Ets]),

    Tables = enode_broker:get_tables(),
    lists:foreach(fun(Tab) ->
                          Size = ets:info(Tab,size),
                          io:format("table ~p size = ~p~n",[Tab,Size])
                  end, Tables),
    io:format("total number of processes = ~p~n",[length(processes())]),
    io:format("total number of atoms     = ~p~n",[erlang:system_info(atom_count)]),
    io:format("total number of ports     = ~p~n",[length(erlang:ports())]),    

    BS = sys:get_state(whereis(enode_broker)),

    io:format("enode_broker gen_server state      = ~P~n",[BS,9]),
    io:format("enode_dw_sup children number       = ~p~n",[supervisor:count_children(BS#state.sup)]),
    io:format("enode broker messages queue length = ~p~n",[erlang:process_info(whereis(enode_broker), message_queue_len)]),
    io:format("scheduler usage = ~p~n", [scheduler_usage(1000)]).

%% @doc Diffs two runs of erlang:statistics(scheduler_wall_time) and
%% returns usage metrics in terms of cores and 0..1 percentages.
-spec scheduler_usage_diff(SchedTime, SchedTime) -> undefined | [{SchedulerId, Usage}] when
    SchedTime :: [{SchedulerId, ActiveTime, TotalTime}],
    SchedulerId :: pos_integer(),
    Usage :: number(),
    ActiveTime :: non_neg_integer(),
    TotalTime :: non_neg_integer().
scheduler_usage_diff(First, Last) when First =:= undefined orelse Last =:= undefined ->
    undefined;
scheduler_usage_diff(First, Last) ->
    lists:map(
        fun ({{I, _A0, T}, {I, _A1, T}}) -> {I, 0.0}; % Avoid divide by zero
            ({{I, A0, T0}, {I, A1, T1}}) -> {I, (A1 - A0)/(T1 - T0)}
        end,
        lists:zip(lists:sort(First), lists:sort(Last))
    ).

%% A scheduler isn't busy when doing anything else.
-spec scheduler_usage(Millisecs) -> undefined | [{SchedulerId, Usage}] when
    Millisecs :: non_neg_integer(),
    SchedulerId :: pos_integer(),
    Usage :: number().
scheduler_usage(Interval) when is_integer(Interval) ->
    %% We start and stop the scheduler_wall_time system flag if
    %% it wasn't in place already. Usually setting the flag should
    %% have a CPU impact (making it higher) only when under low usage.
    FormerFlag = erlang:system_flag(scheduler_wall_time, true),
    First = erlang:statistics(scheduler_wall_time),
    timer:sleep(Interval),
    Last = erlang:statistics(scheduler_wall_time),
    erlang:system_flag(scheduler_wall_time, FormerFlag),
    scheduler_usage_diff(First, Last).


%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) -> {ok, State :: term()} |
                              {ok, State :: term(), Timeout :: timeout()} |
                              {ok, State :: term(), hibernate} |
                              {stop, Reason :: term()} |
                              ignore.
init([]) ->
%%    process_flag(trap_exit, true),
    {ok, #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request :: term(), From :: {pid(), term()}, State :: term()) ->
                         {reply, Reply :: term(), NewState :: term()} |
                         {reply, Reply :: term(), NewState :: term(), Timeout :: timeout()} |
                         {reply, Reply :: term(), NewState :: term(), hibernate} |
                         {noreply, NewState :: term()} |
                         {noreply, NewState :: term(), Timeout :: timeout()} |
                         {noreply, NewState :: term(), hibernate} |
                         {stop, Reason :: term(), Reply :: term(), NewState :: term()} |
                         {stop, Reason :: term(), NewState :: term()}.
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(Request :: term(), State :: term()) ->
                         {noreply, NewState :: term()} |
                         {noreply, NewState :: term(), Timeout :: timeout()} |
                         {noreply, NewState :: term(), hibernate} |
                         {stop, Reason :: term(), NewState :: term()}.
handle_cast(_Request, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_info(Info :: timeout() | term(), State :: term()) ->
                         {noreply, NewState :: term()} |
                         {noreply, NewState :: term(), Timeout :: timeout()} |
                         {noreply, NewState :: term(), hibernate} |
                         {stop, Reason :: normal | term(), NewState :: term()}.
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason :: normal | shutdown | {shutdown, term()} | term(),
                State :: term()) -> any().
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%% @end
%%--------------------------------------------------------------------
-spec code_change(OldVsn :: term() | {down, term()},
                  State :: term(),
                  Extra :: term()) -> {ok, NewState :: term()} |
                                      {error, Reason :: term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called for changing the form and appearance
%% of gen_server status when it is returned from sys:get_status/1,2
%% or when it appears in termination error logs.
%% @end
%%--------------------------------------------------------------------
-spec format_status(Opt :: normal | terminate,
                    Status :: list()) -> Status :: term().
format_status(_Opt, Status) ->
    Status.

%%%===================================================================
%%% Internal functions
%%%===================================================================
