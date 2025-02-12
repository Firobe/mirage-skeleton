open Lwt.Infix
open Cmdliner

let buffsize =
  let doc = Arg.info ~doc:"number of sectors to transfer at a time" [ "buffsize" ] in
  Arg.(value & opt int 50 doc)

let parallel =
  let doc = Arg.info ~doc:"process copies in parallel" [ "parallel" ] in
  Arg.(value & opt bool false doc)

module Main
  (MClock : Mirage_clock.MCLOCK)
  (B1 : Mirage_block.S)
  (B2 : Mirage_block.S) =
struct
  let log_src = Logs.Src.create "block" ~doc:"block tester"

  module Log = (val Logs.src_log log_src : Logs.LOG)

  let (let*) = Lwt.bind

  let copy_block b1 b2 buffsize parallel =
    let get_ok () = Lwt.map Result.get_ok in
    B1.get_info b1 >>= fun info ->
    Log.info (fun f -> f "%a" Mirage_block.pp_info info);
    let sectors = [ Cstruct.create (buffsize * info.sector_size) ] in
    let create_job off len sectors =
        let* () = B1.read b1 off sectors |> get_ok () in
        B2.write b2 off sectors |> get_ok ()
    in
    let rec aux off acc =
        if off >= info.size_sectors then acc
      else
        let remain = Int64.(to_int (sub info.size_sectors off)) in
        let len, sectors =
          if buffsize > remain then
            (remain, [ Cstruct.create (remain * info.sector_size) ])
          else (buffsize, sectors)
        in
        let job = (off, len, sectors) in
        aux Int64.(add off (of_int len)) (job :: acc)
    in
    let inputs = aux 0L [] in
    let f = if parallel then Lwt_list.iter_p else Lwt_list.iter_s in
    f (fun (off, len, sectors) -> create_job off len sectors) inputs

  let start _mclock b1 b2 buffsize parallel =
      Logs.info (fun f -> f "Buffsize: %d; Parallel: %B" buffsize parallel);
    let* res = copy_block b1 b2 buffsize parallel in
    Lwt.return_unit
end
