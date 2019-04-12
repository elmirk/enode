-module(mo_sms).
-author('elmir.karimullin@gmail.com').

-export([create_sms_submits/2]).

-include("sm_rp_ui.hrl").

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
		   ud,  %%binary
                   ud_ascii, %parsed ud in case of gsm7bit coding
                   header_length,
                   header,
                   ud_wo_header}). %%binary

-record(concat, {
                 header_length = [5],
                 ie_identifier = [0], %%concatenated sms
                 length_of_iea = [3], %% use 3 octets going next for
                 %% concatenated sms
                 ref_number, %%modulo 256 counter
                 max_number,
                 seq_number,
                 udl, %%septets number for gsm7bit, octets number for ucs2
                 ud  %% user data, related to text
                }).

%% should create list of sms_submits

%% GSM SMS TPDU (GSM 03.40) SMS-SUBMIT

%% 16#51:

%%    0... .... = TP-RP: TP Reply Path parameter is not set in this SMS SUBMIT/DELIVER
%%    .1.. .... = TP-UDHI: The beginning of the TP UD field contains a Header in addition to the short message
%%    ..0. .... = TP-SRR: A status report is not requested
%%    ...1 0... = TP-VPF: TP-VP field present - relative format (2)
%%    .... .0.. = TP-RD: Instruct SC to accept duplicates
%%    .... ..01 = TP-MTI: SMS-SUBMIT (1)




create_sms_submits(Tp_da, Key) ->
    Delivers = [ {_, H} | _T ] = ets:lookup(parts, Key),
    Out = [{Seq, {Dcs, Ud}} || {_Imsiref, #sm_rp_ui{
                                 header = << _, _, _Ref:8, _Max:8, Seq:8 >>,
                                 ud_wo_header = Ud,
                                 dcs = Dcs
                                }} <- Delivers],    

    Sorted = lists:keysort(1, Out),
    [{_, {Dcs, _}} | _] = Sorted,
           
    Parts = case Dcs of
                ?dcs_ucs2->
                    UdFull = lists:foldr(fun({_Seq, {_Dcs, Ud1}}, Acc) -> 
                                                 binary_to_list(Ud1) ++ Acc 
                                     end, [], Sorted),
                    
                    case H#sm_rp_ui.oa_type of
                        ?oa_numeric ->
                            MsisdnDigits = bcd:decode(msisdn, H#sm_rp_ui.oa_data),
                            %%MsisdnDigits = bcd:decode(msisdn, Sms_deliver#sm_rp_ui.oa_data),
                            List = [ [0, 48 + Digit] || Digit <- MsisdnDigits, Digit < 10],
                            %%  io:format("List = ~w~n", [lists:flatten(List)]),
                            UDPrefix = lists:flatten(List) ++ [0,58,0,32],
                            Ud2 = UDPrefix ++ UdFull,
                            sm_rp_ui:prepare_concatenated(length(Ud2), Ud2);
                        
                        ?oa_alpha ->
                            %%in case when OA is alphanum
                            %%it is ascii chars
                            OAchars = sms_7bit_encoding:from_7bit(H#sm_rp_ui.oa_data),
                            List = [ [0, Char] || Char <- OAchars],
                            Prefix = lists:flatten(List) ++ [0,58,0,32],
                            %%UDPrefix = OAchars ++ [58,32],
                            Ud2 = Prefix ++ UdFull,
                            sm_rp_ui:prepare_concatenated(length(Ud2), Ud2)
                    end;
                    
                ?dcs_7bit ->
                    UdFull = merge_all_ud(Sorted),
                    case H#sm_rp_ui.oa_type of
                        ?oa_numeric ->
                            MsisdnDigits = bcd:decode(msisdn, H#sm_rp_ui.oa_data),
                            %%MsisdnDigits = bcd:decode(msisdn, Sms_deliver#sm_rp_ui.oa_data),
                            List = [ 48 + Digit || Digit <- MsisdnDigits, Digit < 10],
                            Prefix = List ++ [58,32],
                            Ud2 = Prefix ++ UdFull,
                            sm_rp_ui:prepare_concatenated(gsm7bit, length(Ud2),
                                                          Ud2);
                        ?oa_alpha ->
                            OAchars = sms_7bit_encoding:from_7bit(H#sm_rp_ui.oa_data),
                            Prefix = OAchars ++ ": ",
                            Ud2 = Prefix ++ UdFull,
                            sm_rp_ui:prepare_concatenated(gsm7bit, length(Ud2),
                                                          Ud2)
                    end
            end, 
    MaxNum = length(Parts),

    Bin0 = <<16#51>>, %%UDHI flag set for concatenated
    
    io:format("concatenated parts = ~p~n", [Parts]),

    Mr=?default_mr,
    %%Pid = Sms_deliver#sm_rp_ui.pid,
    Bin2 = <<Bin0/binary, Mr >>,
    Da = list_to_binary(Tp_da),
    Bin3 = << Bin2/binary, Da/binary >>,    
    Bin4 = << Bin3/binary, (H#sm_rp_ui.pid) >>,
    Bin5 = << Bin4/binary, (H#sm_rp_ui.dcs) >>,
    Bin6 = << Bin5/binary, 255 >>,

    
            Out2 = lists:map(fun(A) ->
                                    UD =
                                    list_to_binary(A#concat.header_length
                                    ++ A#concat.ie_identifier ++ A#concat.length_of_iea ++ A#concat.ref_number ++
                                                            [MaxNum] ++
                                                            A#concat.seq_number ++ A#concat.ud),
                                    L = A#concat.udl,
                                    Bin7 = << Bin6/binary, L:8 >>,
                                    Bin8 = << Bin7/binary, UD/binary>>,
                                    %%io:format("sm rp ui itog = ~p~n",[Bin8]),
                                    Bin8
                            end, Parts).
                    %%should send concatenated messages to SMSC
         %%   ok;
      %%  true->
            
            %%Bin0 = <<Flags>>,
            %%Mr=?default_mr,
            
          %%  Bin2 = <<Bin0/binary, Mr >>,
          %%  Da = list_to_binary(Tp_da),
          %%  Bin3 = << Bin2/binary, Da/binary >>,    
          %%  Bin4 = << Bin3/binary, (Sms_deliver#sm_rp_ui.pid) >>,
          %%  Bin5 = << Bin4/binary, (Sms_deliver#sm_rp_ui.dcs) >>,
          %%  Bin6 = << Bin5/binary, 255 >>,
        %%    Bin7 = << Bin6/binary, NewUDL:8 >>,
          %%  Bin8 = << Bin7/binary, NewUD/binary>>,
          %%  io:format("sm rp ui itog = ~p~n",[Bin8]),
          %%  Bin8
    %%end.



-spec merge_all_ud( Sorted :: [{integer(), {integer(), binary()}}] ) -> string().

merge_all_ud(Sorted)->
    
    Res = lists:foldr(fun({_Seq, {_Dcs, Ud1}}, Acc) -> 
                              Gsm_7bit = sms_7bit_encoding:remove_fillbit_from_7bit(Ud1),
                              AsciiList = sms_7bit_encoding:from_7bit(Gsm_7bit),
                              AsciiList ++  Acc 
                      end, [], Sorted).
%%    binary_to_list(Res).





