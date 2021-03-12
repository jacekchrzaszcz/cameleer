module type OrderedType = sig
  type t

  val[@logic] compare : t -> t -> int
  (*@ axiom is_pre_order: is_pre_order compare *)
end


module type S =
sig
  type elt
  type t

  val find: t -> elt -> bool
  val insert: t -> elt -> t
  val delete: t -> elt -> t
end


module BinTree (Ord: OrderedType) = struct
  type elt = Ord.t
  type t = Empty | Node of t * elt * t
  type t2 = Empty2 | Node2 of t2 * elt * t2 * int

  (*@ function occ (x: elt) (t: t) : int = match t with
        | Empty -> 0
        | Node l v r -> (if x = v then 1 else 0) + occ x l + occ x r*)
        
  (*@ function occ2 (x:elt) (t: t2) : int = match t with
        | Empty2 -> 0
        | Node2 l v r h -> (if x = v then 1 else 0) + occ2 x l + occ2 x r*)
        

  let [@lemma] rec occ_nonneg (x: elt) (t: t) =
    match t with
    | Empty -> ()
    | Node (l, _, r) -> occ_nonneg x l; occ_nonneg x r
  (*@ occ_nonneg x t
        ensures 0 <= occ x t *)

  (*@ predicate mem2 (x: elt) (t: t) = occ x t > 0 *)

  (*@ predicate binsearchtree (t: t) = match t with
        | Empty -> true
        | Node l v r ->
          (forall x. mem2 x l -> Ord.compare x v < 0) &&
          (forall y. mem2 y r -> Ord.compare y v > 0) &&
           binsearchtree l && binsearchtree r *)

  let [@lemma] rec occ_uniq2 (x: elt) (t: t)=
    match t with
    | Empty -> ()
    | Node (Empty, _,Empty) -> ()
    | Node (l, a, r) -> let z = Ord.compare x a in
        if z = 0 then assert (x=a)
        else occ_uniq2 x (if z < 0 then l else r)
  (*@ occ_uniq2 x t
        variant t
        requires binsearchtree t
        ensures  occ x t <= 1 *)
        
  (*let height = function
    Empty -> 0
    |Node{h} -> h*)

  let create l v r =
    (*let hl = match l with Empty -> 0 | Node {h} -> h in
      let hr = match r with Empty -> 0 | Node {h} -> h in*)
    (*Node{l; v; r; h=(if hl >= hr then hl + 1 else hr + 1)}*)
    Node (l,v,r)
  (*@ res = create l v r
      requires binsearchtree l
      requires binsearchtree r
      requires not (mem2 v l || mem2 v r)
      requires forall j:elt. (mem2 j l -> not mem2 j r) && (mem2 j r -> not mem2 j l)
      requires forall y: elt. mem2 y l -> Ord.compare y v < 0
      requires forall x: elt. mem2 x r -> Ord.compare x v > 0
      ensures binsearchtree res
      ensures forall z: elt. mem2 z l || mem2 z r || Ord.compare z v = 0 -> mem2 z res
      ensures forall w: elt. if w <> v then occ w res = occ w l + occ w r else mem2 v res*)
      
  (*let bal l v r = 
    let hl = match l with Empty -> 0 |Node {h} -> h in
    let hr = match r with Empty -> 0 |Node {h} -> h in
    if hl > hr +2 then begin 
      match l with
        Empty -> assert false
        |Node {l = ll; v = lv; r = lr} ->
          if height ll <= height lr then
            create ll lv (create lr v r)
          else begin
            match lr with
              Empty -> assert false
              |Node {l = lrl; v = lrv; r =lrr} ->
                create (create ll lv lrl) lrv (create lrr v r)
          end
    end  else if hr > hl +2 then begin 
      match r with
        Empty -> assert false
        |Node {l = rl; v = rv; r =rr} ->
          if height rr <= height rl then
            create (create l v rl) rv rr
          else begin
            match rl with
              Empty -> assert false 
              |Node {l = rll; v = rlv; r = rlr} ->
                create (create l v rll) rlv (create rlr rv rr)
          end
    end else
      Node {l;v;r; h=(if hl >= hr then hl +1 else hr + 1)}*)

  let rec mem x tree =
    match tree with
    | Node (l,a,r) -> let z = Ord.compare x a in
        z = 0 || mem x (if z < 0 then l else r)
    | Empty -> false
  (*@ r = find x t
        requires binsearchtree t
        variant  t
        ensures  r <-> mem2 x t *)

  let rec insert tree x =
    match tree with
    |Empty -> Node (Empty,x,Empty)
    |Node (l,y,r) as t-> let z = Ord.compare x y in
        if z < 0 then create (insert l x) y r else
        if z > 0 then create l y (insert r x)
        else t
  (*@r = insert t x
    requires binsearchtree t
    variant t
    ensures forall j: elt. j <> x -> occ j r = occ j t
    ensures occ x r = occ x t || occ x r = 1 + occ x t
    ensures binsearchtree r *)

  (*@ predicate is_minimum (x: elt) (tree: t) =
    mem2 x tree /\ forall e: elt. mem2 e tree -> Ord.compare x e < 0 \/ e = x *)

  (*@ predicate is_maximum (x:elt) (tree: t) =
    mem2 x tree /\ forall e: elt. mem2 e tree -> Ord.compare x e > 0 \/ e = x*)

  let [@logic] rec min_tree (tree: t) : elt =
    match tree with
    | Empty -> assert false
    | Node (Empty, a, _) -> a
    | Node (l, _, _) -> min_tree l
  (*@ r = min_tree t
    variant t
    requires t <> Empty && binsearchtree t
    ensures is_minimum r t*)

  let [@logic] rec max_tree (tree: t) : elt =
    match tree with
    | Empty -> assert false
    | Node (_, a, Empty) -> a
    | Node (_,_, r) -> max_tree r
  (*@ r = max_tree t
    variant t
    requires t <> Empty && binsearchtree t
    ensures is_maximum r t*)

  let [@lemma] rec is_minimum_min (t: t) =
    match t with
    |Empty -> assert false
    |Node (Empty, _, _) -> ()
    |Node (l, _, _) -> is_minimum_min l
  (*@ is_minimum_min t
    requires t <> Empty
    requires binsearchtree t
    variant t
    ensures is_minimum (min_tree t) t*)

  let [@lemma] rec is_maximum_max (t: t) =
    match t with
    |Empty -> assert false
    |Node (_, _, Empty) -> ()
    |Node (_, _, r) -> is_maximum_max r
  (*@ is_maximum_max t
    requires t <> Empty
    requires binsearchtree t
    variant t
    ensures is_maximum (max_tree t) t*)



  let rec remove_min_elt = function
      Empty -> assert false
    | Node (Empty, _ , r) -> r
    | Node(l, v, r) -> create (remove_min_elt l) v r
  (*@ r = remove_min_elt param
    variant param
    requires binsearchtree param
    requires param <> Empty
    ensures binsearchtree r
    ensures forall j: elt. Ord.compare j (min_tree param) <> 0 -> occ j param = occ j r
    ensures not mem2 (min_tree param) r*)

  let merge t1 t2 =
    match (t1, t2) with
      (Empty, t) -> t
    | (t, Empty) -> t
    | (_, _) -> create t1 (min_tree t2) (remove_min_elt t2)
  (*@ r = merge t1 t2
    requires binsearchtree t1 && binsearchtree t2
    requires forall j: elt. mem2 j t1 -> (forall y: elt. mem2 y t2 -> Ord.compare j y < 0)
    requires forall j:elt. (mem2 j t1 -> not mem2 j t2) && (mem2 j t2 -> not mem2 j t1)
    ensures forall j: elt. occ j t1 + occ j t2 = occ j r
    ensures binsearchtree r*)

  (*let rec find_min tree =
    match tree with
      | Empty -> assert false
      | Node (Empty, x, r) -> (x, r)
      | Node (l,a,b) -> let x,y = find_min l in (x, (Node (y,a, b)))
    (*@ (r, x) = find_min t
    variant t
    requires binsearchtree t
    requires t <> Empty
    ensures binsearchtree x
    ensures forall j: elt. j <> r -> occ j t = occ j x
    ensures occ r x = (occ r t) - 1
    ensures r = min_tree t*)*)

  let rec remove x = function
    | Empty -> Empty
    | Node (l,a,r) as t -> let z = Ord.compare x a in
        if z = 0 then merge l r else
        if z < 0 then let ll = remove x l in 
                      if l == ll then t else create ll a r else let rr = remove x r in
                      if r == rr then t else create l a rr
        (*@ r = remove x t
          requires binsearchtree t
          variant t
          ensures forall j: elt. (x<>j) -> occ j t = occ j r
          ensures occ x r = if (occ x t > 0) then ((occ x t) - 1) else occ x t
          ensures binsearchtree r*)


end
