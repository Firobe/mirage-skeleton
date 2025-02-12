open Mirage

let runtime_args = [ 
    runtime_arg ~pos:__POS__ "Unikernel.buffsize";
    runtime_arg ~pos:__POS__ "Unikernel.parallel"
]

let main =
  let packages = [ package "duration" ] in
  main ~runtime_args ~packages "Unikernel.Main" (mclock @-> block @-> block @-> job)

let img1 = block_of_file "block0"
let img2 = block_of_file "block1"

let () = register "block_test" [ main $ default_monotonic_clock $ img1 $ img2 ]
