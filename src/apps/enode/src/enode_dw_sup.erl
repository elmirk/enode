%%%-------------------------------------------------------------------
%%% @author root <root@elmir-N56VZ>
%%% @copyright (C) 2019, root
%%% @doc
%%%
%%% @end
%%% Created : 20 Mar 2019 by root <root@elmir-N56VZ>
%%%-------------------------------------------------------------------
-module(enode_dw_sup).

-behaviour(supervisor).

%% API
-export([start_link/1]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor for dynamic workers.
%% Workers then start in enode_broker module by calling supervisor:start_child
%% @end
%%--------------------------------------------------------------------
-spec start_link(MFA :: tuple()) -> {ok, Pid :: pid()} |
				    {error, {already_started, Pid :: pid()}} |
				    {error, {shutdown, term()}} |
				    {error, term()} |
				    ignore.
%%start_link() ->
%%    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

start_link(MFA = {_,_,_}) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, MFA).
 
%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart intensity, and child
%% specifications.
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) ->
		  {ok, {SupFlags :: supervisor:sup_flags(),
			[ChildSpec :: supervisor:child_spec()]}} |
		  ignore.
init({M,F,A}) ->

    MaxRestart = 5,
    MaxTime = 3600,

    SupFlags = #{strategy => simple_one_for_one,
		 intensity => MaxRestart,
		 period => MaxTime},

    AChild = #{id => dw_sup,
	       start => {M,F,A},
	       restart => temporary,
	       shutdown => 5000, %%brutal_kill,
	       type => worker,
	       modules => [M]},

    {ok, {SupFlags, [AChild]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
