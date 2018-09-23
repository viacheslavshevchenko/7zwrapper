-module('7zwrapper').
-author('vshev4enko').

-define(ARCHIEVER, "7z").
-define(PORT_TIMEOUT, 30000).
-define(FILE_NAME_EXP, <<"[A-Z0-9a-z_]+.csv|[a-zA-Z0-9]+.dbf|[0-9]{2}.[0-9]{2}.[0-9]{4}.dbf|[a-zA-Z0-9]+.DBF">>).


-export([list/1,
         extract/3]).


extract(FileName, FilesToExtract, stdout) ->
    extract(FileName, FilesToExtract, true);
extract(FileName, FilesToExtract, DestinationPath) ->
    {StdOut, Dest} = if DestinationPath == true -> {true, "-so"};
                         true -> {false, "-o" ++ DestinationPath}
                     end,
    Files = case FilesToExtract of
                [_] = File -> File;
                [_ | _] -> FilesToExtract
            end,
    case get_executor(?ARCHIEVER) of
        {ok, Executor} ->
            Args = {args, ["e", FileName] ++ Files ++ [Dest]},
            Options = [exit_status, {line, 255}, Args, binary],
            Port = erlang:open_port({spawn_executable, Executor}, Options),
            case loop_messages(Port, <<>>) of
                {ok, Result} ->
                    if StdOut == true -> {ok, Result};
                        true -> {ok, FilesToExtract}
                    end;
                {error, _} = Error -> Error
            end;
        {error, _} = Err -> Err
    end.

list(FileName) ->
    case get_executor(?ARCHIEVER) of
        {ok, Executor} ->
            Args = {args, ["l", FileName]},
            Options = [exit_status, {line, 255}, Args, binary],
            Port = erlang:open_port({spawn_executable, Executor}, Options),
            case loop_messages(Port, <<>>) of
                {ok, Result} ->
                    {ok, FileList} = match_stdout(Result),
                    {ok, FileList};
                {error, _} = Error -> Error
            end;
        {error, _} = Err -> Err
    end.

get_executor(Name) ->
    case os:find_executable(Name) of
        false -> {error, not_found};
        Path -> {ok, Path}
    end.

loop_messages(Port, Acc)
    when is_port(Port), is_binary(Acc) ->
    receive
        {Port, {data, {eol, <<>>}}} ->
            loop_messages(Port, Acc);
        {Port, {data, {eol, Msg}}} ->
            loop_messages(Port, <<Acc/binary, Msg/binary>>);
        {Port, {data, {noeol, <<>>}}} ->
            loop_messages(Port, Acc);
        {Port, {data, {noeol, Msg}}} ->
            loop_messages(Port, <<Acc/binary, Msg/binary>>);
        {Port, {exit_status, ExitCode}} ->
            case ExitCode of
                0 -> {ok, Acc};
                Code -> {error, Code}
            end
    after ?PORT_TIMEOUT ->
        erlang:port_close(Port),
        {error, timed_out}
    end.

match_stdout(Str) ->
    [_ | Tail] = binary:split(Str, <<"-------------------">>),
    case re:run(Tail, ?FILE_NAME_EXP, [{capture, all, binary}, global]) of
        {match, Matched} ->
            case Matched of
                [[File]] -> {ok, binary_to_list(File)};
                [_ | _] = ListOfLists ->
                    Result = lists:foldl(
                        fun(X, Acc) ->
                            case X of
                                [Name] -> lists:reverse([binary_to_list(Name) | Acc]);
                                [] -> Acc
                            end
                        end, [], ListOfLists),
                    {ok, Result}
            end;
        nomatch ->
            io:format("Error nomatch"),
            {error, nomatch}
    end.

