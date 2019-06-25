%% lets try to use feature0 - no need to send SRI SM to HLR,
%% always send already configured SRI_SM_ACK to SMSC
%% with fake IMSI

%% this should be used to construct binary to send to C node

%%my_list_to_binary(List) ->
%%    my_list_to_binary(List, <<>>).

%%my_list_to_binary([H|T], Acc) ->
%%    my_list_to_binary(T, <<Acc/binary,H>>);
%%my_list_to_binary([], Acc) ->
%%    Acc.
%%%-------------------------------------------------------------------
%%% @author root <root@ubuntu>
%%% @copyright (C) 2018, root
%%% @doc
%%%
%%% @end
%%% Created : 26 Nov 2018 by root <root@ubuntu>
%%%-------------------------------------------------------------------
-module(enode_dw).
-behaviour(gen_server).

-define(cid_update_interval, 300). %%after 5 minutes we should update
%%cid for pair msisdn&smsc which we got from incoming SRI_SM request 

%% API
-export([start_link/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, format_status/2]).

%%-include("dyn_defs.hrl").
-include("gctload.hrl").
-include("enode_broker.hrl").

-define(SERVER, ?MODULE).

-define(sccp_called, 1).
-define(sccp_calling, 3).
-define(ac_name, 11).
-define(dummy_dest, [16#0b, 16#12, 16#06, 0, 16#11, 16#04, 16#97, 16#05, 16#66, 16#15, 16#20, 16#0]).
-define(smsr_sccp_gt, [16#0b, 16#12, 16#08, 0, 16#11, 16#04, 16#97, 16#05, 16#66, 16#15, 16#20, 16#09]).
-define(smsc_sccp_gt, [16#0b, 16#12, 16#08, 0, 16#11, 16#04, 16#97, 16#05, 16#66, 16#15, 16#10, 0]).

%%used in MO_FORWARD_SM, actually SMSC
%%with type at the beginning
-define(sm_rp_da, [16#17, 16#09, 16#04, 16#07, 16#91, 16#97, 16#05, 16#66, 16#15, 16#10, 16#f0]).

-record(state, {subscriber_id, %%msisdn of subscirber, B num
                dlg_id,        %%dialog id, SRI_SM from HLR
                               %%or MT_FWD_SM from SMSC spawn the worker
          %%      tarantool,     %%connection to TT
                components =[],
                sccp_calling,
                sccp_called,
                ac_name,
                dlg_state,
                dlgs,  %% orddict [{dlg_id, #dlg_info}]
                wclass}).
%% wclass types:
%% worker class defined after component data handling
%% this is some kind of trick to stop worker after analyzing it component
%%
%%
%% sri_sm  --- worker for handling incoming SRI_SM and nothing else
%% mt_sms_single ---- this is single mt sms, worker will sendn mo_fsm and then we can stop worker
%% 
%% mt_sms_part_mms
%% mt_sms_part ----- worker receive mt_fsm save part data and close dialogue and exit
%% mo_sms_concatenated  ---- worker receive last part of sms(MT_FSM) and then do several mo_fsms for each part and should wait for returnresults
%%                             from smsc tmt and then worker exit


%%-record(dialog, {dlg_id,
%%                 tarantool,
%%		 components = [],
%%		 sccp_calling,
%%		 sccp_called,
%%		 ac_name}).

%%-record(dlg_info, {dlg_state,
%%                   components = []}).

%%-record(sccp, {sccp_calling, sccp_called, ac_name}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link(StartLevel :: atom(), DlgId :: integer())
                -> {ok, Pid :: pid()} |
                   {error, Error :: {already_started, pid()}} |
                   {error, Error :: term()} |
                   ignore.
start_link(StartLevel,DlgId) ->
%% we should start dynamic worker without registered name
    gen_server:start_link(?MODULE, [StartLevel, DlgId], []).
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
%% this is from skeleton init([]) ->
init([initial_start, DlgId])->

%%    {ok, TTconn} = taran:connect(),

%%    State = case taran:connect() of
%%                {ok, TTconn} -> #state{dlg_id = DlgId, tarantool = TTconn};
%%                _Other -> #state{dlg_id = DlgId, tarantool = fail}
%%            end,

%% start all modules running in dw process
%% this is wrong because we need tarantool connection only for SRI_SM
%% phase on smsrouter, should move to another place
%%    subscribers:start(),



    State = #state{dlg_id = DlgId, dlgs = orddict:new()},
    {ok, State}.

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
%%--------------------------------------------------------------------
%% Process received dialog_open_ind
%%--------------------------------------------------------------------
handle_cast({dlg_ind_open, DlgId, Request}, State) ->
    io:format("[~p]receive dlg ind open smsr worker ~p~n",[self(),Request]),
    %%io:format("i have state already ~p~n", [State]),
    parse_data(binary:bin_to_list(Request)),
    io:format("sccp_calling from PD = ~p~n",[get(sccp_calling)]),
    io:format("sccp_called from PD = ~p~n",[get(sccp_called)]),
    io:format("ac version atom = ~p~n", [get(ac_version_atom)]),

%% suppose we analyxe dlg_ind_open messages and SMSR allow to establish dialogue
%% Now let's send DLG_OPEN_RSP bask to C node!

%% {mapdt_open_rsp, DlgId, BinaryData}
%% should construct payload like this
%%  p810501000b0906070400000100140300
%% send open_resp after delimit ind received!!
%%    Payload = create_map_open_rsp_payload(),
%%    DlgId = State#dialog.dlg_id,
%%    gen_server:cast(broker, {order, ?map_msg_dlg_req, ?mapdt_open_rsp, DlgId, list_to_binary(Payload)}),
  
    Dlgs = State#state.dlgs,
%%orddict:store(DlgId, open, Dlgs),
%%TBD should check if this dialog already exist and opened and do
%% something in this case
    NewState = State#state{dlg_state = open, dlgs =
                               orddict:append(DlgId, {state, open}, Dlgs)},

    {noreply, NewState};

%%--------------------------------------------------------------------
%% Case - receive empty TCAP-BEGIN
%%--------------------------------------------------------------------
handle_cast({delimit_ind, _Request}, State = #state{dlg_state = open}) ->
%%    io:format("srv_ind received ~n"),
%%    Components = State#state.components,
%%    NewState = State#state{dlg_state = components = [ Request | Components ]},
%%    ok = parse_srv_data(binary:bin_to_list(Request)),
%%   io:format("invoke_id from PD = ~p~n",[get(invoke_id)]),
%%    io:format("msisdn from PD = ~p~n",[get(msisdn)]),
%%    io:format("sm rp pri name = ~p~n", [get(sm_rp_pri)]),
%%    io:format("sc addr = ~p~n", [get(sc_addr)]),

%% TODO - we receive delimit and we should analyze what kind of component we recevied bevoe in SRV_IND
%% component should be saved in State like component list
%% Payload here should be like
    Payload = create_map_open_rsp_payload(),
    DlgId = State#state.dlg_id,
    gen_server:cast(?enode_broker, {order, ?map_msg_dlg_req, ?mapdt_open_rsp, DlgId, list_to_binary(Payload)}),
    send_continue(DlgId),

    NewState = State#state{dlg_state = open_confirmed},
    {noreply, NewState};

%%handle_cast({srv_ind, Request}, State = #state{dlg_state = open} ) ->
handle_cast({srv_ind, DlgId, Request}, State ) ->
    %%io:format("srv_ind received in state OPEN ~n"),
    %%DlgInfo = proplists:get_value(DlgId, State#state.dlgs_info),

    Dlgs = State#state.dlgs,
    DlgInfo = orddict:fetch(DlgId, Dlgs),
    {state, DlgState} = lists:keyfind(state, 1, DlgInfo),


    case DlgState of
        open->
            io:format("srv_ind received in state OPEN ~n"),
            NewDlgInfo = [{state, open_waiting_for_delimit}, {components, Request}],
            NewDlgs = orddict:store(DlgId, NewDlgInfo, Dlgs),
            %%    ok = parse_srv_data(binary:bin_to_list(Request)),
            %%   io:format("invoke_id from PD = ~p~n",[get(invoke_id)]),
            %%    io:format("msisdn from PD = ~p~n",[get(msisdn)]),
            %%    io:format("sm rp pri name = ~p~n", [get(sm_rp_pri)]),
            %%    io:format("sc addr = ~p~n", [get(sc_addr)]),
            NewState = State#state{dlgs = NewDlgs},
            io:format("state in handle srv ind in state OPEN= ~p ~n", [NewState]),
            {noreply, NewState};
        open_confirmed->
            io:format("srv_ind received in state OPEN_CONFIRMED ~n"),
            NewDlgInfo = [{state, waiting_for_delimit}, {components, Request}],
            NewDlgs = orddict:store(DlgId, NewDlgInfo, Dlgs),
            NewState = State#state{dlgs = NewDlgs},
            io:format("state in handle srv ind in state OPEN CONFIRMED= ~p ~n", [NewState]),
            {noreply, NewState};
           
        _->
            {noreply, State}
    end;

%%--------------------------------------------------------------------
%% Case - receive empty TCAP-BEGIN
%% and then in the same transaction receive SRV_IND
%%--------------------------------------------------------------------
handle_cast({srv_ind, Request}, State = #state{dlg_state = open_confirmed} ) ->
    io:format("srv_ind received in state OPEN_CONFIRMED ~n"),
    Components = State#state.components,
    NewState = State#state{components = [ Request | Components ],
    dlg_state = waiting_for_delimit},
%%    ok = parse_srv_data(binary:bin_to_list(Request)),
%%   io:format("invoke_id from PD = ~p~n",[get(invoke_id)]),
%%    io:format("msisdn from PD = ~p~n",[get(msisdn)]),
%%    io:format("sm rp pri name = ~p~n", [get(sm_rp_pri)]),
%%    io:format("sc addr = ~p~n", [get(sc_addr)]),
    {noreply, NewState};

%% when smsr open outgoing dlg with some network node
%% then open_confirm received from remote node
handle_cast({mapdt_open_cnf, DlgId, _Request}, State) ->

 %%   case get(flag) of
%%	undefined ->
%%	    do_nothing;
%%	1 ->   
%%	    io:format("in mo_forward_sm_req function after cast ~n"),
	   %% io:format("sm rp oa ~p and tp da ~p in mo forward sm req ~n", [Sm_Rp_Oa, Tp_Da]),
%%	    Payload2 = mo_forwardSM(get(smrpoa),get(tpda)),
%%	    gen_server:cast(broker, {self(), ?map_msg_srv_req, ?mapst_mo_fwd_sm_req, list_to_binary(Payload2)})
  %%  end,
    Dlgs = State#state.dlgs,
%%orddict:store(DlgId, open, Dlgs),
%%TBD should check if this dialog already exist and opened and do
%% something in this case
    NewState = State#state{dlgs = orddict:append(DlgId, {state, open_confirmed}, Dlgs)},
    {noreply, NewState};

%%handle_cast({delimit_ind, Request}, State = #state{dlg_state = open_waiting_for_delimit}) ->
handle_cast({delimit_ind, DlgId, _Request}, State) ->
    io:format("delimit ind 1 ~n"),

    %%send DLG_OPEN_RSP
%%    Payload = create_map_open_rsp_payload(),
%%    DlgId = State#state.dlg_id,

%%    gen_server:cast(?enode_broker, {order, ?map_msg_dlg_req, ?mapdt_open_rsp, DlgId, list_to_binary(Payload)}),
    
    Dlgs = State#state.dlgs,
    DlgInfo = orddict:fetch(DlgId, Dlgs),
    {state, DlgState} = lists:keyfind(state, 1, DlgInfo),
%%    {components, Components} = lists:keyfind(components, 1, DlgInfo),

    case DlgState of 
        %%receive empty TCAP-BEGIN
        %% Belline use mapv3
        open ->
            Payload = create_map_open_rsp_payload(),
%%            DlgId = State#state.dlg_id,
            gen_server:cast(?enode_broker, {order, ?map_msg_dlg_req, ?mapdt_open_rsp, DlgId, list_to_binary(Payload)}),
            send_continue(DlgId),
            
            %% NewState = State#state{dlg_state = open_confirmed},
            false = lists:keyfind(components, 1, DlgInfo),

           NewDlgInfo = [{state, open_confirmed}],
            NewDlgs = orddict:store(DlgId, NewDlgInfo, Dlgs),
            %%    ok = parse_srv_data(binary:bin_to_list(Request)),
            %%   io:format("invoke_id from PD = ~p~n",[get(invoke_id)]),
            %%    io:format("msisdn from PD = ~p~n",[get(msisdn)]),
            %%    io:format("sm rp pri name = ~p~n", [get(sm_rp_pri)]),
            %%    io:format("sc addr = ~p~n", [get(sc_addr)]),
            NewState = State#state{dlgs = NewDlgs},
            {noreply, NewState};

        open_waiting_for_delimit ->
    %%send DLG_OPEN_RSP
            io:format("open_waiting_for_delimit ~n"),
            Payload = create_map_open_rsp_payload(),
            %%    DlgId = State#state.dlg_id,
            gen_server:cast(?enode_broker, {order, ?map_msg_dlg_req, ?mapdt_open_rsp, DlgId, list_to_binary(Payload)}),
    
            {components, Components} = lists:keyfind(components, 1, DlgInfo),
            case handle_service_data(Components,DlgId) of
                sri_sm ->
                    {stop, {shutdown, sri_sm_ok}, State};

                rsds ->
                    lager:warning("reportSMdeliveryStatus from SMSC received"),
                    NewDlgInfo = [{state, open_confirmed}],
                    NewDlgs = orddict:store(DlgId, NewDlgInfo, Dlgs),
                    NewState = State#state{dlgs = NewDlgs},
                   
                    {noreply, NewState};
                %%recieved part of sms, stop worker
                {mt_fsm, mt_sms_part} ->
                       {stop, {shutdown, mt_sms_part}, State};

                %%receive non text mt sms
                {mt_fsm, mt_sms_special} ->
                       {stop, {shutdown, mt_sms_special}, State};

                {mt_fsm, mt_sms_part_mms} ->

                    NewDlgInfo = [{state, open_confirmed}],
                    NewDlgs = orddict:store(DlgId, NewDlgInfo, Dlgs),
                    NewState = State#state{dlgs = NewDlgs},
                    {noreply, NewState};

                {mt_fsm, WClass} ->
                    NewState = State#state{dlg_state = open_confirmed, wclass
                                           = WClass},
                    {noreply, NewState};
                _Other->
                    NewState = State#state{dlg_state = open_confirmed},
                    {noreply, NewState}
            end;
        
        waiting_for_delimit ->
            {components, Components} = lists:keyfind(components, 1, DlgInfo),
            io:format("waiting_for_delimit ~n"),
            case handle_service_data(Components, DlgId) of
                sri_sm ->
                    {stop, {shutdown, sri_sm_ok}, State};

                {mt_fsm, mt_sms_part} ->
                    {stop, {shutdown, mt_sms_part}, State};

                {mt_fsm, mt_sms_part_mms} ->

                    NewDlgInfo = [{state, open_confirmed}],
                    NewDlgs = orddict:store(DlgId, NewDlgInfo, Dlgs),
                    NewState = State#state{dlgs = NewDlgs},
                    {noreply, NewState};


                %% mt_sms_part_mms  --- do not stop worker
                %% mo_sms_concatenated --- do not stop worker,wait all
                %% returnresult from SMSC TMT
                {mt_fsm, WClass} ->
                    NewState = State#state{dlg_state = open_confirmed, wclass
                                           = WClass},
                    {noreply, NewState};
                _Other->
                    NewState = State#state{dlg_state = open_confirmed},
                    {noreply, NewState}
            end
                
    end;

%%--------------------------------------------------------------------
%% Process received delimit_ind
%% this is not the case when YOTA smsc send mt fsm in mapv1
%%--------------------------------------------------------------------
handle_cast({delimit_ind, DlgId, Request}, State = #state{dlg_state = waiting_for_delimit}) ->
            io:format("delimit ind 2 ~n");

%%    case handle_service_data(State, DlgId) of
%%        sri_sm ->
%%            {stop, {shutdown, sri_sm_ok}, State};
%%        {mt_fsm, WClass} ->
%%            NewState = State#state{dlg_state = open_confirmed, wclass
%%                                   = WClass},
%%            {noreply, NewState};
%%        _Other->
%%            NewState = State#state{dlg_state = open_confirmed},
%%            {noreply, NewState}
%%    end;

handle_cast({mapdt_close_ind, DlgId,_Request}, State) ->


    Dlgs = State#state.dlgs,
    DlgInfo = orddict:fetch(DlgId, Dlgs),
    {state, DlgState} = lists:keyfind(state, 1, DlgInfo),
    {components, Components} = lists:keyfind(components, 1, DlgInfo),

    case component:handle_service_data(Components) of
	?mapst_snd_rtism_cnf ->
            send_sri_sm_ack(State#state.components, State#state.dlg_id, fix_it),
            {stop, normal, State};
	?mapst_mo_fwd_sm_cnf ->
            %% should process received ReturnResult from SMSC TMT
            case State#state.wclass of
                mt_sms_single ->
                    {stop, {shutdown, mt_sms_single_ok}, State};
                mt_sms_console ->
                    {stop, {shutdown, mt_sms_single_ok}, State};
                mt_sms_part->
                    submission:submit_confirmed(),
                    case submission:get_confirmation_status() of 
                        all_confirmed ->
                            io:format("all sms confirmed from smsc tmt ~n"),
                            {stop, {shutdown, mt_sms_concatenated_ok}, State};
                        confirmation_ongoing ->
                            io:format("confirmation from smsc tmt ongoing ~n"),
                            {noreply, State}
                    end;
                mo_sms_concatenated ->
                    submission:submit_confirmed(),
                    case submission:get_confirmation_status() of 
                        all_confirmed ->
                            io:format("all sms confirmed from smsc tmt ~n"),
                            {stop, {shutdown, mo_sms_concatenated}, State};
                        confirmation_ongoing ->
                            io:format("confirmation from smsc tmt ongoing ~n"),
                            {noreply, State}
                    end;
                _ -> 
                    io:format("received mo_forward_sm confirmation from SMSC TMT ~n"),
                    io:format("mo forward sm returned result!~n"),
                    io:format("user err = ~p~n", [get(user_err)]),
                    {stop, normal, State}
            end;
        ?mapst_rpt_smdst_cnf -> 
            {stop, {shutdown, rpt_smdst_cnf_ok}, State};
	_Other->
	    io:format("!!!!!!!!!!!!!!!!!!!!!!!!!1unexpected error ~n"),
	    true,
            {stop, normal, State}
    end.
     
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
terminate({shutdown, sri_sm_ok} , _State) ->
    subscribers:stop(),
    ok;

terminate({shutdown, mt_sms_part} , _State) ->
    io:format("gen_server with pid = ~p terminated after mt_sms_part handling ~n",[self()]),
    ok;


terminate({shutdown, mt_sms_single_ok} , _State) ->
    %%subscribers:stop(),
    io:format("gen_server with pid = ~p terminated after mt_sms_single handling ~n",[self()]),
    ok;

terminate({shutdown, mt_sms_concatenated_ok}, _State) ->
    
    io:format("gen_server with pid = ~p terminated after mt_sms_concatenated handling ~n",[self()]),
    ok;

terminate({shutdown, mo_sms_concatenated}, _State) ->
    io:format("gen_server with pid = ~p terminated after mo_sms_concatenated handling ~n",[self()]),
    ok;

terminate({shutdown, rpt_smdst_cnf_ok}, _State) ->
    lager:warning("rpt_smdst_cnf from HLR received,worker terminated"),
    ok;

terminate({shutdown, mt_sms_special}, _State) ->
    lager:warning("mt_sms special received,worker terminated"),
    ok;

terminate(_Reason, _State) ->
    io:format("gen_server with pid = ~p terminated with terminate callback ~n",[self()]),
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
send_continue(DlgId)->
    gen_server:cast(?enode_broker, {self(), ?map_msg_dlg_req, ?mapdt_delimiter_req, DlgId}).

%%%===================================================================
%%% Handle components data in smsrouter

%%% Actually supposed that could be only one component in signalling data
%%% but this could be wrong!!!!
%%% If we have component data - then we should handle it!
%%%===================================================================
handle_service_data(Components,DlgId)->

    case component:handle_service_data(Components) of
	?mapst_snd_rtism_ind ->

            subscribers:start(),

	    Msisdn = get(msisdn),
            Smsc = get(sc_addr),
            Key = Msisdn ++ Smsc,

            Now = erlang:monotonic_time(),

            case ets:lookup(sri_sm, Key) of
                [] ->
                    io:format("key not found in sri_sm table ~n"),
                    Cid = get_cid(),
                    %%                    Result_ = ets:update_counter(sri_sm, Key, {3,1} , {Key,Cid,0});
                    _Result = ets:insert(sri_sm, {Key, Cid, Now}),
                    Tp_da = subscribers:get_cnum(Msisdn),
                    ets:insert(cid, {bcd:encode(imsi, Cid), Msisdn, Tp_da});
          
                [{_, OldCid, Timestamp}] ->

                    TimeDiff = erlang:convert_time_unit(Now - Timestamp, native,
                                                        second),
                    
                    case TimeDiff < ?cid_update_interval of
                        
                        false ->
                            io:format("need update cid ~n"),
                            Cid = get_cid(),
                            ets:insert(sri_sm, {Key, Cid, Now}),
                            Tp_da = subscribers:get_cnum(Msisdn),
                            ets:insert(cid, {bcd:encode(imsi, Cid), Msisdn, Tp_da});
                        true ->
                            Cid = OldCid,
                            io:format("use same cid just update timestamp ~n"),
                            ets:update_element(sri_sm, Key, {3, Now})
                    end

%%                    Result_ = ets:update_counter(sri_sm, Key, {3,1})
            end,
%%            Tp_da = subscribers:get_cnum(Msisdn),
%%	    ets:insert(cid, {bcd:encode(imsi, Cid), Msisdn, Tp_da}),
            io:format("Cid table in sri_sm part = ~p~n", [ets:tab2list(cid)]),
%%	    sri_sm_req(State#dialog.components);
	    send_sri_sm_ack(Components, DlgId, Cid),
            sri_sm;

        ?mapst_rpt_smdst_ind ->
        %%reportSm-deliveryStatus received from SMSC
        %%we should send it to HLR
            send_rpt_smdst_ack(DlgId),
            hlr_agent:invoke_reportSM_DeliveryStatus(Components),
            rsds;

	?mapst_mt_fwd_sm_ind ->
            %%MT_FSM_v3 received in incoming component
            
            [_Type | [Length | Imsi  ]] = get(sm_rp_da),
            %%Ref = sm_rp_ui:get_ref(),
            %%Key = Imsi ++ [Ref],

            case {get(more_msg), get(ac_version_atom)} of
                {1, shortMsgMTRelayContext_v3} ->

                    %%if max_num = 1 then
                    %% smsc tmt console case
                    %% max num = part num =1 and moremsg flat = 1
                    %%smsr should send mo_fsm and close dialogue!!
                    %%if we didn't close then
                    %%we can mix sms on smsr because refs the same always
                    %%YandexMoney case - also could be single sms with
                    %% moremessagetosend=1(from smsc tmt)

                    case sm_rp_ui:check_sms_type() of
                        {sms_no_header, 0} ->
                            lager:warning("map3;mms;mt_sms without header,relay to smsc;dlg=~p", [DlgId]),
                            WClass = mt_sms_single_mms,
                            put(more_msg, undefined),
                            mt_forward_sm_ack_continue(DlgId),
                            [{_Cid, Sm_rp_oa, Tp_da}] = ets:lookup(cid, list_to_binary(Imsi)),
                            mo_forward_sm_req(Sm_rp_oa, Tp_da);
                        {sms_with_header, 0} ->
                            lager:warning("map3;mms;mt_sms special,do not process;dlg=~p", [DlgId]),
                            %%mt_sms with header but not concatenated, some special sms
                            %% may be binary, wap push mms notifier and so on
                            WClass = mt_sms_special_mms,
                            %%we do not process,just send returnresult and do nothing,
                            %%do not forward this type of sms
                            mt_forward_sm_ack(DlgId, WClass);
                       
                        {sms_part, PartData}->

                            MaxNum = case get(max_num) of
                                         undefined ->
                                             sm_rp_ui:get_maxnum();
                                         Value ->
                                             Value
                                     end,
                            
                            WClass = if
                                         MaxNum =:= 1->
                                             lager:warning("map3;mms;max_num=1;mt_console,relay to smsc;dlg=~p", [DlgId]),
                                             mt_forward_sm_ack(DlgId, mt_sms_console),
                                             [{_Cid, Sm_rp_oa, Tp_da}] = ets:lookup(cid, list_to_binary(Imsi)),
                                             mo_forward_sm_req(Sm_rp_oa, Tp_da),
                                             mt_sms_console;
                                         true ->
                                             put(max_num, MaxNum),
                                             
                                             Ref = sm_rp_ui:get_ref(),
                                             Key = Imsi ++ [Ref],
                                             ets:insert(parts, {Key, get(sm_rp_ui_mv)}),
                                             put(more_msg, undefined),
                                             mt_forward_sm_ack_continue(DlgId),
                                             
                                             PartsReceived = case get(parts_received) of
                                                                 undefined ->
                                                                     1;
                                                                 Parts ->
                                                                     Parts+1
                                                             end,
                                             put(parts_received, PartsReceived),
                                             
                                             ets:insert(db0, {Key, MaxNum, PartsReceived}),
                                             mt_sms_part_mms
                                     end
                    end;
%%                    Ref = sm_rp_ui:get_ref(),
%%                    Key = Imsi ++ [Ref],
%%                    ets:insert(parts, {Key, get(sm_rp_ui_mv)}),
%%                    put(more_msg, undefined),
%%                    mt_forward_sm_ack_continue(State#state.dlg_id),

%%                    PartsReceived = case get(parts_received) of
%%                                       undefined ->
%%                                           1;
%%                                       Parts ->
%%                                           Parts+1
%%                                   end,
%%                    put(parts_received, PartsReceived),
                    %%MaxNum = sm_rp_ui:get_maxnum(),
                    %%put(max_num, MaxNum)

                    %%MaxNum = case get(max_num) of
                     %%            undefined ->
                     %%                sm_rp_ui:get_maxnum();
                     %%            Value ->
                     %%                Value
                     %%        end,
                    %%put(max_num, MaxNum),
                    %%MaxNum = sm_rp_ui:get_maxnum(),
                    %%put(max_num, MaxNum)


                    %% need to use some more elegant solution to check
                    %% if this is sms from smsc tmt console (part=max=1)
                    %%WClass = if
                     %%            MaxNum =:= 1->
                     %%                mt_sms_console;
                     %%            true ->
                     %%                mt_sms_part
                     %%        end,

                    %%
                    %% should store in ets, becauser worker may be exited
                    %%
                    
                    %%ets:insert(db0, {Key, MaxNum, PartsReceived}),
                    %%WClass = mt_sms_part;
                
                {undefined, shortMsgMTRelayContext_v3}->
                    %% could be next cases: 
                    %% we still in the same transaction or
                    %% we in another transaction (another worker)
                    %% also this is the case when we send simple sms from smsc console and 
                    %% smsc tmt send it like concatenated with part=1 maxnum = 1
                    case sm_rp_ui:check_sms_type() of
                        {sms_no_header, 0} ->
                            lager:warning("map3;mt_sms without header,relay to smsc;dlg=~p", [DlgId]),
                            WClass = mt_sms_single,
                            mt_forward_sm_ack(DlgId, WClass),
                            %%Sm_rp_da = get(sm_rp_da),
                            %%[_Type | [Length | Imsi  ]] = Sm_rp_da,
                            %%ImsiL = bcd:decode(imsi, list_to_binary(Imsi)),
                            [{_Cid, Sm_rp_oa, Tp_da}] = ets:lookup(cid, list_to_binary(Imsi)),
                            mo_forward_sm_req(Sm_rp_oa, Tp_da);
                        {sms_with_header, 0} ->
                            %%mt_sms with header but not concatenated, some special sms
                            %% may be binary, wap push mms notifier and so on
                            lager:warning("map3;mt_sms special,do not process;dlg=~p", [DlgId]),
                            WClass = mt_sms_special,
                            %%we do not process,just send returnresult and do nothing,
                            %%do not forward this type of sms
                            mt_forward_sm_ack(DlgId, WClass);
                        {sms_part, PartData}->                    
                            
                            %%Ref = sm_rp_ui:get_ref(),
                            %%Key = Imsi ++ [Ref],

                            %%put(parts_received, PartsReceived),
                            %%ets:insert(db0, {Key, PartsReceived})

                            MaxNum = case get(max_num) of
                                undefined ->
                                    sm_rp_ui:get_maxnum();
                                Value ->
                                    Value
                                     end,

                            %% need to use some more elegant solution to check
                            %% if this is sms from smsc tmt console (part=max=1)
                            WClass = if
                                         MaxNum =:= 1->
                                             lager:warning("map3;max_num=1;mt_console,relay to smsc;dlg=~p", [DlgId]),
                                             mt_forward_sm_ack(DlgId, mt_sms_console),
                                             [{_Cid, Sm_rp_oa, Tp_da}] = ets:lookup(cid, list_to_binary(Imsi)),
                                             mo_forward_sm_req(Sm_rp_oa, Tp_da),
                                             mt_sms_console;
                                         true ->
                                             
                                             Ref = sm_rp_ui:get_ref(),
                                             Key = Imsi ++ [Ref],
                                             ets:insert(parts, {Key,  get(sm_rp_ui_mv)}),
                                             mt_forward_sm_ack(DlgId, mt_sms_part),

                                             PartsReceived = case get(parts_received) of
                                                                 undefined ->
                                                                     
                                                                     case ets:lookup(db0, Key) of
                                                                         [] ->
                                                                             ets:insert(db0, {Key, MaxNum, 1}),
                                                                             1;
                                                                         [{Key, _, _Value2}] ->
                                                                             ets:update_counter(db0,Key,{3,1})
                                                                     end;
                                                                 _Value -> ets:update_counter(db0,Key,{3,1})
  
                                                             end,
                                             if
                                                 MaxNum =:= PartsReceived->
                                                     [{_Cid, Sm_rp_oa, Tp_da}] = ets:lookup(cid, list_to_binary(Imsi)),
                                                     mo_forward_sm_req_concatenated(Sm_rp_oa, Tp_da, Key),
                                                     %% TODO
                                                     %% need to check if no race conditions and errors!!
                                                     %% when another worker use the same Key at the same moment
                                                     ets:delete(parts, Key),
                                                     mo_sms_concatenated;
                                                 true ->
                                                     %%Result_ = ets:update_counter(db0,Key,{3,1})
                                                     mt_sms_part
                                             end
                                             %%io:format("stay after mo forward sm~n"),
                                             %%mt_sms_part
                                     end
                    end
            end,
            {mt_fsm, WClass};

	?mapst_fwd_sm_ind -> %%smsc use mapv2 forward_sm instead of mt forward sm
            %% MT_FSM_v1_v2 received in component
            [_Type | [_Length | Imsi  ]] = get(sm_rp_da),
            io:format("Imsi = ~p~n", [Imsi]),
            case sm_rp_ui:check_sms_type() of
                {sms_no_header, 0} ->
                    WClass = mt_sms_single,
                    forward_sm_ack(DlgId, WClass),
                    %%Sm_rp_da = get(sm_rp_da),
                    %%[_Type | [Length | Imsi  ]] = Sm_rp_da,
                    %%ImsiL = bcd:decode(imsi, list_to_binary(Imsi)),
                    [{_Cid, Sm_rp_oa, Tp_da}] = ets:lookup(cid, list_to_binary(Imsi)),
                    mo_forward_sm_req(Sm_rp_oa, Tp_da);
                {sms_with_header, 0} ->
                            %%mt_sms with header but not concatenated, some special sms
                            %% may be binary, wap push mms notifier and so on
                            WClass = mt_sms_special,
                            %%we do not process,just send returnresult and do nothing,
                            %%do not forward this type of sms
                            forward_sm_ack(DlgId, WClass);
                {sms_part, PartData} ->
%%                    WClass = mt_sms_part,
  %%                  forward_sm_ack(DlgId, WClass),
  
                  %%case get(all_parts_received) of
                    %%   undefined -> forward_sm_ack_continue(State#state.dlg_id);
                    %%   _ ->
                    Ref = sm_rp_ui:get_ref(),
                    Key = Imsi ++ [Ref],

%% for this map versions differnet parts will go in differnet transactions
%% meand different workers will handle thm
%% need analyze do we need to use process dictionayr here

                    MaxNum = sm_rp_ui:get_maxnum(),
                           
                    PartsReceived = case ets:lookup(db0, Key) of
                                                [] ->
                                                    ets:insert(db0, {Key, MaxNum, 1}),
                                                    1;
                                                [{Key, _, _Value2}] ->
                                                    ets:update_counter(db0,Key,{3,1})
                                    end,
                    
                    %%forward_sm_ack(State#state.dlg_id),
                    ets:insert(parts, {Key, get(sm_rp_ui_mv)}),
                    %%     Sm_rp_da = get(sm_rp_da),
                    %%    [_Type | [Length | Imsi  ]] = Sm_rp_da,
                    %%ImsiL = bcd:decode(imsi, list_to_binary(Imsi)),

                    if
                        MaxNum =:= PartsReceived ->
                            WClass = mo_sms_concatenated,
                            forward_sm_ack(DlgId, WClass),
                  
                            io:format("cid table = ~p~n",[ets:tab2list(cid)]),
                            [{_Cid, Sm_rp_oa, Tp_da}] = ets:lookup(cid, list_to_binary(Imsi)),
                            %%mo_sms:create_sms_submits(Sm_rp_oa, Tp_da, Key),
                            %%[{_Cid, Sm_rp_oa, Tp_da}] = ets:lookup(cid, list_to_binary(Imsi)),
                            mo_forward_sm_req_concatenated(Sm_rp_oa, Tp_da, Key),
                            %% ??? should we delete in here?
                            ets:delete(parts, Key);
                        true ->
                            WClass = mt_sms_part,
                            forward_sm_ack(DlgId, WClass),
                  
                            %%Result_ = ets:update_counter(db0,Key,{3,1})
                            do_nothing
                    end,
                    io:format("stay after mo forward sm~n")
                                                
                    %%[{_Cid, Sm_rp_oa, Tp_da}] = ets:lookup(cid, list_to_binary(Imsi)),
                    %%mo_forward_sm_req(Sm_rp_oa, Tp_da),
%%                    io:format("stay after mo forward sm all parts received~n")
                    %%end
            end,
            {mt_fsm, WClass};
        
	_Other->
	    io:format("suddenly true ~n"),
	    true
    end.


sri_sm_req(Components)->
    io:format("in sri sm req function ~n"),
%% p010b09060704000001001403010b1206001104970566152000030b120800110497056615200900
%% also we should choos dlg id for outgoing dlgs
    Payload = create_map_open_req_payload(),
    gen_server:cast(?enode_broker, {self(), ?map_msg_dlg_req, ?mapdt_open_req, list_to_binary(Payload)}),
%% payload here

io:format("in srim sm req function after cast ~n"),
 
    Payload2 = map_srv_req_primitive(snd_rtism_req, Components),
    gen_server:cast(?enode_broker, {self(), ?map_msg_srv_req, ?mapst_snd_rtism_req, Payload2}).

%%%-----------------------------------------------------------------------------
%% @doc
%% send MAP_SRI_SM_ACK to SMSC
%% should construct parameters for MAP_SRI_SM_ACK as in example
%% p81 0e01b5 120852200701304377f7 1307919705661520f900
%% also in this function we should change trueIMSI to Correlationid
%% @spec
%% @end
%%--------------------------------------------------------------------
send_sri_sm_ack(Components, DlgId, Cid)->
%%    Payload = map_msg_srv_req(),
%%    Cid = get(cid),
    Fimsi= bcd:encode(imsi, Cid),
    Payload = construct_sri_sm_ack(Fimsi),
%%    Payload x= [16#81,  16#0e, 16#01, 16#b5,   16#12, 16#08, 16#52, 16#20,
%%	       16#07, 16#01, 16#30, 16#43, 16#77, 16#f7,  16#13, 16#07,
%%	       16#91, 16#97, 16#05, 16#66, 16#15, 16#20, 16#f9, 16#00],
    gen_server:cast(?enode_broker, {self(), ?map_msg_srv_req, ?mapst_snd_rtism_rsp, DlgId, list_to_binary(Payload)}).


%% function that need deep refactoring then!
%% here we should construct valid service payload
%% to reply to SMSC with needed SRI_SM_ACK with changed imsi
-spec construct_sri_sm_ack(binary()) -> [integer()].
construct_sri_sm_ack(Imsi)->
    Invoke = get(invoke_id),
    InvokeId = [?mappn_invoke_id, 1] ++ Invoke,
    ImsiParam = [?mappn_imsi, 16#08] ++  binary_to_list(Imsi),
%%smsr gt as smsc, we need to intercept mt sms
    Other = [16#13, 16#07, 16#91, 16#97, 16#05,
	     16#66, 16#15, 16#20, 16#f9] ++
	[?mappn_dialog_type,1,?mapdt_close_req, ?mappn_release_method, 1, 0, 0],
    [?mapst_snd_rtism_rsp] ++ InvokeId ++ ImsiParam ++ Other.

%%send ReturnResult to SMSC on report-SMdeliveryStatus
send_rpt_smdst_ack(DlgId) ->
    Invoke = get(invoke_id),
    InvokeId = [?mappn_invoke_id, 1] ++ Invoke,
    Other = [?mappn_dialog_type,1,?mapdt_close_req, ?mappn_release_method, 1, 0, 0],
    Payload = [?mapst_rpt_smdst_rsp] ++ InvokeId ++ Other,
    gen_server:cast(?enode_broker, {self(), ?map_msg_srv_req, ?mapst_rpt_smdst_rsp, DlgId, list_to_binary(Payload)}).
%%% function to send MT_FORWARD_SM_ACK to SMSC
%%%
%%% 
mt_forward_sm_ack(DlgId, WClass)->
%%    Payload = map_msg_srv_req(),
%%    CorrelationId = get(correlationid),
%%    Fimsi= bcd:encode(imsi, CorrelationId),
%%    Payload = construct_sri_sm_ack(Fimsi),
    Invoke = get(invoke_id),
    InvokeId = [?mappn_invoke_id, 1] ++ Invoke,

    Payload = [?mapst_mt_fwd_sm_rsp] ++ InvokeId ++
	[?mappn_sm_rp_ui, 16#02, 16#0, 16#0,
	 ?mappn_dialog_type, 1, ?mapdt_close_req, ?mappn_release_method, 1, 0, 16#00],
    gen_server:cast(?enode_broker, {self(), WClass, ?map_msg_srv_req, ?mapst_mt_fwd_sm_rsp, DlgId, list_to_binary(Payload)}).

%%% function to send MT_FORWARD_SM_ACK to SMSC
%%% this is when SMSS use mapv3 context MT_FORWARD_SM 
%%% but we didn't close dialogue we send Continue
%%% attempt to receive all parts of concatenated msgs in one transaction
%%% ?mappn_sm_rp_ui, 16#02, 16#0, 16#0,  --- SMS-DELIVER-REPORT
mt_forward_sm_ack_continue(DlgId)->
%%    Payload = map_msg_srv_req(),
%%    CorrelationId = get(correlationid),
%%    Fimsi= bcd:encode(imsi, CorrelationId),
%%    Payload = construct_sri_sm_ack(Fimsi),
    Invoke = get(invoke_id),
    InvokeId = [?mappn_invoke_id, 1] ++ Invoke,

    Payload = [?mapst_mt_fwd_sm_rsp] ++ InvokeId ++
	[?mappn_sm_rp_ui, 16#02, 16#0, 16#0,
	 ?mappn_dialog_type, 1, ?mapdt_delimiter_req, 16#00],
    gen_server:cast(?enode_broker, {self(), ?map_msg_srv_req, ?mapst_mt_fwd_sm_rsp, DlgId, list_to_binary(Payload)}).


%%map v2 used to sent sms from foreign SMSC
forward_sm_ack(DlgId, Wclass)->
%%    Payload = map_msg_srv_req(),
%%    CorrelationId = get(correlationid),
%%    Fimsi= bcd:encode(imsi, CorrelationId),
%%    Payload = construct_sri_sm_ack(Fimsi),
    Invoke = get(invoke_id),
    InvokeId = [?mappn_invoke_id, 1] ++ Invoke,

    Payload = [?mapst_fwd_sm_rsp] ++ InvokeId ++
	       %%16#0e, 16#01, 16#01,   %%invoke_id   
	       %%?mappn_sm_rp_ui, 16#02, 16#0, 16#0,
	       [?mappn_dialog_type, 1, ?mapdt_close_req, ?mappn_release_method, 1, 0,  16#00],
    gen_server:cast(?enode_broker, {self(), Wclass, ?map_msg_srv_req, ?mapst_fwd_sm_rsp, DlgId, list_to_binary(Payload)}).

forward_sm_ack_continue(DlgId)->
%%    Payload = map_msg_srv_req(),
%%    CorrelationId = get(correlationid),
%%    Fimsi= bcd:encode(imsi, CorrelationId),
%%    Payload = construct_sri_sm_ack(Fimsi),
    Invoke = get(invoke_id),
    InvokeId = [?mappn_invoke_id, 1] ++ Invoke,

    Payload = [?mapst_fwd_sm_rsp] ++ InvokeId ++
	       %%16#0e, 16#01, 16#01,   %%invoke_id   
	       %%?mappn_sm_rp_ui, 16#02, 16#0, 16#0,
	       [?mappn_dialog_type, 1, ?mapdt_delimiter_req,  16#00],
    gen_server:cast(?enode_broker, {self(), ?map_msg_srv_req, ?mapst_fwd_sm_rsp, DlgId, list_to_binary(Payload)}).


%%% function to send MO FORWARD SM to SMSC
%%%
%%% smsrouter act as MSC sending MO FORWARD SM to SMS

mo_forward_sm_req(Sm_Rp_Oa, Tp_Da)->
    io:format("in mo_forward_sm_req function ~n"),
    Payload = create_map_open_req_payload2(),
    %%gen_server:cast(?enode_broker, {self(), ?map_msg_dlg_req, ?mapdt_open_req, list_to_binary(Payload)}),

    put(smrpoa, Sm_Rp_Oa),
    put(tpda, Tp_Da),
    
    io:format("in mo_forward_sm_req function after cast ~n"),
    io:format("sm rp oa ~p and tp da ~p in mo forward sm req ~n", [Sm_Rp_Oa, Tp_Da]),
    Payload2 = mo_forwardSM(Sm_Rp_Oa, Tp_Da),

    lists:foreach(fun(Payload_mofsm)->
                          ODlgId = gen_server:call(?enode_broker, {?map_msg_dlg_req, ?mapdt_open_req, list_to_binary(Payload)}),
                          gen_server:cast(?enode_broker, {self(),
                          ?map_msg_srv_req, ?mapst_mo_fwd_sm_req,
                          ODlgId, list_to_binary(Payload_mofsm)})
                  end,Payload2).
    %%gen_server:cast(?enode_broker, {self(), ?map_msg_srv_req, ?mapst_mo_fwd_sm_req, list_to_binary(Payload2)}).

mo_forward_sm_req_concatenated(Sm_Rp_Oa, Tp_Da, Key)->
    io:format("================ trying to send concatenated sms to smsc ~n"),
    Payload = create_map_open_req_payload2(),
    %%gen_server:cast(?enode_broker, {self(), ?map_msg_dlg_req, ?mapdt_open_req, list_to_binary(Payload)}),

    put(smrpoa, Sm_Rp_Oa),
    put(tpda, Tp_Da),
    
    io:format("in mo_forward_sm_req function after cast ~n"),
    io:format("sm rp oa ~p and tp da ~p in mo forward sm req ~n", [Sm_Rp_Oa, Tp_Da]),
    Payload2 = mo_forwardSM2(Sm_Rp_Oa, Tp_Da, Key),

    lists:foreach(fun(Payload_mofsm)->
                          ODlgId = gen_server:call(?enode_broker, {?map_msg_dlg_req, ?mapdt_open_req, list_to_binary(Payload)}),
                          gen_server:cast(?enode_broker, {self(),
                          ?map_msg_srv_req, ?mapst_mo_fwd_sm_req,
                          ODlgId, list_to_binary(Payload_mofsm)}),
                          submission:submit_sent()
                  end,Payload2).
    


%% parse binary data received from C node
%% this is for received mapdt_dlg_ind received from C node
parse_data([])->
    ok;
parse_data([?mapdt_open_ind | T])->
    parse_data(T);
parse_data([?sccp_called | T]) ->
    io:format("sccp called ~n"),
    Rest = parse_sccp(sccp_called, T),
    parse_data(Rest);
parse_data([?sccp_calling | T]) ->
    io:format("sccp calling ~n"),
    Rest = parse_sccp(sccp_calling, T),
    parse_data(Rest);
parse_data([?ac_name | T]) ->
    parse_ac(T).

parse_sccp(CallingOrCalled, Data = [H | T]) ->
    SccpAddr = lists:sublist(Data, 1, H + 1),
    put(CallingOrCalled, SccpAddr),
    io:format("sccp addr = ~p~n", [SccpAddr]),
    %%io:format("T = ~p~n", [T]),
    Rest = Data -- SccpAddr,
    %%io:format("rest = ~p~n", [Rest]),
    Rest.

parse_ac(Data = [H|T])->
    AcData = lists:sublist(Data, 1, H+1),
    put(ac_version_list, AcData),
    put(ac_version_atom, ac_text(AcData)),
    io:format("ac version list  = ~p~n", [get(ac_version_list)]).

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
ac_text([9,6,7,4,0,0,1,0,25,3])-> shortMsgMTRelayContext_v3; %%MT FSM from SMSC to MSC/VLR/SMSROUTER
ac_text([9,6,7,4,0,0,1,0,20,2])-> shortMsgGatewayContext_v2; %%SRI SM from SMSC to HLR
ac_text([9,6,7,4,0,0,1,0,21,1])-> shortMsgRelayContext_v1;
ac_text([9,6,7,4,0,0,1,0,21,3])-> shortMsgMORelayContext_v3; %%smsr use this when send MO SM to SMSC TMT
ac_text([9,6,7,4,0,0,1,0,25,2])-> shortMsgMTRelayContext_v2; %%forwardSM(46) from Tele2 SMSC   
ac_text([9,6,7,4,0,0,1,0,20,3])-> shortMsgGatewayContext_v3; %%used by bee in ping SRI SM to smsr
ac_text([9,6,7,4,0,0,1,0,20,1])-> shortMsgGatewayContext_v1. %% when send sms from Megafon NN    
   

%% pptr[0] = MAPDT_OPEN_RSP;
%%    pptr[1] = MAPPN_result;
%%    pptr[2] = 0x01;
%%    pptr[3] = result;
 %%   pptr[4] = MAPPN_applic_context;
%%    pptr[5] = (u8)dlg_info->ac_len;
%%    memcpy((void*)(pptr+6), (void*)dlg_info->app_context, dlg_info->ac_len);
%%    pptr[6+dlg_info->ac_len] = 0x00;


create_map_open_rsp_payload()->
    create_map_open_rsp_payload([?mapdt_open_rsp], mappn_result).
create_map_open_rsp_payload(List, mappn_result) ->
    Result = [?mappn_result, 1, 0],
    List2 = List ++ Result,
    create_map_open_rsp_payload(List2, mappn_applic_context);
create_map_open_rsp_payload(List, mappn_applic_context) ->
    ACname = [?mappn_applic_context] ++ get(ac_version_list),
    List2 = List ++ ACname,
    create_map_open_rsp_payload(List2, terminator);
create_map_open_rsp_payload(List, terminator) ->
    List ++ [0].


create_map_open_rsp_payload_refuse()->
    create_map_open_rsp_payload_refuse([?mapdt_open_rsp], mappn_result).
create_map_open_rsp_payload_refuse(List, mappn_result) ->
    Result = [?mappn_result, 1, ?dlg_refused],
    List2 = List ++ Result,
    create_map_open_rsp_payload_refuse(List2, mappn_applic_context);
create_map_open_rsp_payload_refuse(List, mappn_applic_context) ->
    ACname = [?mappn_applic_context] ++ get(ac_version_list),
    List2 = List ++ ACname,
    create_map_open_rsp_payload_refuse(List2, terminator);
create_map_open_rsp_payload_refuse(List, terminator) ->
    List ++ [0].


%% create payload for MAP_OPEN_REQ
%% we should construct DLG_REQ message with MAPDT_OPEN_REQ
%%* mapMsg_dlg_req tc7e2 i0001 f2e d15 s00 p010b09060704000001001403 010b1206001104970566152000030b120800110497056615200900 map open req

%% 01 - mapdt_open_req
%% 0b 09 060704000001001403 ac context
%% 010b 1206001104970566152000 destination address
%% 030b 1208001104970566152009 originating address
%% 00                         terminator
%% this part is for sending SRI_SM request to HLR
%% first we need to send OPEN_DLG command to MAP
create_map_open_req_payload()->
    create_map_open_req_payload([?mapdt_open_req], mappn_applic_context).
create_map_open_req_payload(List, mappn_applic_context) ->
    List2 = List ++ [?mappn_applic_context] ++ get(ac_version_list),
    create_map_open_req_payload(List2, sccp_called);
create_map_open_req_payload(List, sccp_called) ->
    List2 = List ++ [?mappn_dest_address] ++ ?dummy_dest, 
    create_map_open_req_payload(List2, sccp_calling);
create_map_open_req_payload(List, sccp_calling) ->
    List2 = List ++ [?mappn_orig_address] ++ ?smsr_sccp_gt,
    List2 ++ [0].


%% this part is for sending MO_FORWARD_SM request to HLR
%% first we need to send OPEN_DLG command to MAP
%% TODO - construct one fucntion from two, remove magics
%% and other

create_map_open_req_payload2()->
    create_map_open_req_payload2([?mapdt_open_req], mappn_applic_context).
create_map_open_req_payload2(List, mappn_applic_context) ->
    List2 = List ++ [?mappn_applic_context] ++ [9, 6, 7, 4, 0, 0, 1, 0, 16#15, 3],
    create_map_open_req_payload2(List2, sccp_called);
create_map_open_req_payload2(List, sccp_called) ->
    List2 = List ++ [?mappn_dest_address] ++ ?smsc_sccp_gt, 
    create_map_open_req_payload2(List2, sccp_calling);
create_map_open_req_payload2(List, sccp_calling) ->
    List2 = List ++ [?mappn_orig_address] ++ ?smsr_sccp_gt,
    List2 ++ [0].

%% function to construct submit sm payload
%% invoke id + sm rp da + sm rp oa + sm rp ui
%% input arg msisdn is list with 0x91 at head
mo_forwardSM(Msisdn, Tp_Da)->
    InvokeId = [?mappn_invoke_id, 1, 1],
    Sm_rp_da = [16#17, 16#09, 16#04, 16#07, 16#91, 16#97, 16#05, 16#66, 16#15, 16#10, 16#f0],
    Sm_rp_oa = [16#18, 16#09, 16#02, 16#07] ++ Msisdn,
    Sm_rp_uiB = list_to_binary(get(sm_rp_ui)),
    Sms_deliver = sm_rp_ui:parse(Sm_rp_uiB),
    Sm_rp_ui = sm_rp_ui:create_sms_submit(Sms_deliver, Tp_Da),

    case is_list(Sm_rp_ui) of
        true ->
            io:format("WARNING: should send concatenated sms!~n"),
            lists:map(fun(A)->
                              [?mapst_mo_fwd_sm_req] ++ InvokeId ++ Sm_rp_da ++ Sm_rp_oa ++ [?mappn_sm_rp_ui, byte_size(A)] ++
                                  binary_to_list(A) ++ [?mappn_dialog_type, 1, ?mapdt_delimiter_req, 0]
                      end,Sm_rp_ui);
        false ->
            Sm_rp_ui_length = byte_size(Sm_rp_ui),
           [ [?mapst_mo_fwd_sm_req] ++ InvokeId ++ Sm_rp_da ++ Sm_rp_oa ++ [?mappn_sm_rp_ui, Sm_rp_ui_length] ++
                binary_to_list(Sm_rp_ui) ++
                [?mappn_dialog_type, 1, ?mapdt_delimiter_req, 0] ]
    end.




%% function to construct submit sm payload
%% invoke id + sm rp da + sm rp oa + sm rp ui
%% input arg msisdn is list with 0x91 at head
mo_forwardSM2(Msisdn, Tp_Da, Key)->
    InvokeId = [?mappn_invoke_id, 1, 1],
    Sm_rp_da = [16#17, 16#09, 16#04, 16#07, 16#91, 16#97, 16#05, 16#66, 16#15, 16#10, 16#f0],
    Sm_rp_oa = [16#18, 16#09, 16#02, 16#07] ++ Msisdn,
    %%Sm_rp_uiB = list_to_binary(get(sm_rp_ui)),
    %%Sms_deliver = sm_rp_ui:parse(Sm_rp_uiB),
    Sm_rp_ui = mo_sms:create_sms_submits(Tp_Da, Key),

    case is_list(Sm_rp_ui) of
        true ->
            io:format("WARNING: should send concatenated sms!~n"),
            lists:map(fun(A)->
                              [?mapst_mo_fwd_sm_req] ++ InvokeId ++ Sm_rp_da ++ Sm_rp_oa ++ [?mappn_sm_rp_ui, byte_size(A)] ++
                                  binary_to_list(A) ++ [?mappn_dialog_type, 1, ?mapdt_delimiter_req, 0]
                      end,Sm_rp_ui);
        false ->
            Sm_rp_ui_length = byte_size(Sm_rp_ui),
           [ [?mapst_mo_fwd_sm_req] ++ InvokeId ++ Sm_rp_da ++ Sm_rp_oa ++ [?mappn_sm_rp_ui, Sm_rp_ui_length] ++
                binary_to_list(Sm_rp_ui) ++
                [?mappn_dialog_type, 1, ?mapdt_delimiter_req, 0] ]
    end.

%% parsing received srv_ind data from C node
%%parse_srv_data([?mapst_snd_rtism_ind | T]) ->
%%    parse_srv_data(T);
%%parse_srv_data([?mappn_invoke_id | [Length | T]]) ->
%%    InvokeId = lists:sublist(T, 1, Length ),
%%    put(invoke_id, InvokeId),
%%    Out = lists:nthtail(Length, T),
%%    parse_srv_data(Out);
%%parse_srv_data([?mappn_msisdn | [Length | T]]) ->
%%    Msisdn = lists:sublist(T, 1, Length ),
%%    put(msisdn, Msisdn),
%%    Out = lists:nthtail(Length, T),
%%    parse_srv_data(Out);
%%parse_srv_data([?mappn_sm_rp_pri | [Length | T]]) ->
%%    Smrppri = lists:sublist(T, 1, Length ),
%%    put(sm_rp_pri, Smrppri),
%%    Out = lists:nthtail(Length, T),
%%    parse_srv_data(Out);
%%parse_srv_data([?mappn_sc_addr | [Length | T]]) ->
%%    Smscaddr = lists:sublist(T, 1, Length ),
%%    put(sc_addr, Smscaddr),
%%    Out = lists:nthtail(Length, T),
%%    parse_srv_data(Out);
%%parse_srv_data([0])->
%%    ok.

-spec map_srv_req_primitive( atom(),[binary()] ) -> binary().
map_srv_req_primitive(snd_rtism_req, Components)->
    [Component] = Components,
    %%should remove last 0 from binary
    %%New = binary_part(Component, {0, byte_size(Component)-1}),
    %%Out = <<New/binary, ?mappn_dialog_type, 1, ?mapdt_delimiter_req,0>>,
    %%io:format("Out = ~p~n", [Out]),
    %%Out.
    <<_First:8, Rest/binary>> = Component,
    Out = << ?mapst_snd_rtism_req, Rest/binary, ?mappn_dialog_type, 1 , ?mapdt_delimiter_req, 0>>,
    Out.


get_cid()->
    gen_server:call(?enode_broker, get_cid).
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------

    
