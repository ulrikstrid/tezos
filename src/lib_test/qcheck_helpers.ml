(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2021 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(* Permission is hereby granted, free of charge, to any person obtaining a   *)
(* copy of this software and associated documentation files (the "Software"),*)
(* to deal in the Software without restriction, including without limitation *)
(* the rights to use, copy, modify, merge, publish, distribute, sublicense,  *)
(* and/or sell copies of the Software, and to permit persons to whom the     *)
(* Software is furnished to do so, subject to the following conditions:      *)
(*                                                                           *)
(* The above copyright notice and this permission notice shall be included   *)
(* in all copies or substantial portions of the Software.                    *)
(*                                                                           *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR*)
(* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  *)
(* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   *)
(* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER*)
(* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   *)
(* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       *)
(* DEALINGS IN THE SOFTWARE.                                                 *)
(*                                                                           *)
(*****************************************************************************)

let qcheck_wrap ?verbose ?long ?rand =
  List.map (QCheck_alcotest.to_alcotest ?verbose ?long ?rand)

let qcheck_eq ?pp ?cmp ?eq expected actual =
  let pass =
    match (eq, cmp) with
    | (Some eq, _) -> eq expected actual
    | (None, Some cmp) -> cmp expected actual = 0
    | (None, None) -> Stdlib.compare expected actual = 0
  in
  if pass then true
  else
    match pp with
    | None ->
        QCheck.Test.fail_reportf
          "@[<h 0>Values are not equal, but no pretty printer was provided.@]"
    | Some pp ->
        QCheck.Test.fail_reportf
          "@[<v 2>Equality check failed!@,expected:@,%a@,actual:@,%a@]"
          pp
          expected
          pp
          actual

let qcheck_eq' ?pp ?cmp ?eq ~expected ~actual () =
  qcheck_eq ?pp ?cmp ?eq expected actual

let int64_range a b =
  let int64_range_gen st =
    let range = Int64.sub b a in
    let raw_val = Random.State.int64 st range in
    let res = Int64.add a raw_val in
    assert (a <= res && res <= b) ;
    res
  in
  QCheck.int64 |> QCheck.set_gen int64_range_gen

let rec of_option_gen gen random =
  match gen random with None -> of_option_gen gen random | Some a -> a

let of_option_arb QCheck.{gen; print; small; shrink; collect; stats} =
  let gen = of_option_gen gen in
  let print = Option.map (fun print_opt a -> print_opt (Some a)) print in
  let small = Option.map (fun small_opt a -> small_opt (Some a)) small in
  (* Only shrink if the optional value is non-empty. *)
  let shrink =
    Option.map
      (fun shrink_opt a f -> shrink_opt (Some a) (Option.iter f))
      shrink
  in
  let collect =
    Option.map (fun collect_opt a -> collect_opt (Some a)) collect
  in
  let stats = List.map (fun (s, f_opt) -> (s, fun a -> f_opt (Some a))) stats in
  QCheck.make ?print ?small ?shrink ?collect ~stats gen

let uint16 = QCheck.(0 -- 65535)

let int16 = QCheck.(-32768 -- 32767)

let uint8 = QCheck.(0 -- 255)

let int8 = QCheck.(-128 -- 127)

let bytes_arb = QCheck.(map ~rev:Bytes.to_string Bytes.of_string string)

let of_option_shrink shrink_opt x yield =
  Option.iter (fun shrink -> shrink x yield) shrink_opt

module MakeMapArb (Map : Stdlib.Map.S) = struct
  open QCheck

  let arb_of_size (size_gen : int Gen.t) (key_arb : Map.key arbitrary)
      (val_arb : 'v arbitrary) : 'v Map.t arbitrary =
    map
      ~rev:(fun map -> Map.to_seq map |> List.of_seq)
      (fun entries -> List.to_seq entries |> Map.of_seq)
      (list_of_size size_gen @@ pair key_arb val_arb)

  let arb (key_arb : Map.key arbitrary) (val_arb : 'v arbitrary) :
      'v Map.t arbitrary =
    arb_of_size Gen.small_nat key_arb val_arb

  let gen_of_size (size_gen : int Gen.t) (key_gen : Map.key Gen.t)
      (val_gen : 'v Gen.t) : 'v Map.t Gen.t =
    let open Gen in
    map
      (fun entries -> List.to_seq entries |> Map.of_seq)
      (list_size size_gen @@ pair key_gen val_gen)

  let gen (key_gen : Map.key Gen.t) (val_gen : 'v Gen.t) : 'v Map.t Gen.t =
    gen_of_size Gen.small_nat key_gen val_gen

  let shrink ?key:key_shrink ?value:val_shrink map yield =
    let open Shrink in
    let kv_list = map |> Map.to_seq |> List.of_seq in
    list
      ~shrink:(pair (of_option_shrink key_shrink) (of_option_shrink val_shrink))
      kv_list
      (fun smaller_kv_list ->
        smaller_kv_list |> List.to_seq |> Map.of_seq |> yield)
end
