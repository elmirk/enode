%%%-------------------------------------------------------------------
%%% @author root <root@elmir-N56VZ>
%%% @copyright (C) 2019, root
%%% @doc
%%%
%%% @end
%%% Created : 20 Mar 2019 by root <root@elmir-N56VZ>
%%%-------------------------------------------------------------------
-module(enode_root_sup).

-behaviour(supervisor).

%% API
-export([start_link/3]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%% @end
%%--------------------------------------------------------------------
%%-spec start_link() -> {ok, Pid :: pid()} |
%%		      {error, {already_started, Pid :: pid()}} |
%%		      {error, {shutdown, term()}} |
%%		      {error, term()} |
%%		      ignore.
start_link(Name, Limit, MFA) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, {Name, Limit, MFA}).

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
init({Name, Limit, MFA}) ->

    SupFlags = #{strategy => one_for_one,
		 intensity => 1,
		 period => 5},

    AChild = #{id => broker,
	       start => {enode_broker, start_link, [Name, Limit, self(), MFA]},
	       restart => permanent,
	       shutdown => 5000,
	       type => worker,
	       modules => [enode_broker]},

    {ok, {SupFlags, [AChild]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
