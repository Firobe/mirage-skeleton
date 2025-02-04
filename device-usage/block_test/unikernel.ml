open Lwt.Infix

module Main
  (MClock : Mirage_clock.MCLOCK)
  (B1 : Mirage_block.S)
  (B2 : Mirage_block.S) =
struct
  let log_src = Logs.Src.create "block" ~doc:"block tester"

  module Log = (val Logs.src_log log_src : Logs.LOG)

  let copy_block b1 b2 =
    B1.get_info b1 >>= fun info ->
    Log.info (fun f -> f "%a" Mirage_block.pp_info info);
    let buffsize = 201 in
    let sectors = [ Cstruct.create (buffsize * info.sector_size) ] in
    let rec aux off =
      if off >= info.size_sectors then Lwt.return_unit
      else
        let remain = Int64.(to_int (sub info.size_sectors off)) in
        let len, sectors =
          if buffsize > remain then
            (remain, [ Cstruct.create (remain * info.sector_size) ])
          else (buffsize, sectors)
        in
        B1.read b1 off sectors >>= fun r ->
        (match r with
        | Ok () -> Log.info (fun f -> f "Read OK of %d at %Ld" len off)
        | Error e ->
            Log.err (fun m -> m "%a" B1.pp_error e);
            exit 2);
        B2.write b2 off sectors >>= fun r ->
        (match r with
        | Ok () -> Log.info (fun f -> f "Write OK of %d at %Ld" len off)
        | Error e ->
            Log.err (fun m -> m "%a" B2.pp_write_error e);
            exit 2);
        aux Int64.(add off (of_int len))
    in
    aux 0L

  let [@inline never] test_clock mclock =
    let time = MClock.elapsed_ns mclock in
    time

  let start mclock b1 b2 =
    let before = test_clock mclock in
    copy_block b1 b2 >>= fun () ->
    Unikraft_os.Time.sleep_ns 100000L >>= fun () ->
    let after = MClock.elapsed_ns mclock in
    Printf.printf "before = %Ld, after = %Ld\n" before after;
    Printf.printf "time = %Ld\n" Int64.(sub after before);
    Lwt.return_unit
end
