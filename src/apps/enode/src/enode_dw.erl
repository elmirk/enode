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

%% API
-export([start_link/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, format_status/2]).

-define(SERVER, ?MODULE).

%% definest should be checked before production!!
%% !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1
-define(mapdt_open_ind, 2).
%%-define(mapdt_open_rsp, 16#81).
%%-define(mapdt_open_req, 16#01).
%%-define(mappn_result, 9).

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
                               %%or MT_FWD_SM spawn the worker
                tarantool,     %%connection to TT
                components,
                sccp_calling,
                sccp_called,
                ac_name}).
%%-record(dialog, {dlg_id,
%%                 tarantool,
%%		 components = [],
%%		 sccp_calling,
%%		 sccp_called,
%%		 ac_name}).

-record(sccp, {sccp_calling, sccp_called, ac_name}).

%%-include("dyn_defs.hrl").
-include("gctload.hrl").
%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link(term()) -> {ok, Pid :: pid()} |
		      {error, Error :: {already_started, pid()}} |
		      {error, Error :: term()} |
		      ignore.
start_link(DlgId) ->
%% we should start dynamic worker without registered name
    gen_server:start_link(?MODULE, DlgId, []).
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
init(DlgId)->
    %%process_flag(trap_exit, true),
%%    {ok, TTconn} = taran:connect(),
    State = case taran:connect() of
                {ok, TTconn} -> #state{dlg_id = DlgId, tarantool = TTconn};
                _Other -> #state{dlg_id = DlgId, tarantool = fail}
            end,
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
handle_cast({dlg_ind_open, Request}, State) ->
    io:format("[~p]receive dlg ind open smsr worker ~p~n",[self(),Request]),
    %%io:format("i have state already ~p~n", [State]),
    parse_data(binary:bin_to_list(Request)),
    io:format("sccp_calling from PD = ~p~n",[get(sccp_calling)]),
    io:format("sccp_called from PD = ~p~n",[get(sccp_called)]),
    io:format("ac name = ~p~n", [get(ac_name)]),

%% suppose we analyxe dlg_ind_open messages and SMSR allow to establish dialogue
%% Now let's send DLG_OPEN_RSP bask to C node!

%% {mapdt_open_rsp, DlgId, BinaryData}
%% should construct payload like this
%%  p810501000b0906070400000100140300
%% send open_resp after delimit ind received!!
%%    Payload = create_map_open_rsp_payload(),
%%    DlgId = State#dialog.dlg_id,
%%    gen_server:cast(broker, {order, ?map_msg_dlg_req, ?mapdt_open_rsp, DlgId, list_to_binary(Payload)}),

    {noreply, State};

handle_cast({mapdt_open_cnf, Request}, State) ->

 %%   case get(flag) of
%%	undefined ->
%%	    do_nothing;
%%	1 ->   
%%	    io:format("in mo_forward_sm_req function after cast ~n"),
	   %% io:format("sm rp oa ~p and tp da ~p in mo forward sm req ~n", [Sm_Rp_Oa, Tp_Da]),
%%	    Payload2 = mo_forwardSM(get(smrpoa),get(tpda)),
%%	    gen_server:cast(broker, {self(), ?map_msg_srv_req, ?mapst_mo_fwd_sm_req, list_to_binary(Payload2)})
  %%  end,
        {noreply, State};

handle_cast({srv_ind, Request}, State) ->
    io:format("srv_ind received ~n"),
    Components = State#state.components,
    NewState = State#state{components = [ Request | Components ]},
%%    ok = parse_srv_data(binary:bin_to_list(Request)),
%%   io:format("invoke_id from PD = ~p~n",[get(invoke_id)]),
%%    io:format("msisdn from PD = ~p~n",[get(msisdn)]),
%%    io:format("sm rp pri name = ~p~n", [get(sm_rp_pri)]),
%%    io:format("sc addr = ~p~n", [get(sc_addr)]),
    {noreply, NewState};
%%--------------------------------------------------------------------
%% Process received delimit_ind
%%--------------------------------------------------------------------
handle_cast({delimit_ind, Request}, State) ->
    io:format("receive delimit ind in dyn worker ~n"),
%% TODO - we receive delimit and we should analyze what kind of component we recevied bevoe in SRV_IND
%% component should be saved in State like component list
%% Payload here should be like
    Payload = create_map_open_rsp_payload(),
    DlgId = State#state.dlg_id,
    gen_server:cast(broker, {order, ?map_msg_dlg_req, ?mapdt_open_rsp, DlgId, list_to_binary(Payload)}),

    case component:handle_service_data(State#state.components) of
	?mapst_snd_rtism_ind ->
	    io:format("stay before send sri sm req ~n"),
	    Cid = get_cid(),
	    Msisdn = get(msisdn),
	    [{_, Tp_da}] = ets:lookup(subscribers, list_to_binary(Msisdn)),
	    ets:insert(cid, {bcd:encode(imsi, Cid), Msisdn, binary_to_list(Tp_da)}),
	    %% update_sid(),
	    %% CorrealatioId = fake IMSI
	    %%CorrelationId = 250270900000000 + Sid,
	    put(cid, Cid),
%%	    sri_sm_req(State#dialog.components);
	    send_sri_sm_ack(State#state.components, State#state.dlg_id);
	?mapst_mt_fwd_sm_ind ->
	    io:format("stay before send mt forward sm ack ~n"),
	    mt_forward_sm_ack(State#state.dlg_id),
	    Sm_rp_da = get(sm_rp_da),
	    [_Type | [Length | Imsi  ]] = Sm_rp_da,
	    %%ImsiL = bcd:decode(imsi, list_to_binary(Imsi)),
	    [{_Cid, Sm_rp_oa, Tp_da}] = ets:lookup(cid, list_to_binary(Imsi)),
	    mo_forward_sm_req(Sm_rp_oa, Tp_da),
	io:format("stay after mo forward sm~n");
	?mapst_fwd_sm_ind -> %%smsc use mapv2 forward_sm instead of mt forward sm
	    forward_sm_ack(State#state.dlg_id),
	    Sm_rp_da = get(sm_rp_da),
	    [_Type | [Length | Imsi  ]] = Sm_rp_da,
	    %%ImsiL = bcd:decode(imsi, list_to_binary(Imsi)),
	    [{_Cid, Sm_rp_oa, Tp_da}] = ets:lookup(cid, list_to_binary(Imsi)),
	    mo_forward_sm_req(Sm_rp_oa, Tp_da),
	    io:format("stay after mo forward sm~n");
	_Other->
	    io:format("suddenly true ~n"),
	    true
    end,
%% p010b09060704000001001403010b1206001104970566152000030b120800110497056615200900
%% also we should choos dlg id for outgoing dlgs

%%    Payload = create_map_open_req_payload(),
%%    gen_server:cast(broker, {order, ?map_msg_dlg_req, ?mapdt_open_req, 64700, list_to_binary(Payload)}),
%% payload here
%% 
%%    Payload2 = map_srv_req_primitive(snd_rtism_req),
%%    gen_server:cast(broker, {order, ?map_msg_srv_req, ?mapst_snd_rtism_req, 64700, list_to_binary(Payload2)}),

    {noreply, State};
handle_cast({mapdt_close_ind, Request}, State) ->

    case component:handle_service_data(State#state.components) of
	?mapst_snd_rtism_cnf -> send_sri_sm_ack(State#state.components, State#state.dlg_id);
	?mapst_mo_fwd_sm_cnf -> mo_fwd_sm_cnf();
	_Other->
	    io:format("!!!!!!!!!!!!!!!!!!!!!!!!!1unexpected error ~n"),
	    true
    end,

{stop, normal, State}.
%%    {noreply, State}.



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

sri_sm_req(Components)->
    io:format("in sri sm req function ~n"),
%% p010b09060704000001001403010b1206001104970566152000030b120800110497056615200900
%% also we should choos dlg id for outgoing dlgs
    Payload = create_map_open_req_payload(),
    gen_server:cast(broker, {self(), ?map_msg_dlg_req, ?mapdt_open_req, list_to_binary(Payload)}),
%% payload here

io:format("in srim sm req function after cast ~n"),
 
    Payload2 = map_srv_req_primitive(snd_rtism_req, Components),
    gen_server:cast(broker, {self(), ?map_msg_srv_req, ?mapst_snd_rtism_req, Payload2}).

%%%-----------------------------------------------------------------------------
%% @doc
%% send MAP_SRI_SM_ACK to SMSC
%% should construct parameters for MAP_SRI_SM_ACK as in example
%% p81 0e01b5 120852200701304377f7 1307919705661520f900
%% also in this function we should change trueIMSI to Correlationid
%% @spec
%% @end
%%--------------------------------------------------------------------
send_sri_sm_ack(Components, DlgId)->
%%    Payload = map_msg_srv_req(),
    Cid = get(cid),
    Fimsi= bcd:encode(imsi, Cid),
    Payload = construct_sri_sm_ack(Fimsi),
%%    Payload x= [16#81,  16#0e, 16#01, 16#b5,   16#12, 16#08, 16#52, 16#20,
%%	       16#07, 16#01, 16#30, 16#43, 16#77, 16#f7,  16#13, 16#07,
%%	       16#91, 16#97, 16#05, 16#66, 16#15, 16#20, 16#f9, 16#00],
    gen_server:cast(broker, {self(), ?map_msg_srv_req, ?mapst_snd_rtism_rsp, DlgId, list_to_binary(Payload)}).


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


%%% function to send MT_FORWARD_SM_ACK to SMSC
%%%
%%% 
mt_forward_sm_ack(DlgId)->
%%    Payload = map_msg_srv_req(),
%%    CorrelationId = get(correlationid),
%%    Fimsi= bcd:encode(imsi, CorrelationId),
%%    Payload = construct_sri_sm_ack(Fimsi),
    Invoke = get(invoke_id),
    InvokeId = [?mappn_invoke_id, 1] ++ Invoke,

    Payload = [?mapst_mt_fwd_sm_rsp] ++ InvokeId ++
	[?mappn_sm_rp_ui, 16#02, 16#0, 16#0,
	 ?mappn_dialog_type, 1, ?mapdt_close_req, ?mappn_release_method, 1, 0, 16#00],
    gen_server:cast(broker, {self(), ?map_msg_srv_req, ?mapst_mt_fwd_sm_rsp, DlgId, list_to_binary(Payload)}).


forward_sm_ack(DlgId)->
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
    gen_server:cast(broker, {self(), ?map_msg_srv_req, ?mapst_fwd_sm_rsp, DlgId, list_to_binary(Payload)}).



%%% function to send MO FORWARD SM to SMSC
%%%
%%% smsrouter act as MSC sending MO FORWARD SM to SMS

mo_forward_sm_req(Sm_Rp_Oa, Tp_Da)->
    io:format("in mo_forward_sm_req function ~n"),
    Payload = create_map_open_req_payload2(),
    gen_server:cast(broker, {self(), ?map_msg_dlg_req, ?mapdt_open_req, list_to_binary(Payload)}),
%% payload here

    put(smrpoa, Sm_Rp_Oa),
    put(tpda, Tp_Da),
    %%put(flag,1),
    
    io:format("in mo_forward_sm_req function after cast ~n"),
    io:format("sm rp oa ~p and tp da ~p in mo forward sm req ~n", [Sm_Rp_Oa, Tp_Da]),
    Payload2 = mo_forwardSM(Sm_Rp_Oa, Tp_Da),
    gen_server:cast(broker, {self(), ?map_msg_srv_req, ?mapst_mo_fwd_sm_req, list_to_binary(Payload2)}).

mo_fwd_sm_cnf()->
    io:format("mo forward sm returned result!~n"),
    io:format("user err = ~p~n", [get(user_err)]).

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
    put(ac_name, AcData),
    io:format("ac data = ~p~n", [AcData]).
    

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
    ACname = [?mappn_applic_context] ++ get(ac_name),
    List2 = List ++ ACname,
    create_map_open_rsp_payload(List2, terminator);
create_map_open_rsp_payload(List, terminator) ->
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
    List2 = List ++ [?mappn_applic_context] ++ get(ac_name),
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
    Sm_rp_ui_length = byte_size(Sm_rp_ui),
    [?mapst_mo_fwd_sm_req] ++ InvokeId ++ Sm_rp_da ++ Sm_rp_oa ++ [?mappn_sm_rp_ui, Sm_rp_ui_length] ++
	binary_to_list(Sm_rp_ui) ++
	[?mappn_dialog_type, 1, ?mapdt_delimiter_req, 0].

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
    gen_server:call(broker, get_cid).
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------

    
