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

-define(cid_initial, 250270000000001).
-define(cid_default, 250270000000000).
-define(cid_maximum, 250270000500000).
-define(cid_increment, 1).

%% API
-export([start_link/4]).
-export([test55/2]).
-export([get_tables/0]).


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


-record(state, {cur_cid, %%currently used cid
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

init({Limit, MFA, Sup}) ->
%% We need to find the Pid of the worker supervisor from here,
%% but alas, this would be calling the supervisor while it waits for us!
    self() ! {start_worker_supervisor, Sup, MFA},

    Tables = create_tables(),

    CNode = case nodes(hidden) of
                [] ->
                    lager:warning("Node not connected, start discovering..."),
                    self() ! discover_cnode,
                    undefined;
                [Data] ->
                    lager:warning("Node ~p connected!",[Data]),
                    Data
            end,

    %%init queue for outgoing dialogues
    SeqList = lists:seq(0, 16000-1),
    Q = queue:from_list(SeqList),

    {ok, #state{limit=Limit, tabs = Tables, o_dialogs = Q, c_node = CNode}}.
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

    Cid = ets:update_counter(ids, cid, {2, ?cid_increment, ?cid_maximum, ?cid_initial}, {cid, ?cid_default}),
    {reply, Cid, State#state{cur_cid = Cid}};

handle_call(get_tables, _From, State) ->
    {reply, State#state.tabs, State};

%% receive request from worker to open outgoing dialogue
%% use call from dyn worker, not cast!
handle_call({?map_msg_dlg_req, ?mapdt_open_req, Data}, {Worker, _Tag}, State)->

    {{value, ODlgId}, NewQueue} = queue:out(State#state.o_dialogs),
    NewState = State#state{o_dialogs=NewQueue},
    {any, State#state.c_node} ! {?map_msg_dlg_req, ?mapdt_open_req, ODlgId, Data},
    ets:insert(didpid, {ODlgId, Worker}),
    {reply, ODlgId, NewState};

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
%% seems never used comment and then delete
%%handle_cast({Worker, MsgType = ?map_msg_dlg_req, PrimitiveType = ?mapdt_open_req, Data}, State)->
%%    io:format("map msg dlg req + mapdt open request ~n"),
%%    {{value, ODlgId}, NewQueue} = queue:out(State#state.o_dialogs),
%%    NewState = State#state{o_dialogs=NewQueue},
%%    {any, State#state.c_node} ! {MsgType, PrimitiveType, ODlgId, Data},
%%    ets:insert(didpid, {ODlgId, Worker}),
%%    io:format("didpid = ~p~n",[ets:tab2list(didpid)]),
%%    {noreply, NewState};

%send delimiter to map
handle_cast({_Worker, ?map_msg_dlg_req, ?mapdt_delimiter_req, Data}, State)->

    Data2 = list_to_binary([5, 0]),
    {any, State#state.c_node} ! {?map_msg_dlg_req, ?mapdt_delimiter_req, Data, Data2},
    {noreply, State};
%% used when SMSR should send SRI_SM request to HLR
%% but firts release of smsr should use this
handle_cast({Worker, MsgType = ?map_msg_srv_req, PrimitiveType = ?mapst_snd_rtism_req, Data}, State)->
    %%io:format("send back to c node ~n"),
%% TODO!! what about DlgId here!!!!
%% !!    [{_, ODlgId}] = ets:lookup(piddid, Worker),
%% uncomment this if above line uncommented    {any, State#state.c_node} ! {MsgType, PrimitiveType, ODlgId, Data},

%% maybe this is not good idea, but we send delimit automaticaly from broker
%% alternatives - send delimit from dyn worker or send delimit in C code ?
%% solution - use special parameter then no need for delim req or close req
    Data2 = list_to_binary([5, 0]),
%% !!    {any, State#state.c_node} ! {?map_msg_dlg_req, ?mapdt_delimiter_req, ODlgId, Data2},
    {noreply, State};
handle_cast({Worker, MsgType = ?map_msg_srv_req, PrimitiveType = ?mapst_snd_rtism_rsp, Data}, State)->
    io:format("send back to c node mapst_snd_rtism_rsp ~n"),
%% TODO!! what about DlgId here!!!!
%% !!    [{_, ODlgId}] = ets:lookup(piddid, Worker),
%% !!    {any, State#state.c_node} ! {MsgType, PrimitiveType, ODlgId, Data},
    {noreply, State};
handle_cast({_Worker, MsgType = ?map_msg_srv_req, PrimitiveType =
                 ?mapst_mo_fwd_sm_req, ODlgId, Data}, State)->
    io:format("send mo fwd sm req to c node ~n"),
%% TODO!! what about DlgId here!!!!
    %%[{_, ODlgId}] = ets:lookup(piddid, Worker),
    {any, State#state.c_node} ! {MsgType, PrimitiveType, ODlgId, Data},
    {noreply, State};

%%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
%%TODO - dyn worker doesnt send CLOSE DLG, we send it from Broker,
%% need to anaylize if it possible to send close directly from C code????
handle_cast({Worker, ?map_msg_srv_req, ?mapst_snd_rtism_rsp, DlgId, Data}, State)->
    io:format("send SRI_SM_ACK from smsrouter ~n"),
    {any, State#state.c_node} ! {?map_msg_srv_req, ?mapst_snd_rtism_rsp, DlgId, Data},
    %%Data2 = list_to_binary([5, 0]),
    %%{any, ?c_node} ! {?map_msg_dlg_req, ?mapdt_close_req, DlgId, Data2},

    {noreply, State};

handle_cast({Worker, WClass, ?map_msg_srv_req, ?mapst_mt_fwd_sm_rsp, DlgId, Data}, State)->
    ets:insert(pidwclass, {Worker, WClass}),
    {any, State#state.c_node} ! {?map_msg_srv_req, ?mapst_mt_fwd_sm_rsp, DlgId, Data},
    %%Data2 = list_to_binary([5, 0]),
    %%{any, ?c_node} ! {?map_msg_dlg_req, ?mapdt_close_req, DlgId, Data2},

    {noreply, State};

handle_cast({Worker, WClass, ?map_msg_srv_req, ?mapst_fwd_sm_rsp, DlgId, Data}, State)->
    io:format("send back MAP MT FORWARD SM ACK to c node and exactly
    to SMSC ~n"),
    ets:insert(pidwclass, {Worker, WClass}),
    {any, State#state.c_node} ! {?map_msg_srv_req, ?mapst_fwd_sm_rsp, DlgId, Data},
    {noreply, State};

handle_cast({_Worker, ?map_msg_srv_req, ?mapst_rpt_smdst_req, ODlgId, Data}, State) ->

    {any, State#state.c_node} ! {?map_msg_srv_req, ?mapst_rpt_smdst_req, ODlgId, Data},

    {noreply, State};

handle_cast({_Worker, ?map_msg_srv_req, ?mapst_rpt_smdst_rsp, DlgId, Data}, State) ->

    {any, State#state.c_node} ! {?map_msg_srv_req, ?mapst_rpt_smdst_rsp, DlgId, Data},

    {noreply, State};

handle_cast({Worker, MsgType, PrimitiveType, DlgId, Data}, State)->
    io:format("send back MAP MT FORWARD SM ACK to c node ~n"),
    {any, State#state.c_node} ! {MsgType, PrimitiveType, DlgId, Data},
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
handle_info({start_worker_supervisor, Sup, MFA}, State) ->
    {ok, Pid} = supervisor:start_child(Sup, ?SPEC(MFA)),
    link(Pid),
    {noreply, State#state{sup=Pid}};

handle_info(discover_cnode, State) ->
    CNode =case nodes(hidden) of
               [] ->
                   self() ! discover_cnode,
                   undefined;
               [Data] ->
                   lager:warning("Node ~p connected while discovering!",[Data]),
                   Data
           end,
{noreply, State#state{c_node = CNode}};
%%--------------------------------------------------------------------
%% Process received dialog_open_ind from map_user c node
%%--------------------------------------------------------------------
handle_info({dlg_ind_open, DlgId, Data}, State) ->
%% start dynamic worker for received dlg_ind_open
    {ok, Pid} = supervisor:start_child(State#state.sup, [initial_start, DlgId]),
    Ref = erlang:monitor(process, Pid),    
    ets:insert(mrefdlgid, {Ref, DlgId}),
    ets:insert(didpid, {DlgId, Pid}),
    gen_server:cast(Pid, {dlg_ind_open, DlgId, Data}),
    lager:warning("dlg_open_ind in broker received:Pid=~p,DlgId=~p",[Pid, DlgId]),
    {noreply, State};

handle_info({mapdt_open_cnf, DlgId, Data}, State) ->
    io:format("Receive dialog confirmation in broker~n"),
    [{_, Pid}] = ets:lookup(didpid, DlgId),
    gen_server:cast(Pid, {mapdt_open_cnf, DlgId, Data}),
    {noreply, State};

handle_info({srv_ind, DlgId, Data}, State) ->
    io:format("srv ind received in broker with DlgId = ~p~n",[DlgId]),
    [{_, Pid}] = ets:lookup(didpid, DlgId),
    gen_server:cast(Pid, {srv_ind, DlgId, Data}),
    {noreply, State};

handle_info({delimit_ind, DlgId, Data}, State) ->
    io:format("Receive delimit ind in broker~n"),
    [{_, Pid}] = ets:lookup(didpid, DlgId),
    gen_server:cast(Pid, {delimit_ind, DlgId, Data}),
    {noreply, State};

%%when broker receive dlg_close
%%then broker could delete entry from didpid ets?
handle_info({mapdt_close_ind, DlgId, Data}, State) ->

    [{_, Pid}] = ets:lookup(didpid, DlgId),
    lager:warning("mapdt_close_ind in broker received:Pid=~p,DlgId=~p",[Pid, DlgId]),
    gen_server:cast(Pid, {mapdt_close_ind, DlgId, Data}),
    Q=State#state.o_dialogs,
    NewQueue = queue:in(DlgId, Q),
    NewState = State#state{o_dialogs=NewQueue},
    ets:delete(didpid, DlgId),
    {noreply, NewState};

handle_info({'EXIT', Pid, Reason}, State)->
    io:format("~p exited with reason = ~p~n",[Pid, Reason]),
    {noreply, State};

%%receive DOWN message because SRI_SM worker finish work and shutdown
handle_info({'DOWN', MonitorRef, _Type, _Object, {shutdown, sri_sm_ok}}, State) ->
    [{_, DlgId}] = ets:take(mrefdlgid, MonitorRef),
    ets:delete(didpid, DlgId),
    {noreply, State};

handle_info({'DOWN', MonitorRef, _Type, Object, {shutdown, mt_sms_single_ok}}, State) ->
    [{_, WClass}] = ets:take(pidwclass, Object),

    case WClass of
        mt_sms_single ->
            [{_, DlgId}] = ets:take(mrefdlgid, MonitorRef),
            ets:delete(didpid, DlgId);
            %%when smsr handle single sms then 1 outgoing dlg_id also assigned on smsr
            %%this dlg id is for MO_FSM to SMSC TMT to send forwarded sms
%% !!            [{_, ODlgId}] = ets:take(piddid, Object),
%% !!            ets:delete(didpid, ODlgId);
        mt_sms_console ->
            [{_, DlgId}] = ets:take(mrefdlgid, MonitorRef),
            ets:delete(didpid, DlgId);
            %%when smsr handle single sms then 1 outgoing dlg_id also assigned on smsr
            %%this dlg id is for MO_FSM to SMSC TMT to send forwarded sms
%% !!            [{_, ODlgId}] = ets:take(piddid, Object),
%% !!            ets:delete(didpid, ODlgId);
        _-> do_nohting
    end,

    {noreply, State};

handle_info({'DOWN', MonitorRef, Type, Object, {shutdown, mt_sms_part}},
            State) ->
    io:format("mt sms worker kaput MonitorRef = ~p, Type = ~p, Object = ~p ~n",
              [MonitorRef, Type, Object]),

    [{_, DlgId}] = ets:take(mrefdlgid, MonitorRef),
    ets:delete(didpid, DlgId),
    
    {noreply, State};

handle_info({'DOWN', MonitorRef, _Type, _Object, {shutdown, rpt_smdst_cnf_ok}},
            State) ->

    [{_, DlgId}] = ets:take(mrefdlgid, MonitorRef),
    ets:delete(didpid, DlgId),
    {noreply, State};

handle_info({'DOWN', MonitorRef, Type, Object, {shutdown, mt_sms_concatenated_ok}},
            State) ->
    io:format("concatenated sms worker kaput MonitorRef = ~p, Type = ~p, Object = ~p ~n",
              [MonitorRef, Type, Object]),
    
    {noreply, State};

handle_info({'DOWN', MonitorRef, Type, Object, {shutdown, mo_sms_concatenated}},
            State) ->
    io:format("222 concatenated sms worker kaput MonitorRef = ~p, Type = ~p, Object = ~p ~n",
              [MonitorRef, Type, Object]),
    [{_, DlgId}] = ets:take(mrefdlgid, MonitorRef),
    ets:delete(didpid, DlgId),
    {noreply, State};

handle_info(Info, State) ->
    lager:error("unexpected message received: ~p",[Info]),
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


create_tables() ->
    
    [ ets:new(didpid, [set, named_table]),
      ets:new(mrefdlgid, [set, named_table]),
      ets:new(pidwclass, [set, named_table]),
      ets:new(cid, [set, public, named_table]),
      ets:new(ids, [set, public, named_table]), %%cid values generation             
      ets:new(parts, [bag, public, named_table]),
      ets:new(sri_sm, [set, public, named_table]),
      ets:new(db0, [set, public, named_table])
    ].

get_tables()->
    gen_server:call(?MODULE, get_tables).
    

