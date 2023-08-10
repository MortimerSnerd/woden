import rects
import testing

run_test("vert splits"):
   let r = recti{xy_i{5, 10}, xy_i{4, 4}}
   for(r.extent.x) i:
      let x = r.top_left.x + i
      let ra = r.area
      let rl = r.split_left(x)
      let rr = r.split_right(x)

      print("vert {rl}      {rr}")
      assert ra == (rl.area + rr.area)

run_test("horiz splits"):
   let r = recti{xy_i{5, 10}, xy_i{4, 4}}
   for(r.extent.y) i:
      let y = r.top_left.y + i
      let ra = r.area
      let rt = r.split_top(y)
      let rb = r.split_bottom(y)

      print("horiz {rt}      {rb}")
      assert ra == (rt.area + rb.area)

run_test("center"):
   let ri = recti{xy_i{1, 5}, xy_i{4, 4}}

   assert ri.center == xy_i{3, 7}

   let rf = rectf{xy_f{1.0, 5.0}, xy_f{4.0, 4.0}}
   assert rf.center == xy_f{3.0, 7.0}

run_test("contains"):
   let r = recti{xy_i{5, 5}, xy_i{3, 2}}

   assert not r.contains(xy_i{4,5})
   assert r.contains(xy_i{5,5})
   assert r.contains(xy_i{7,5})
   assert not r.contains(xy_i{8,5})

   assert r.contains(xy_i{5,6})
   assert not r.contains(xy_i{5,7})
