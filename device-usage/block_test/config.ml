open Mirage

let runtime_args = [ 
    runtime_arg ~pos:__POS__ "Unikernel.buffsize";
    runtime_arg ~pos:__POS__ "Unikernel.parallel"
]

let main =
  let packages = [ package "duration" ] in
  main ~runtime_args ~packages "Unikernel.Main" (mclock @-> block @-> block @-> job)

let img1 =
  if_impl Key.is_solo5 (block_of_file "storage1")
    ((block_of_file "disk1.img"))

let img2 =
  if_impl Key.is_solo5 (block_of_file "storage2")
    ((block_of_file "disk2.img"))

let () = register "block_test" [ main $ default_monotonic_clock $ img1 $ img2 ]
