-module(bcd).
%%-compile(export_all).

-export([encode/2,
	 decode/2,
	 test/0]).
% pack the digits of an integer as BCD in a given size of binary
% pad with leading zeros
%%encode(N, Size) ->
%%  encode(N, Size, []).
%%% Any BCD code /decode functions used in SMSR
%%encode(_, 0, Acc) -> list_to_binary(Acc);
%%encode(N, Size, Acc) ->
%%  B  = N  rem 10,
%%  N1 = N  div 10,
%%  A  = N1 rem 10,
%%  N2 = N1 div 10,
%%  encode(N2, Size - 1, [(A bsl 4) + B | Acc]).

-spec encode(atom(), integer()) -> binary().
encode(imsi, N)->
    B = integer_to_binary(N),
    NewB = <<B/binary, 63 >>,
    encode1(NewB, []).

encode1(<< >>, Acc) -> encode2(list_to_binary(Acc), << >>);
encode1(B, Acc)->
    << A:8, Rest/binary>> = B,
    Digit = A - 48,
    encode1(Rest, [ Digit | Acc]).

encode2(<< >>, Acc2) -> rev(Acc2);
encode2(Acc, Acc2)->
    %%C = list_to_binary(Acc),
    << A:16, Rest/binary >> = Acc,
    M = A bsr 4, 
    L = A band 16#F,
    Out = M bor L,
    encode2(Rest, << Acc2/binary, Out >>).

rev(Binary) ->
   Size = erlang:size(Binary)*8,
   <<X:Size/integer-little>> = Binary,
   <<X:Size/integer-big>>.

%% return [7,9,0,2,7,1,1,1,2,8,7,15] from bcd coded msisdn

decode(msisdn, Data)-> decode(msisdn, Data, []).
decode(msisdn, << >>, Acc)->lists:reverse(Acc);
%%decode(msisdn, Data, [])->
%%    << H:8, Rest/binary>> = Data,
%%    L = H bsr 4,
%%    M = H band 16#F,
%%    %%Out = [M,L],
%%    decode(msisdn, Rest, [L | [M]]);
decode(msisdn, Data, Acc)->
    << H:8, Rest/binary>> = Data,
    L = H bsr 4,
    M = H band 16#F,
    Out = [L,M],
    decode(msisdn, Rest, Out ++ Acc).

%% return [250270000000000] from bcd coded imsi
%% not tested and seems not used yet
%%decode(imsi, Data)-> imsi(imsi, Data, []).
%%decode(imsi, << >>, Acc)->lists:reverse(Acc);
%%decode(msisdn, Data, [])->
%%    << H:8, Rest/binary>> = Data,
%%    L = H bsr 4,
%%    M = H band 16#F,
%%    %%Out = [M,L],
%%    decode(msisdn, Rest, [L | [M]]);
%%decode(imsi, Data, Acc)->
%%    << H:8, Rest/binary>> = Data,
%%    L = H bsr 4,
%%    M = H band 16#F,
%%    Out = [L,M],
%%    decode(msisdn, Rest, Out ++ Acc).

    


test()->
    << 16#52, 16#20, 16#07, 16#73, 16#21, 16#43, 16#65, 16#f7 >> = encode(imsi, 250270371234567),

    << 16#52, 16#20, 16#07, 16#19, 16#12, 16#13, 16#92, 16#f0 >> = encode(imsi, 250270912131290),

 %%   Imsi = << 16#52, 16#20, 16#07, 16#19, 16#12, 16#13, 16#92, 16#f0 >>,

    Msisdn = << 16#97, 16#20, 16#17, 16#11, 16#82, 16#f7 >>,

    [7,9,0,2,7,1,1,1,2,8,7,15] = decode(msisdn, Msisdn),

  %%  [2,5,0,2,7,0,9,1,2,1,3,1,2,9,0] = decode(imsi, Imsi),

    ok.
