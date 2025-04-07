open Mirage

let runtime_args = [ 
    runtime_arg ~pos:__POS__ "Unikernel.buffsize";
    runtime_arg ~pos:__POS__ "Unikernel.parallel"
]

let main =
  let packages = [ package "duration" ] in
  main ~runtime_args ~packages "Unikernel.Main" (block @-> block @-> job)

let img1 = block_of_file "0"
let img2 = block_of_file "1"

let () = register "block_test" [ main $ img1 $ img2 ]
