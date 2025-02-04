open Mirage

let main =
  let packages = [ package "duration" ] in
  main ~packages "Unikernel.Main" (mclock @-> block @-> block @-> job)

let img1 =
  if_impl Key.is_solo5 (block_of_file "storage1")
    (if_impl Key.is_unikraft (block_of_file "block0") (block_of_file "disk1.img"))

let img2 =
  if_impl Key.is_solo5 (block_of_file "storage2")
    (if_impl Key.is_unikraft (block_of_file "block1") (block_of_file "disk2.img"))

let () = register "block_test" [ main $ default_monotonic_clock $ img1 $ img2 ]
