open Lwt.Infix
open Cmdliner

let port =
  let doc =
    Arg.info ~doc:"The TCP port on which to listen for incoming connections."
      [ "port" ]
  in
  Mirage_runtime.register_arg Arg.(value & opt int 8080 doc)

type stats = {
  mutable start : int64 option;
  mutable size : int;
}

let stats () = { start = None; size = 0 }

let kick_start stats =
  let now = Mirage_mtime.elapsed_ns () in
  if Option.is_none stats.start then stats.start <- Some now

let dump stats =
  let now = Mirage_mtime.elapsed_ns () in
  let start = Option.get @@ stats.start in
  let time = Int64.(div (sub now start) 1000000L) in
  Logs.info (fun f -> f "Read %i bytes in %Lu ms" stats.size time);
  stats.start <- Some now;
  stats.size <- 0

let tick stats size =
  let now = Mirage_mtime.elapsed_ns () in
  let start = Option.get stats.start in
  stats.size <- stats.size + size;
  let time = Int64.(sub now start) in
  if time >= 1000000000L then dump stats

module Main (S : Tcpip.Stack.V4V6) = struct
  let start s =
    let rec loop stats flow =
      kick_start stats;
        S.TCP.read flow >>= function
        | Ok `Eof ->
            dump stats;
            Logs.info (fun f -> f "Closing connection!");
            S.TCP.close flow
        | Error e ->
            Logs.warn (fun f ->
                f "Error reading data from established connection: %a"
                  S.TCP.pp_error e);
            Lwt.return_unit
        | Ok (`Data b) ->
            let length = Cstruct.length b in
            tick stats length;
            loop stats flow
    in
    S.TCP.listen (S.tcp s) ~port:(port ()) (fun flow ->
        let dst, dst_port = S.TCP.dst flow and stats = stats () in
        Logs.info (fun f ->
            f "new tcp connection from IP %s on port %d" (Ipaddr.to_string dst)
              dst_port);
        loop stats flow);

    S.listen s
end
