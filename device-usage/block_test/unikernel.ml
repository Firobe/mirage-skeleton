open Lwt.Infix
open Cmdliner

let buffsize =
  let doc =
    Arg.info ~doc:"number of sectors to transfer at a time" [ "buffsize" ]
  in
  Arg.(value & opt int 50 doc)

let parallel =
  let doc = Arg.info ~doc:"process copies in parallel" [ "parallel" ] in
  Arg.(value & opt bool false doc)

let ( let* ) = Lwt.bind

(* limit 32 *)
module Semaphore = struct
  type t = {
    cond : unit Lwt_condition.t;
    mutex : Lwt_mutex.t;
    mutable wakeups : int;
    mutable value : int;
  }

  let create n =
    {
      value = n;
      wakeups = 0;
      mutex = Lwt_mutex.create ();
      cond = Lwt_condition.create ();
    }

  let rec wait_for_wakeup t =
    let* () = Lwt_condition.wait ~mutex:t.mutex t.cond in
    if t.wakeups >= 1 then (
      t.wakeups <- t.wakeups - 1;
      Lwt.return_unit)
    else wait_for_wakeup t

  let acquire t =
    Lwt_mutex.with_lock t.mutex (fun () ->
        t.value <- t.value - 1;
        if t.value < 0 then wait_for_wakeup t else Lwt.return_unit)

  let release t =
    Lwt_mutex.with_lock t.mutex (fun () ->
        t.value <- t.value + 1;
        if t.value <= 0 then (
          t.wakeups <- t.wakeups + 1;
          Lwt_condition.signal t.cond ();
          Lwt.return_unit)
        else Lwt.return_unit)
end

module Main
    (MClock : Mirage_clock.MCLOCK)
    (B1 : Mirage_block.S)
    (B2 : Mirage_block.S) =
struct
  let log_src = Logs.Src.create "block" ~doc:"block tester"

  module Log = (val Logs.src_log log_src : Logs.LOG)

  let copy_block b1 b2 buffsize parallel =
    let get_ok () = Lwt.map Result.get_ok in
    B1.get_info b1 >>= fun info ->
    Log.info (fun f -> f "%a" Mirage_block.pp_info info);
    let wrap_read =
      let sem = Semaphore.create 32 in
      fun a b c ->
        let* () = Semaphore.acquire sem in
        let* res = B1.read a b c in
        let* () = Semaphore.release sem in
        Lwt.return res
    in
    let wrap_write =
      let sem = Semaphore.create 32 in
      fun a b c ->
        let* () = Semaphore.acquire sem in
        let* res = B2.write a b c in
        let* () = Semaphore.release sem in
        Lwt.return res
    in
    let create_job off _len sectors =
      let* () = wrap_read b1 off sectors |> get_ok () in
      wrap_write b2 off sectors |> get_ok ()
    in
    let rec aux off acc =
      if off >= info.size_sectors then acc
      else
        let remain = Int64.(to_int (sub info.size_sectors off)) in
        let len, sectors =
          if buffsize > remain then
            (remain, [ Cstruct.create (remain * info.sector_size) ])
          else (buffsize, [ Cstruct.create (buffsize * info.sector_size) ])
        in
        let job = (off, len, sectors) in
        aux Int64.(add off (of_int len)) (job :: acc)
    in
    let inputs = aux 0L [] in
    let f = if parallel then Lwt_list.iter_p else Lwt_list.iter_s in
    let before = MClock.elapsed_ns () in
    let* () =
      f (fun (off, len, sectors) -> create_job off len sectors) inputs
    in
    let after = MClock.elapsed_ns () in
    Lwt.return (Int64.sub after before)

  let start _mclock b1 b2 buffsize parallel =
    Logs.err (fun f -> f "Buffsize: %d; Parallel: %B" buffsize parallel);
    let* res = copy_block b1 b2 buffsize parallel in
    Logs.err (fun f -> f "done: %Ld" res);
    Lwt.return_unit
end
