%%%
%%%
%%% all stuff about MO-FORWARD-SM to SMSC TMT
%%% and received ReturnResult from SMSC TMT
%%

-module(submission).
-author('elmir.karimullin@gmail.com').


-export([submit_sent/0,
         submit_confirmed/0,
         get_confirmation_status/0]).

-record(mv, {submits = 0,
             submits_confirmed = 0,
             tp_scts = []}). %%list for tp_scts that should be parsed from sm_rp_ui


%% every MO-FORWARD-SM we should increment submit number in mv 
submit_sent()->
    case get(mv_submission) of
        undefined ->
            put(mv_submission, #mv{submits = 1});
        Mv->
            Sent = Mv#mv.submits,
            NewMv = Mv#mv{submits = Sent + 1},
            put(mv_submission, NewMv)
    end.
            
%% every ReturnResult for MO-FORWARD-SM received from SMSC TMT
%% we should increment submits_confirmed
submit_confirmed()->
    Mv = get(mv_submission),
    Confirmed = Mv#mv.submits_confirmed,
    NewMv = Mv#mv{submits_confirmed = Confirmed + 1},
    put(mv_submission, NewMv).

get_confirmation_status()->
    Mv = get(mv_submission),
    case Mv#mv.submits =:= Mv#mv.submits_confirmed of
        true->
            all_confirmed;
        false ->
            confirmation_ongoing
    end.
