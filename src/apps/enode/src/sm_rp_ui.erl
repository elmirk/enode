%%% @author root <root@elmir-N56VZ>
%%% @copyright (C) 2018, root
%%% @doc
%%%
%%% @end
%%% Created : 16 Dec 2018 by root <root@elmir-N56VZ>
%%%

%%--------------------------------------------------------------------
%%% 
%%% SMS-SUBMIT
%%%
%%--------------------------------------------------------------------
%% first octet(from LSB)
%% TP-MTI TP-Message-Type-Indicator M 2b Parameter describing the message type,
%%                                                01 for SMS-SUBMIT
%% TP-RD TP-Reject-Duplicates M b Parameter indicating whether or not the
%%                          SC shall accept an SMS-SUBMIT for an
%%                          SM still held in the SC which has the sam
%%                          TP-MR and the same TP-DA as a
%%                           previously submitted SM from the same OA 1
%%TP-VPF TP-Validity-Period-Format M 2b Parameter indicating whether or not the
%%                        TP-VP field is present. (10 - present, relative format)
%%TP-SRR TP-Status-Report-Request O b Parameter indicating if the MS is
%%requesting a status report.  In real SM-Submit is 1 if status report requested by ME
%%TP-UDHI TP-User-Data-Header-Indicator O b Parameter indicating that the TP-UD field
%%contains a Header
%%TP-RP TP-Reply-Path M b Parameter indicating the request for Reply
%%Path.
%%then following octets:


%%TP-MR TP-Message-Reference M 1 octet Parameter identifying the SMS-SUBMIT.
%%TP-DA TP-Destination-Address M 2-12o Address of the destination SME.
%%TP-PID TP-Protocol-Identifier M o Parameter identifying the above layer
%%protocol, if any.
%%TP-DCS TP-Data-Coding-Scheme M I Parameter identifying the coding scheme
%%within the TP-User-Data. Usually 8 for UCS2 coding scheme
%%TP-VP TP-Validity-Period O o/7o Parameter identifying the time from where
%%the message is no longer valid. 0xff enough?
%%TP-UDL TP-User-Data-Length M I Parameter indicating the length of the
%%TP-User-Data field to follow.
%%
%%
%%--------------------------------------------------------------------
%%% 
%%% SMS-DELIVER
%%%
%%--------------------------------------------------------------------
%% 
%% example of coded data 
%% 24 0b919720171182f7 0008 81901200532321 080422043504410442

%%24hex = 0010 0100
%%TP-MTI TP-Message-Type-Indicator M 2b Parameter describing the message
%%type. 00 - SMS-DELIVER
%%TP-MMS TP-More-Messages-to-Send M b Parameter indicating whether or
%%not there are more messages to send, 1 - no more message in SMSC
%%TP-LP 1 bit, = 0

%%TP-SRI TP-Status-Report-Indication O b(bit5) Parameter indicating if the SME
%%has requested a status report.1 = status report shall returned to the SME
%%TP-UDHI TP-User-Data-Header-Indicator O b Parameter indicating that the
%%                                       TP-UD field contains a Header
%%=0, no header, SM only in UD
%%TP-RP TP-Reply-Path M b Parameter indicating that Reply
%%Path exists.Reply Path  = 0, is not set

%%0b919720171182f7 - Originating Address
%%TP-PID = 00
%%TP-DCS = 08
%%TP-SCTS TP-Service-Centre-Time-Stamp M 7o Parameter identifying time when
%%the SC received the message.
%%TP-UDL TP-User-Data-Length M I Parameter indicating the length of
%%the TP-User-Data field to follow.
%%TP-UD TP-User-Data O  Depend on the TP-DCS
 

-module(sm_rp_ui).

-export([get_oa/1,
	 test/0,
	 test2_0/0,
	 test2_1/0,
	 test3/0,
	 parse/1,
	 create_sms_submit/2]).

-record(sm_rp_ui, {
		   message_type,
		   mti,
		   mms,
		   rp,
		   lp,      %%loop prevention
		   udhi,
		   sri,
		   srr,
		   vpf,
		   rd,
		   oa_length, %%0x0b
		   oa_type, %%0x91
		   oa_data, %%9720171182f7
		   oa_raw,  %%0b919720171182f7
		   pid,
		   dcs,
		   scts,
		   udl,
		   ud}).

-define(sms_deliver, 0).
-define(sms_submit, 1).
-define(default_mr, 202).

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------

%% input - binary sm_rp_ui
%% output - sms_deliver record 
parse(Sm_rp_ui)->

    <<Flags:8, Rest/binary>> = Sm_rp_ui,
    
    %%[Rp, Udhi, Sri, Lp, Mms, Mti] = parse_flags(Flags),
    <<_Rest:6, Mti:2>> = <<Flags>>,
    case Mti of
	?sms_deliver ->
	    [Rp, Udhi, Sri, Lp, Mms] = parse_flags(sms_deliver, Flags),
	    %%[Rp, Udhi, Sri, Lp, Mms, Mti] = parse_flags(Flags),
	    Obj = parse_sms_deliver(Rest),
	    NewObj = Obj#sm_rp_ui{rp=Rp,
				  udhi = Udhi,
				  sri = Sri,
				  lp = Lp,
				  mms = Mms,
				  mti = Mti};
	?sms_submit ->
	    [Rp, Udhi, Srr, Vpf, Rd] = parse_flags(sms_submit, Flags),
	    Obj = parse_sms_submit(Rest),
	    NewObj = Obj#sm_rp_ui{rp=Rp,
				  udhi = Udhi,
				  srr = Srr,
				  vpf = Vpf,
				  rd = Rd,
				  mti = Mti};
	_Other -> 
	    NewObj = error
    end,

    io:format("sms deliver = ~w~n", [NewObj]),
    NewObj.


parse_sms_deliver(Data)->
    

    <<OAlength:8, OAtype:8, Rest/binary>> = Data,

    case OAtype of
	16#91 ->
	    {Oa_data, Tail} = decode_numeric_oa(OAlength, Rest);
	16#d0 -> %%alphanumeric oa field
	    {Oa_data, Tail} = decode_alphanum_oa(OAlength, Rest);
	Other -> 
	    {Oa_data,Tail} = decode_oa_carefully(Other, OAlength, Rest)
    end,

%%Slen = 56,
%% Scts - 7 octets
<< Pid:8, Dcs:8, Scts:7/binary, Udl:8, Ud/binary >>  = Tail,
%%<<Scts:7/binary, R2/binary >> = R,
%%<< Udl:8, Ud/binary >> = R2,

    #sm_rp_ui{message_type = sms_deliver,
		       oa_data = Oa_data,
		       oa_length = OAlength,
		       oa_type = OAtype,
		       pid = Pid,
		       dcs = Dcs,
		       scts = Scts,
		       udl = Udl,
		       ud = Ud}.

%%io:format("sms deliver = ~w~n", [Out]).

parse_flags(sms_deliver, Flags)->
    <<Rp:1, Udhi:1, Sri:1, _Reserved:1, Lp:1,  Mms:1, _Rest:2>> = <<Flags>>,
    %%<<Rest:6, Mti:2>> = <<Flags>>,
%%case Mti of
      [Rp, Udhi, Sri, Lp, Mms];
parse_flags(sms_submit, Flags)->
    <<Rp:1, Udhi:1, Srr:1, Vpf:2,  Rd:1, _Rest:2>> = <<Flags>>,
    %%<<Rest:6, Mti:2>> = <<Flags>>,
%%case Mti of
      [Rp, Udhi, Srr, Vpf, Rd].



parse_sms_submit(_Data)->
    ok.

get_oa(Data)->
    <<MTI:8, OAlength:8, OAtype:8, Rest/binary>> = Data,
    case OAtype of
	16#91 ->
	    decode_numeric_oa(OAlength, Rest);
	Other -> decode_oa_carefully(Other, OAlength, Rest)
    end.


%% output - {binary(), binary()}
%% even number of address digits
decode_numeric_oa(Length, Data) when (( Length band 1) == 0)->
    OAnum_bytes = Length div 2,
    << OA:OAnum_bytes, Rest/binary >> = Data,  
    {OA, Rest};
%% odd numbers of addres digits(ex. 0x0b)
decode_numeric_oa(Length, Data) ->
    OAnum_bytes = (Length+1) div 2,
%%    io:format("num bytes = ~p~n", [OAnum_bytes]),
    << OA:OAnum_bytes/binary, Rest/binary >> = Data,  
    {OA, Rest}.

decode_oa_carefully(_Type,_Length,_Rest)->
    ok.
%%for even number of semioctets of gsm7bit coded OA 
decode_alphanum_oa(Length, Data) when (( Length band 1) == 0) ->
    OAnum_bytes = Length div 2,
    << OA:OAnum_bytes/binary, Rest/binary >> = Data,  
    {OA, Rest};
decode_alphanum_oa(Length, Data)->
    OAnum_bytes = (Length+1) div 2,
%%    io:format("num bytes = ~p~n", [OAnum_bytes]),
    << OA:OAnum_bytes/binary, Rest/binary >> = Data,  
    {OA, Rest}.


even(X) when X >= 0 -> (X band 1) == 0.
odd(X) when X > 0 -> not even(X).

%% TP-DA should be argument for this function!
%% get it in some previous state!!
%% output - binary
create_sms_submit(Sms_deliver, Tp_da)->

    %%Sms_deliver = get(sms_deliver),
    %%Sms_deliver = test2(),
%% Flags
%% 0... .... TP-RP   Reply Path is not set
%% .?.. .... TP-UDHI 0: TP-UD contains only short message, 1 - contains header
%% ..0. .... TP-SRR 1: status report requested, 0 - status report not requested
%% ...1 0... TP-VPF relative format
%% .... .0.. TP-RD 1: insturct SC to reject duplicates, 0 - duplicates allowed
%% .... ..01 TP-MTI: sms-submit 

    {NewUDL, NewUD} = case Sms_deliver#sm_rp_ui.udhi of
			  1->
			      Flags = 16#51,
			      {Sms_deliver#sm_rp_ui.udl, Sms_deliver#sm_rp_ui.ud};
			  0 ->
			      Flags = 16#11,
			      construct_new_ud(Sms_deliver)
		      end,

io:format("sms deliver = ~w~n", [Sms_deliver]),

    Bin0 = <<Flags>>,
    Mr=?default_mr,
%%Pid = Sms_deliver#sm_rp_ui.pid,
    Bin2 = <<Bin0/binary, Mr >>,
    Da = list_to_binary(Tp_da),
    Bin3 = << Bin2/binary, Da/binary >>,    
    Bin4 = << Bin3/binary, (Sms_deliver#sm_rp_ui.pid) >>,
    Bin5 = << Bin4/binary, (Sms_deliver#sm_rp_ui.dcs) >>,
    Bin6 = << Bin5/binary, 255 >>,
    Bin7 = << Bin6/binary, NewUDL:8 >>,
    Bin8 = << Bin7/binary, NewUD/binary>>,
io:format("sm rp ui itog = ~p~n",[Bin8]),
    Bin8.


%% function to construct new text for sms concatenad with DA
%% initially works for international OA types
%% for alphanumeric OA there is no prefix and no text modification
construct_new_ud(Sms_deliver)->
    case Sms_deliver#sm_rp_ui.oa_type of
	16#91->
	    MsisdnDigits = bcd:decode(msisdn, Sms_deliver#sm_rp_ui.oa_data),
	    List = [ [0, 48 + Digit] || Digit <- MsisdnDigits, Digit < 10],
	    io:format("List = ~w~n", [lists:flatten(List)]),
	    UDPrefix = lists:flatten(List) ++ [0,58,0,32],
	    %%PrefixLength = length(UDPrefix),
	    io:format("ud = ~p, udl = ~p ~n", [Sms_deliver#sm_rp_ui.ud, Sms_deliver#sm_rp_ui.udl]),
	    {UDL,UD} = case Sms_deliver#sm_rp_ui.dcs of
			   8 ->
			       modify_user_data(UDPrefix,
						Sms_deliver#sm_rp_ui.udl,
						Sms_deliver#sm_rp_ui.ud,
						Sms_deliver#sm_rp_ui.udhi
					       );
			   _Other ->
			       {Sms_deliver#sm_rp_ui.udl, Sms_deliver#sm_rp_ui.ud}
		       end;
	16#d0->
	    {UDL,UD} ={Sms_deliver#sm_rp_ui.udl,Sms_deliver#sm_rp_ui.ud}
    end,
    {UDL, UD}.


modify_user_data(UDPrefix, Udl, Ud, Udhi)->
    case Udhi of
	0 ->
	    Length = length(UDPrefix),   
	    if Length + Udl < 140 ->
		    {Length + Udl,
		     list_to_binary(UDPrefix ++ binary_to_list(Ud))};
	       true ->
		   {Udl, Ud}
	    end; 
	1 ->
	    {Udl, Ud}
    end.



test()->
    Data = << 16#24, 16#0b, 16#91, 16#97, 16#20, 16#17, 16#11, 16#82, 16#f7, 16#00,
	      16#08, 16#81, 16#90, 16#12, 16#00, 16#53, 16#23, 16#21, 16#08, 
	      16#04, 16#22, 16#04, 16#35, 16#04, 16#41, 16#04, 16#42 >>,
    << 16#97, 16#20, 16#17, 16#11, 16#82, 16#f7 >> = get_oa(Data),
    ok.

%%input test sms_deliver with udhi = 0, and OA num = international
test2_0()->
    Data  = << 16#24, 16#0b, 16#91, 16#97, 16#20,
	     16#17, 16#11, 16#82, 16#f7, 16#00,
	     16#08, 16#81, 16#90, 16#12, 16#00,
	     16#53, 16#23, 16#21, 16#08, 16#04,
	     16#22, 16#04, 16#35, 16#04, 16#41,
	     16#04, 16#42 >>,
    parse(Data).

%%input test sms_deliver with udhi = 1, and OA num = alphanumeric Letai
test2_1() ->
    Data = << 16#64, 16#0a, 16#d0, 16#cc, 16#32, 16#3d,  16#9c, 16#06,
	      0, 16#08, 16#81, 16#21, 16#12, 16#41, 16#50, 16#90, 16#21,
	      16#1a, 16#05, 0, 16#03, 1, 1, 1,
	      16#04, 16#42, 16#04, 16#35, 16#04, 16#41, 16#04, 16#42,
	      0, 16#20, 0, 16#31, 0, 16#34, 0, 16#3a, 0, 16#30, 0, 16#30 >>,
    parse(Data).

test3() ->
    Sms_deliver = test2_1(),
    Tp_da = [11,145,151,21,96,82,85,245],
    Out = create_sms_submit(Sms_deliver, Tp_da),
    io:format("out = ~p~n", [Out]).
