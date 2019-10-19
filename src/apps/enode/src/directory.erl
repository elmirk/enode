%%%-------------------------------------------------------------------
%%% @author root <>
%%% @copyright (C) 2019, root
%%% @doc
%%% Module for managing DCS coding schemes in smsrouter.
%%% @end
%%% Created : 25 Jun 2019 by root <>
%%% TODO: initial values in ets could be loaded from file (file2tab or something)
%%% TODO: data loaded in runtime should be saved on disk/file to load
%%%       new data in case of restarts
%%%-------------------------------------------------------------------
-module(directory).

-behaviour(gen_server).

%% external API
-export([start_link/2,
         add_dcs2coding/1,
         get_coding/0,
         get_coding/1,
         rm_coding/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3, format_status/2]).

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link(term(), term()) -> {ok, Pid :: pid()} |
                      {error, Error :: {already_started, pid()}} |
                      {error, Error :: term()} |
                      ignore.
start_link(A,B) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [A,B], []).

%%--------------------------------------------------------------------
%% @doc
%% Add tuple {Dcs, Coding} to dcs2coding table
%% @end
%%--------------------------------------------------------------------
-spec add_dcs2coding({integer(), atom()}) -> true | false.
add_dcs2coding({Dcs, Coding}) when Coding =:= ucs2 orelse Coding =:= gsm7bit->
    gen_server:call(?MODULE, {add, Dcs, Coding});
add_dcs2coding({_Dcs, _Coding}) -> false.

%%--------------------------------------------------------------------
%% @doc
%% Fetch specific DCS from dcs2coding table
%% @end
%%--------------------------------------------------------------------
-spec get_coding(Dcs :: integer()) -> atom().
get_coding(Dcs)->
    case ets:lookup(dcs2coding, Dcs) of
        [{_, Coding}] -> Coding;
        [] -> io:format("there is no data in dcs coding table for DCS=~p~n",[Dcs])
    end.

%%--------------------------------------------------------------------
%% @doc
%% Fetch all data from dcs2coding table
%% @end
%%--------------------------------------------------------------------
get_coding()->
    io:format("~p~n",[ets:tab2list(dcs2coding)]).

%%--------------------------------------------------------------------
%% @doc
%% Remove Dcs from dcs2coding table
%% @end
%%--------------------------------------------------------------------
rm_coding(Dcs) when Dcs =:= 0 orelse Dcs =:= 1 orelse Dcs =:=8 ->
    io:format("could not remove initially configured DCS!");
rm_coding(Dcs)->
    gen_server:call(?MODULE, {rm, Dcs}).

%%--------------------------------------------------------------------
%% @doc
%% Load initially configured list of Dcs codings
%% @end
%%--------------------------------------------------------------------
load_dcs2coding([H|T])->
    ets:insert_new(dcs2coding, H),
    load_dcs2coding(T);

load_dcs2coding([])->
    true.

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the directory gen_server process
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) -> {ok, State :: term()} |
                              {ok, State :: term(), Timeout :: timeout()} |
                              {ok, State :: term(), hibernate} |
                              {stop, Reason :: term()} |
                              ignore.
init([A,B]) ->
   %% process_flag(trap_exit, true),
    ets:new(dcs2coding, [set, protected, named_table, {keypos,1},
                         {heir,none}, {write_concurrency,false},
                         {read_concurrency, true}]),
    InitialData = [{0, gsm7bit}, {1, gsm7bit}, {8, ucs2}],
    load_dcs2coding(InitialData),
    io:format("dictionary started wih A = ~p B = ~p !~n", [A,B]),
    { ok, #state{} }.

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
handle_call({add, Dcs, Coding}, _From, State) ->
    Reply = ets:insert_new(dcs2coding, {Dcs, Coding}),
    {reply, Reply, State};

handle_call({rm, Dcs}, _From, State) ->
    Reply = ets:delete(dcs2coding, Dcs),
    {reply, Reply, State};

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
