%%% message types to convey primitive data
-define(map_msg_srv_req, 16#c7e0).
-define(map_msg_srv_ind, 16#87e1).
-define(map_msg_dlg_req, 16#c7e2).
-define(map_msg_dlg_ind, 16#87e3).


%% dialogue primitive types

-define(mapdt_open_req, 1).
-define(mapdt_open_ind, 2).
-define(mapdt_close_req, 3).
-define(mapdt_close_ind, 4).
-define(mapdt_delimiter_req, 5).
-define(mapdt_delimiter_ind, 6).
-define(mapdt_u_abort_req, 7).
-define(mapdt_u_abort_ind, 8).
-define(mapdt_p_abort_ind, 9).
-define(mapdt_notice_ind, 10).
-define(mapdt_open_rsp, 129). %%0x81
-define(mapdt_open_cnf, 16#82).

%% service primitive types
-define(empty_service_portion, 16#00). %%if incoming components list
%%=[], suppos TCAP handshake procedure (Beeline traces)
-define(mapst_snd_rtism_req, 16#01).
-define(mapst_snd_rtism_ind, 16#02).
-define(mapst_mo_fwd_sm_req, 16#03). %%version 3 onwards
-define(mapst_snd_rtism_cnf, 16#82). %% sri_sm_ack received from HLR
-define(mapst_snd_rtism_rsp, 16#81). %% send it to send sri_sm_ack to SMSC
-define(mapst_mt_fwd_sm_ind, 16#46). %% map3 onwards
-define(mapst_mt_fwd_sm_rsp, 16#bf). %%MAP_MT_FORWARD_SM_ACK to SMSC
-define(mapst_fwd_sm_req, 16#03). %%MAP-FORWARD-SHORT-MESSAGE-REQ (versions 1 and 2)
-define(mapst_fwd_sm_rsp, 16#83). %%MAP-FORWARD-SHORT-MESSAGE-RSP (versions 1 and 2)
-define(mapst_fwd_sm_cnf, 16#84). %%MAP-FORWARD-SHORT-MESSAGE-CNF (versions 1 and 2)
-define(mapst_mo_fwd_sm_cnf, 16#84). %%MAP-MO-FORWARD-SHORT-MESSAGE-CNF (version 3 onwards)
-define(mapst_fwd_sm_ind, 16#04). %%MAP-FORWARD-SHORT-MESSAGE-IND (versions 1 and 2)
-define(mapst_rpt_smdst_req, 16#05). %%MAP-REPORT-SM-DELIVERY-STATUS-REQ
-define(mapst_rpt_smdst_ind, 16#06). %%MAP-REPORT-SM-DELIVERY-STATUS-IND
-define(mapst_rpt_smdst_rsp, 16#85). %%MAP-REPORT-SM-DELIVERY-STATUS-RSP
-define(mapst_rpt_smdst_cnf, 16#86). %%MAP-REPORT-SM-DELIVERY-STATUS-CNF

%% MAP Dialogue Primitive Parameters

-define(mappn_dest_address, 1). %%Destination address
-define(mappn_orig_address, 3). %%Originating address
-define(mappn_applic_context, 11). %%Application context name 
-define(mappn_result, 5). %% Result
-define(mappn_dialog_type, 16#f9). %%look at MAP user guide
-define(mappn_release_method, 16#07).


%% MAP Service Primitive Parameters

-define(mappn_invoke_id, 14).
-define(mappn_msisdn, 15). %%MSISDN
-define(mappn_sm_rp_pri, 16). %%Short Message Delivery Priority
-define(mappn_sc_addr, 17). %%Short Message Service Centre Address
-define(mappn_imsi, 18).
-define(mappn_msc_num, 16#13).
-define(mappn_sm_rp_ui, 16#19).
-define(mappn_sm_rp_da, 16#17). %%Short Message Destination Address
-define(mappn_sm_rp_oa, 16#18). %%Short Message Originating Address
-define(mappn_more_msgs, 16#1a). %%More messages to send, special coding 1a00 - means true, look dialogic MAP manual.
-define(mappn_user_err, 16#15).
-define(mappn_gprs_support_ind, 16#76).
-define(mappn_sm_rp_mti, 16#77). 
-define(mappn_sm_rp_smea, 16#78).
-define(mappn_sm_deliv_outcome, 16#1b). %%SM delivery outcome
-define(mappn_deliv_fail_cse, 16#1f). %%SM delivery failure cause


%%%
%% mappn_result values
-define(dlg_accept, 0).
-define(dlg_refused, 1).


%%sm_rp_da types - first octet of sm_rp_da
-define(sm_rp_da_imsi, 0).
-define(sm_rp_da_lmsi, 1).
-define(sm_rp_da_roaming_number, 3).
-define(sm_rp_da_sca, 4). %% Service centre address
-define(no_sm_rp_da, 5).

%% First octet showing type of address encoded as specified
%% in ETS 300-599, i.e.
%% 0 – IMSI
%% 1 – LMSI
%% 3 – Roaming Number (MAP V1 only)
%% 4 – Service centre address
%% 5 – no SM-RP-DA (not MAP V1)
%% Second octet, indicating the number of octets that follow.
%% Subsequent octets containing the content octets of the
%% IMSI, LMSI, Roaming Number or address string encoded
%% as specified in ETS 300-599.

%%
%% First octet showing type of address encoded as specified
%% in ETS 300-599, i.e.
%% 2 – MSISDN
%% 4 – Service centre address
%% 5 – no SM-RP-OA (not MAP V1)
%% Second octet, indicating the number of octets that follow.
%% Subsequent octets containing the content octets of the
%% MSISDN or address string encoded as specified in ETS
%% 300-599.
