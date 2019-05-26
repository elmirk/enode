-module(hlr_agent).

-author('elmir.karimullin@gmail.com').

-include("gctload.hrl").
-include("enode_broker.hrl").


-export([invoke_reportSM_DeliveryStatus/1]).

-define(shortMsgGatewayContext_v3, [9,6,7,4,0,0,1,0,20,3]). 
%%ac_text([9,6,7,4,0,0,1,0,20,3])-> shortMsgGatewayContext_v3; %%used by bee in ping SRI SM to smsr

-define(sccp_called, 1).
-define(sccp_calling, 3).
-define(ac_name, 11).
-define(dummy_dest, [16#0b, 16#12, 16#06, 0, 16#11, 16#04, 16#97, 16#05, 16#66, 16#15, 16#20, 16#0]).
-define(smsr_sccp_gt, [16#0b, 16#12, 16#08, 0, 16#11, 16#04, 16#97, 16#05, 16#66, 16#15, 16#20, 16#09]).
-define(smsc_sccp_gt, [16#0b, 16#12, 16#08, 0, 16#11, 16#04, 16#97, 16#05, 16#66, 16#15, 16#10, 0]).


%%Components is binary
invoke_reportSM_DeliveryStatus(Components)->
    
%% p010b09060704000001001403010b1206001104970566152000030b120800110497056615200900
%% also we should choos dlg id for outgoing dlgs
    DlgPayload = create_map_open_dlg_req_payload(),
    %%gen_server:cast(?enode_broker, {self(), ?map_msg_dlg_req, ?mapdt_open_req, list_to_binary(DlgPayload)}),
    ODlgId = gen_server:call(?enode_broker, {?map_msg_dlg_req, ?mapdt_open_req, list_to_binary(DlgPayload)}),
%% payload here

    SrvPayload = create_map_srv_req_primitive(mapst_rpt_smdst_req, Components),
    gen_server:cast(?enode_broker, {self(), ?map_msg_srv_req, ?mapst_rpt_smdst_req, ODlgId, SrvPayload}).


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
create_map_open_dlg_req_payload()->
    create_map_open_dlg_req_payload([?mapdt_open_req], mappn_applic_context).
create_map_open_dlg_req_payload(List, mappn_applic_context) ->
    List2 = List ++ [?mappn_applic_context] ++ ?shortMsgGatewayContext_v3,
    create_map_open_dlg_req_payload(List2, sccp_called);
create_map_open_dlg_req_payload(List, sccp_called) ->
    List2 = List ++ [?mappn_dest_address] ++ ?dummy_dest, 
    create_map_open_dlg_req_payload(List2, sccp_calling);
create_map_open_dlg_req_payload(List, sccp_calling) ->
    List2 = List ++ [?mappn_orig_address] ++ ?smsr_sccp_gt,
    List2 ++ [0].



-spec create_map_srv_req_primitive( atom(), binary() ) -> binary().
create_map_srv_req_primitive(mapst_rpt_smdst_req, Components)->
    %%[Component] = Components,
    %%should remove last 0 from binary
    %%New = binary_part(Component, {0, byte_size(Component)-1}),
    %%Out = <<New/binary, ?mappn_dialog_type, 1, ?mapdt_delimiter_req,0>>,
    %%io:format("Out = ~p~n", [Out]),
    %%Out.
    <<_First:8, Rest/binary>> = Components,
    %%should remove terminating zero byte from binary
    Rest2 = binary_part(Rest, {0, byte_size(Rest)-1}),
    Out = << ?mapst_rpt_smdst_req, Rest2/binary, ?mappn_dialog_type, 1 , ?mapdt_delimiter_req, 0>>,
    Out.
