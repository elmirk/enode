%%%-------------------------------------------------------------------
%%% @author elmir.karimullin@gmail.com
%%% @copyright (C) 2019, root
%%% @doc
%%%


%%% gen_server process
%%% supervised by enode_root_sup
%%% @end
%%% Created : 20 Mar 2019 by root <root@elmir-N56VZ>
%%%-------------------------------------------------------------------
-module(enode_broker).

-behaviour(gen_server).

%% API
-export([start_link/4]).
-export([test55/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, format_status/2]).

-include("gctload.hrl").

-define(SERVER, ?MODULE).
-define(SPEC(MFA),
	{worker_sup,
	 {enode_dw_sup, start_link, [MFA]},
	 temporary,
	 10000,
	 supervisor,
	 [enode_dw_sup]}).

-ifdef(prod).
-define(c_node, 'c1@ubuntu').
-else.
-define(c_node, 'c1@elmir-N56VZ').
-endif.


-record(state, {o_dialogs,
                limit = 0,
		sup}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link(Name :: atom(), Limit :: integer(), Sup :: pid(),
		 MFA :: tuple()) -> {ok, Pid :: pid()} |
				    {error, Error :: {already_started, pid()}} |
				    {error, Error :: term()} |
				    ignore.
%%start_link() ->
%%    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

start_link(Name, Limit, Sup, MFA) when is_atom(Name), is_integer(Limit) ->
    gen_server:start_link({local, Name}, ?MODULE, {Limit, MFA, Sup}, []).
%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server,
%% prepare didpid ETS table.
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) -> {ok, State :: term()} |
			      {ok, State :: term(), Timeout :: timeout()} |
			      {ok, State :: term(), hibernate} |
			      {stop, Reason :: term()} |
			      ignore.
%%init([]) ->
%%    process_flag(trap_exit, true),
%%    {ok, #state{}}.

init({Limit, MFA, Sup}) ->
%% We need to find the Pid of the worker supervisor from here,
%% but alas, this would be calling the supervisor while it waits for us!
    self() ! {start_worker_supervisor, Sup, MFA},
    %%{ok, #state{limit=Limit, refs=gb_sets:empty()}}.

%% now we should initiate all stuff to work

    SeqList = lists:seq(0, 1024),
    Q = queue:from_list(SeqList),
    Result = ets:new(didpid, [set, named_table]),
    ets:new(piddid, [set, named_table]),
%%cid  - correlation id, like fake imsi
%%tp_da - forwarded to number
%%sm_rp_oa - originating address digits in MO_SUBMIT_SM, msisdn of subscriber
    ets:new(cid, [set, public, named_table]),  %% for {cid, sm_rp_oa, tp_da}

put(cid, 250270000000000),

    {ok, #state{limit=Limit, o_dialogs = Q}}.
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
handle_call({test55, Args}, _From, S = #state{limit=N, sup=Sup}) when N > 0 ->
    {ok, Pid} = supervisor:start_child(Sup, Args),
    Ref = erlang:monitor(process, Pid),
    {reply, {ok,Pid}, S#state{limit=N-1}};
handle_call(get_cid, _From, State) ->
    Cid = get(cid),
    NewCid = Cid + 1,
    put(cid, NewCid),
    {reply, Cid, State};
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
handle_cast({Worker, MsgType = ?map_msg_dlg_req, PrimitiveType = ?mapdt_open_req, Data}, State)->
    io:format("map msg dlg req + mapdt open request ~n"),
%%    ODlgID = 
    {{value, ODlgId}, NewQueue} = queue:out(State#state.o_dialogs),
    NewState = State#state{o_dialogs=NewQueue},
    {any, ?c_node} ! {MsgType, PrimitiveType, ODlgId, Data},
    ets:insert(didpid, {ODlgId, Worker}),
    ets:insert(piddid, {Worker, ODlgId}),
    io:format("didpid = ~p~n",[ets:tab2list(didpid)]),
    io:format("piddid = ~p~n",[ets:tab2list(piddid)]),
    {noreply, NewState};
handle_cast({Worker, MsgType = ?map_msg_srv_req, PrimitiveType = ?mapst_snd_rtism_req, Data}, State)->
    %%io:format("send back to c node ~n"),
%% TODO!! what about DlgId here!!!!
    [{_, ODlgId}] = ets:lookup(piddid, Worker),
    {any, ?c_node} ! {MsgType, PrimitiveType, ODlgId, Data},
%% maybe this is not good idea, but we send delimit automaticaly from broker
%% alternatives - send delimit from dyn worker or send delimit in C code ?
%% solution - use special parameter then no need for delim req or close req
    Data2 = list_to_binary([5, 0]),
    {any, ?c_node} ! {?map_msg_dlg_req, ?mapdt_delimiter_req, ODlgId, Data2},
    {noreply, State};
handle_cast({Worker, MsgType = ?map_msg_srv_req, PrimitiveType = ?mapst_snd_rtism_rsp, Data}, State)->
    io:format("send back to c node mapst_snd_rtism_rsp ~n"),
%% TODO!! what about DlgId here!!!!
    [{_, ODlgId}] = ets:lookup(piddid, Worker),
    {any, ?c_node} ! {MsgType, PrimitiveType, ODlgId, Data},
    {noreply, State};
handle_cast({Worker, MsgType = ?map_msg_srv_req, PrimitiveType = ?mapst_mo_fwd_sm_req, Data}, State)->
    io:format("send mo fwd sm req to c node ~n"),
%% TODO!! what about DlgId here!!!!
    [{_, ODlgId}] = ets:lookup(piddid, Worker),
    {any, ?c_node} ! {MsgType, PrimitiveType, ODlgId, Data},
    {noreply, State};

%%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
%%TODO - dyn worker doesnt send CLOSE DLG, we send it from Broker,
%% need to anaylize if it possible to send close directly from C code????
handle_cast({Worker, MsgType = ?map_msg_srv_req, PrimitiveType =?mapst_snd_rtism_rsp, DlgId, Data}, State)->
    {any, ?c_node} ! {MsgType, PrimitiveType, DlgId, Data},
    %%Data2 = list_to_binary([5, 0]),
    %%{any, ?c_node} ! {?map_msg_dlg_req, ?mapdt_close_req, DlgId, Data2},

    {noreply, State};

handle_cast({Worker, MsgType = ?map_msg_srv_req, PrimitiveType =?mapst_mt_fwd_sm_rsp, DlgId, Data}, State)->
    {any, ?c_node} ! {MsgType, PrimitiveType, DlgId, Data},
    %%Data2 = list_to_binary([5, 0]),
    %%{any, ?c_node} ! {?map_msg_dlg_req, ?mapdt_close_req, DlgId, Data2},

    {noreply, State};



handle_cast({Worker, MsgType, PrimitiveType, DlgId, Data}, State)->
    io:format("send back MAP MT FORWARD SM ACK to c node ~n"),
    {any, ?c_node} ! {MsgType, PrimitiveType, DlgId, Data},
    {noreply, State};


handle_cast(_Request, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%% messages from C node
%% @end
%%--------------------------------------------------------------------
-spec handle_info(Info :: timeout() | term(), State :: term()) ->
			 {noreply, NewState :: term()} |
			 {noreply, NewState :: term(), Timeout :: timeout()} |
			 {noreply, NewState :: term(), hibernate} |
			 {stop, Reason :: normal | term(), NewState :: term()}.
handle_info({start_worker_supervisor, Sup, MFA}, S = #state{}) ->
    {ok, Pid} = supervisor:start_child(Sup, ?SPEC(MFA)),
    link(Pid),
    {noreply, S#state{sup=Pid}};
%%--------------------------------------------------------------------
%% Process received dialog_open_ind from map_user c node
%%--------------------------------------------------------------------
handle_info({dlg_ind_open, DlgId, Data}, State) ->
%% start dynamic workerd for received dlg_ind_open
%%    {ok, Pid} = smsrouter_worker:start_link(DlgId),
    {ok, Pid} = supervisor:start_child(State#state.sup, [DlgId]),
    Ref = erlang:monitor(process, Pid),    

    ets:insert(didpid, {DlgId, Pid}),
    io:format("worker with pid started = ~p~n",[Pid]),
    gen_server:cast(Pid, {dlg_ind_open, Data}),
    {noreply, State};

handle_info({mapdt_open_cnf, DlgId, Data}, State) ->
    io:format("Receive dialog confirmation in broker~n"),
    [{_, Pid}] = ets:lookup(didpid, DlgId),
    gen_server:cast(Pid, {mapdt_open_cnf, Data}),
    {noreply, State};

handle_info({srv_ind, DlgId, Data}, State) ->
    io:format("srv ind received in broker with DlgId = ~p~n",[DlgId]),
    [{_, Pid}] = ets:lookup(didpid, DlgId),
    gen_server:cast(Pid, {srv_ind, Data}),
    {noreply, State};

handle_info({delimit_ind, DlgId, Data}, State) ->
    io:format("Receive delimit ind in broker~n"),
    [{_, Pid}] = ets:lookup(didpid, DlgId),
    gen_server:cast(Pid, {delimit_ind, Data}),
    {noreply, State};

handle_info({mapdt_close_ind, DlgId, Data}, State) ->
    io:format("Receive mapdt_close_ind in broker~n"),
    [{_, Pid}] = ets:lookup(didpid, DlgId),
    io:format("mapdt close ind in broker received: Pid = ~p, DlgId = ~p ~n",[Pid, DlgId]),
    gen_server:cast(Pid, {mapdt_close_ind, Data}),
    Q=State#state.o_dialogs,
    NewQueue = queue:in(DlgId, Q),
    NewState = State#state{o_dialogs=NewQueue},
    %%ets:delete(didpid, DlgId),
    %%ets:delete(piddid, Pid),

    {noreply, NewState};


handle_info({'EXIT',Pid, normal}, State)->
    io:format("~p exited with reason = ~p~n",[Pid, normal]),
    {noreply, State};

handle_info({'EXIT', Pid, Reason}, State)->
    io:format("~p exited with reason = ~p~n",[Pid, Reason]),
    {noreply, State};


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
test55(Name, Args) ->
    gen_server:call(Name, {test55, Args}).
