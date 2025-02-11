open Lwt.Infix
open Cmdliner

let buffsize =
  let doc = Arg.info ~doc:"number of sectors to transfer at a time" [ "buffsize" ] in
  Arg.(value & opt int 50 doc)

module Main
  (MClock : Mirage_clock.MCLOCK)
  (B1 : Mirage_block.S)
  (B2 : Mirage_block.S with type error = B1.error and type write_error =
      B1.write_error) =
struct
  let log_src = Logs.Src.create "block" ~doc:"block tester"

  module Log = (val Logs.src_log log_src : Logs.LOG)

  let (let*) = Lwt.bind

  let copy_block b1 b2 buffsize =
    let get_ok () = Lwt.map Result.get_ok in
    B1.get_info b1 >>= fun info ->
    Log.info (fun f -> f "%a" Mirage_block.pp_info info);
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
        let* () = B1.read b1 off sectors |> get_ok () in
        let* () = B2.write b2 off sectors |> get_ok () in
        aux Int64.(add off (of_int len))
    in
    aux 0L

  let start _mclock b1 b2 buffsize =
    Logs.info (fun f -> f "Buffsize: %d" buffsize);
    let* res = copy_block b1 b2 buffsize in
    Lwt.return_unit
end
