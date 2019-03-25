-module(component).

-export([handle_service_data/1]).
%%%
%%% Module for analyzing service component received in SRV_IND message
%%%
%%% Actually, firstly we receive component and then after DELIMITER or DLG_CLOSE received
%%% dynamic worker should analyze component data and make some decisions.
%%%
%%% Decisions could be:
%%%
%%% -- If map_sri_for_sm received then dynamic worker should send map_sri_sm to HLR
%%% -- If map_sri_sm_ack received then dynamic worker should send map_sri_sm_ack to SMSC
%%% -- If map_mt_forward_sm reeived then dynamic worker should send map_mt_forward_sm_ack to SMSC



-include("gctload.hrl").
%%%---------------------------------------------------------------------------
%%% analyze payload of service component
%%% Components - list of components where each element is binary with 
%%% component payload
%%%---------------------------------------------------------------------------

handle_service_data(Components)->
%% TODO !
    [Component | _Tail] = Components,
    [ServiceType | Parameters] = binary:bin_to_list(Component),
    parse_service_data(Parameters),
    put(service_type, ServiceType), %% when PD not defined then this will return undefined
    io:format("service type in worker = ~p~n", [ServiceType]),
    ServiceType.

%% parsing received srv_ind parameters(except service type) from C node
%%parse_service_data([?mapst_snd_rtism_ind | T]) ->
%%    put(service_type, ?mapst_snd_rtism_ind),
%%    parse_service_data(T);

parse_service_data([?mappn_invoke_id | [Length | T]]) ->
    InvokeId = lists:sublist(T, 1, Length ),
    put(invoke_id, InvokeId),
    Out = lists:nthtail(Length, T),
    parse_service_data(Out);
parse_service_data([?mappn_msisdn | [Length | T]]) ->
    Msisdn = lists:sublist(T, 1, Length ),
    io:format("Msisdn in parse service data = ~p~n", [Msisdn]),
    [{_, Tp_da}] = ets:lookup(subscribers, list_to_binary(Msisdn)),
    Sm_rp_oa = << Length, (list_to_binary(Msisdn))/binary >>,
    put(sm_rp_oa, Sm_rp_oa),
    put(msisdn, Msisdn),
    put(tp_da, Tp_da),
    Out = lists:nthtail(Length, T),
    parse_service_data(Out);
parse_service_data([?mappn_sm_rp_pri | [Length | T]]) ->
    Smrppri = lists:sublist(T, 1, Length ),
    put(sm_rp_pri, Smrppri),
    Out = lists:nthtail(Length, T),
    parse_service_data(Out);
parse_service_data([?mappn_imsi | [Length | T]]) ->
    Imsi = lists:sublist(T, 1, Length ),
    put(imsi, Imsi),
    Out = lists:nthtail(Length, T),
    parse_service_data(Out);
parse_service_data([?mappn_msc_num | [Length | T]]) ->
    Msc = lists:sublist(T, 1, Length ),
    put(msc, Msc),
    Out = lists:nthtail(Length, T),
    parse_service_data(Out);
parse_service_data([?mappn_sc_addr | [Length | T]]) ->
    Smscaddr = lists:sublist(T, 1, Length ),
    put(sc_addr, Smscaddr),
    Out = lists:nthtail(Length, T),
    parse_service_data(Out);
parse_service_data([?mappn_sm_rp_ui | [Length | T]]) ->
    Sm_rp_ui = lists:sublist(T, 1, Length ),
    put(sm_rp_ui, Sm_rp_ui),
    Out = lists:nthtail(Length, T),
    parse_service_data(Out);
parse_service_data([?mappn_sm_rp_da | [Length | T]]) ->
    Sm_rp_da = lists:sublist(T, 1, Length ),
    put(sm_rp_da, Sm_rp_da),
    Out = lists:nthtail(Length, T),
    parse_service_data(Out);
parse_service_data([?mappn_user_err | [Length | T]]) ->
    User_err = lists:sublist(T, 1, Length ),
    put(user_err, User_err),
    Out = lists:nthtail(Length, T),
    parse_service_data(Out);
parse_service_data([?mappn_sm_rp_oa | [Length | T]]) ->
    Sm_rp_oa = lists:sublist(T, 1, Length ),
    put(sm_rp_oa, Sm_rp_oa),
    Out = lists:nthtail(Length, T),
    parse_service_data(Out);
parse_service_data([?mappn_more_msgs | [_Length | T]]) ->
    More_msg = 1,
    put(more_msg, More_msg),
    %%Out = lists:nthtail(Length, T),
    parse_service_data(T);
parse_service_data([?mappn_gprs_support_ind | [_Length | T]]) ->
    put(gprs_support_ind, 1),
    %%Out = lists:nthtail(Length, T),
    parse_service_data(T);

parse_service_data([0])->
    get(service_type).
