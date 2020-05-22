(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2020 Nomadic Labs <contact@nomadic-labs.com>                *)
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

(** Modules with the signature [S] are safe (e.g., [find] uses [option] rather
    than raising [Not_found]) extensions of [Hashtbl.S] with some Lwt- and
    Error-aware traversal functions. *)
module type S = sig
  type error

  type key

  type 'a t

  val create : int -> 'a t

  val clear : 'a t -> unit

  val reset : 'a t -> unit

  val add : 'a t -> key -> 'a -> unit

  val remove : 'a t -> key -> unit

  val find : 'a t -> key -> 'a option

  val find_all : 'a t -> key -> 'a list

  val replace : 'a t -> key -> 'a -> unit

  val mem : 'a t -> key -> bool

  val iter : (key -> 'a -> unit) -> 'a t -> unit

  val iter_s : (key -> 'a -> unit Lwt.t) -> 'a t -> unit Lwt.t

  val iter_p : (key -> 'a -> unit Lwt.t) -> 'a t -> unit Lwt.t

  val iter_e :
    (key -> 'a -> (unit, error) result) -> 'a t -> (unit, error) result

  val iter_es :
    (key -> 'a -> (unit, error) result Lwt.t) ->
    'a t ->
    (unit, error) result Lwt.t

  val iter_ep :
    (key -> 'a -> (unit, error) result Lwt.t) ->
    'a t ->
    (unit, error) result Lwt.t

  val filter_map_inplace : (key -> 'a -> 'a option) -> 'a t -> unit

  val try_map_inplace : (key -> 'a -> ('a, error) result) -> 'a t -> unit

  val fold : (key -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b

  val fold_s : (key -> 'a -> 'b -> 'b Lwt.t) -> 'a t -> 'b -> 'b Lwt.t

  val fold_e :
    (key -> 'a -> 'b -> ('b, error) result) -> 'a t -> 'b -> ('b, error) result

  val fold_es :
    (key -> 'a -> 'b -> ('b, error) result Lwt.t) ->
    'a t ->
    'b ->
    ('b, error) result Lwt.t

  val length : 'a t -> int

  val stats : 'a t -> Stdlib.Hashtbl.statistics

  val to_seq : 'a t -> (key * 'a) Stdlib.Seq.t

  val to_seq_keys : _ t -> key Stdlib.Seq.t

  val to_seq_values : 'a t -> 'a Stdlib.Seq.t

  val add_seq : 'a t -> (key * 'a) Stdlib.Seq.t -> unit

  val replace_seq : 'a t -> (key * 'a) Stdlib.Seq.t -> unit

  val of_seq : (key * 'a) Stdlib.Seq.t -> 'a t
end

(** Modules with the signature [S_LWT] are Hashtbl-like with the following
    differences:

    First, the module exports only a few functions in an attempt to limit the
    likelihood of race-conditions. Of particular interest is the following: in
    order to insert a value, one has to use `find_or_make` which either returns
    an existing promise for a value bound to the given key, or makes such a
    promise. It is not possible to insert another value for an existing key.

    Second, the table is automatically cleaned. Specifically, when a promise for
    a value is fulfilled with an [Error _], the binding is removed. This leads
    to the following behavior:

    [
    (* setup *)
    let t = create 256 in
    let () = assert (fold_keys (fun _ acc -> succ acc) t 0 = 0) in

    (* insert a first promise for a value *)
    let p, r = Lwt.task () in
    let i1 = find_or_make t 1 (fun () -> p) in
    let () = assert (fold_keys (fun _ acc -> succ acc) t 0 = 1) in

    (* because the same key is used, the promise is not inserted. *)
    let i2 = find_or_make t 1 (fun () -> assert false) in
    let () = assert (fold_keys (fun _ acc -> succ acc) t 0 = 1) in

    (* when the original promise errors, the binding is removed *)
    let () = Lwt.wakeup r (Error ..) in
    let () = assert (fold_keys (fun _ acc -> succ acc) t 0 = 0) in

    (* and both the [find_or_make] promises have the error *)
    let () = match Lwt.state i1 with
      | Return (Error ..) -> ()
      | _ -> assert false
    in
    let () = match Lwt.state i2 with
      | Return (Error ..) -> ()
      | _ -> assert false
    in
    ]

    This automatic cleaning relieves the user from the responsibility of
    cleaning the table (which is another possible source of race condition).

    Third, every time a promise is removed from the table (be it by [clean],
    [reset], or just [remove]), the promise is canceled.
*)
module type S_LWT = sig
  type error

  type key

  type 'a t

  val create : int -> 'a t

  val clear : 'a t -> unit

  val reset : 'a t -> unit

  val find_or_make :
    'a t ->
    key ->
    (unit -> ('a, error) result Lwt.t) ->
    ('a, error) result Lwt.t

  val remove : 'a t -> key -> unit

  val find : 'a t -> key -> ('a, error) result Lwt.t option

  val mem : 'a t -> key -> bool

  val iter_es :
    (key -> 'a -> (unit, error) result Lwt.t) ->
    'a t ->
    (unit, error) result Lwt.t

  val iter_ep :
    (key -> 'a -> (unit, error) result Lwt.t) ->
    'a t ->
    (unit, error) result Lwt.t

  val fold_es :
    (key -> 'a -> 'b -> ('b, error) result Lwt.t) ->
    'a t ->
    'b ->
    ('b, error) result Lwt.t

  val fold_keys : (key -> 'b -> 'b) -> 'a t -> 'b -> 'b

  val fold_promises :
    (key -> ('a, error) result Lwt.t -> 'b -> 'b) -> 'a t -> 'b -> 'b

  val fold_resolved : (key -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b

  val length : 'a t -> int

  val stats : 'a t -> Stdlib.Hashtbl.statistics
end