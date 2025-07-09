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

module Main (B1 : Mirage_block.S) (B2 : Mirage_block.S) = struct
  let log_src = Logs.Src.create "block" ~doc:"block tester"

  module Log = (val Logs.src_log log_src : Logs.LOG)

  let copy_block b1 b2 buffsize parallel =
    let get_ok () = Lwt.map Result.get_ok in
    let get_ok1 () =
      Lwt.map (function
        | Ok () -> ()
        | Error e -> failwith (Fmt.str "read error: %a" B1.pp_error e))
    in
    B1.get_info b1 >>= fun info ->
    Log.info (fun f -> f "%a" Mirage_block.pp_info info);
    let total_size = Int64.to_int info.size_sectors * info.sector_size in
    let buffer =
      Bigarray.Array1.create Bigarray.Char Bigarray.c_layout total_size
    in
    Logs.debug (fun f -> f "allocation OK: %d bytes" total_size);
    let create_job off _len sectors =
      let* () = B1.read b1 off sectors |> get_ok1 () in
      B2.write b2 off sectors |> get_ok ()
    in
    let rec aux off acc =
      if off >= info.size_sectors then acc
      else
        let remain = Int64.(to_int (sub info.size_sectors off)) in
        let len = min buffsize remain in
        let sub =
          Bigarray.Array1.sub buffer
            (info.sector_size * Int64.to_int off)
            (len * info.sector_size)
        in
        let sectors = [ Cstruct.of_bigarray sub ] in
        let job = (off, len, sectors) in
        aux Int64.(add off (of_int len)) (job :: acc)
    in
    let inputs = aux 0L [] in
    Logs.debug (fun f -> f "inputs OK");
    let f = if parallel then Lwt_list.iter_p else Lwt_list.iter_s in
    let before = Mirage_mtime.elapsed_ns () in
    let* () =
      f (fun (off, len, sectors) -> create_job off len sectors) inputs
    in
    let after = Mirage_mtime.elapsed_ns () in
    Lwt.return (Int64.sub after before)

  let start b1 b2 buffsize parallel =
    Logs.err (fun f -> f "Buffsize: %d; Parallel: %B" buffsize parallel);
    let* res = copy_block b1 b2 buffsize parallel in
    Logs.err (fun f -> f "done: %Ld" res);
    Lwt.return_unit
end
