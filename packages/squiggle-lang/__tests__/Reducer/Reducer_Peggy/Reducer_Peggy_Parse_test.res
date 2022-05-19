module Parse = Reducer_Peggy_Parse
module Result = Belt.Result

open Jest
open Expect

let expectParseToBe = (expr, answer) =>
  Parse.parse(expr)->Parse.toStringResult->expect->toBe(answer)

let testParse = (expr, answer) => test(expr, () => expectParseToBe(expr, answer))

module MySkip = {
  let testParse = (expr, answer) => Skip.test(expr, () => expectParseToBe(expr, answer))

  let testDescriptionParse = (desc, expr, answer) =>
    Skip.test(desc, () => expectParseToBe(expr, answer))
}

module MyOnly = {
  let testParse = (expr, answer) => Only.test(expr, () => expectParseToBe(expr, answer))
  let testDescriptionParse = (desc, expr, answer) =>
    Only.test(desc, () => expectParseToBe(expr, answer))
}

describe("Peggy parse", () => {
  describe("literals operators parenthesis", () => {
    // Note that there is always an outer block. Otherwise, external bindings are ignrored at the first statement
    testParse("1", "{1}")
    testParse("'hello'", "{'hello'}")
    testParse("true", "{true}")
    testParse("1+2", "{(::add 1 2)}")
    testParse("add(1,2)", "{(::add 1 2)}")
    testParse("(1)", "{1}")
    testParse("(1+2)", "{(::add 1 2)}")
  })

  describe("unary", () => {
    testParse("-1", "{(::unaryMinus 1)}")
    testParse("!true", "{(::not true)}")
    testParse("1 + -1", "{(::add 1 (::unaryMinus 1))}")
    testParse("-a[0]", "{(::unaryMinus (::$atIndex :a 0))}")
  })

  describe("multi-line", () => {
    testParse("x=1; 2", "{:x = {1}; 2}")
    testParse("x=1; y=2", "{:x = {1}; :y = {2}}")
  })

  describe("variables", () => {
    testParse("x = 1", "{:x = {1}}")
    testParse("x", "{:x}")
    testParse("x = 1; x", "{:x = {1}; :x}")
  })

  describe("functions", () => {
    testParse("identity(x) = x", "{:identity = {|:x| {:x}}}") // Function definitions become lambda assignments
    testParse("identity(x)", "{(::identity :x)}")
  })

  describe("arrays", () => {
    testParse("[]", "{(::$constructArray ())}")
    testParse("[0, 1, 2]", "{(::$constructArray (0 1 2))}")
    testParse("['hello', 'world']", "{(::$constructArray ('hello' 'world'))}")
    testParse("([0,1,2])[1]", "{(::$atIndex (::$constructArray (0 1 2)) 1)}")
  })

  describe("records", () => {
    testParse("{a: 1, b: 2}", "{(::$constructRecord ('a': 1 'b': 2))}")
    testParse("{1+0: 1, 2+0: 2}", "{(::$constructRecord ((::add 1 0): 1 (::add 2 0): 2))}") // key can be any expression
    testParse("record.property", "{(::$atIndex :record 'property')}")
  })

  describe("comments", () => {
    testParse("1 # This is a line comment", "{1}")
    testParse("1 // This is a line comment", "{1}")
    testParse("1 /* This is a multi line comment */", "{1}")
    testParse("/* This is a multi line comment */ 1", "{1}")
  })

  describe("ternary operator", () => {
    testParse("true ? 2 : 3", "{(::$$ternary true 2 3)}")
    testParse("false ? 2 : false ? 4 : 5", "{(::$$ternary false 2 (::$$ternary false 4 5))}") // nested ternary
  })

  describe("if then else", () => {
    testParse("if true then 2 else 3", "{(::$$ternary true {2} {3})}")
    testParse("if false then {2} else {3}", "{(::$$ternary false {2} {3})}")
    testParse(
      "if false then {2} else if false then {4} else {5}",
      "{(::$$ternary false {2} (::$$ternary false {4} {5}))}",
    ) //nested if
  })

  describe("pipe", () => {
    testParse("1 -> add(2)", "{(::add 1 2)}")
    testParse("-1 -> add(2)", "{(::add (::unaryMinus 1) 2)}")
    testParse("1 -> add(2) * 3", "{(::multiply (::add 1 2) 3)}")
    testParse("1 -> subtract(2)", "{(::subtract 1 2)}")
    testParse("-1 -> subtract(2)", "{(::subtract (::unaryMinus 1) 2)}")
    testParse("1 -> subtract(2) * 3", "{(::multiply (::subtract 1 2) 3)}")
  })

  describe("elixir pipe", () => {
    testParse("1 |> add(2)", "{(::add 1 2)}")
  })

  describe("to", () => {
    testParse("1 to 2", "{(::credibleIntervalToDistribution 1 2)}")
    testParse("-1 to -2", "{(::credibleIntervalToDistribution (::unaryMinus 1) (::unaryMinus 2))}") // lower than unary
    testParse(
      "a[1] to a[2]",
      "{(::credibleIntervalToDistribution (::$atIndex :a 1) (::$atIndex :a 2))}",
    ) // lower than post
    testParse(
      "a.p1 to a.p2",
      "{(::credibleIntervalToDistribution (::$atIndex :a 'p1') (::$atIndex :a 'p2'))}",
    ) // lower than post
    testParse("1 to 2 + 3", "{(::add (::credibleIntervalToDistribution 1 2) 3)}") // higher than binary operators
    testParse(
      "1->add(2) to 3->add(4) -> add(4)",
      "{(::credibleIntervalToDistribution (::add 1 2) (::add (::add 3 4) 4))}",
    ) // lower than chain
  })

  describe("inner block", () => {
    // inner blocks are 0 argument lambdas. They can be used whenever a value is required.
    // Like lambdas they have a local scope.
    testParse("x={y=1; y}; x", "{:x = {:y = {1}; :y}; :x}")
  })

  describe("lambda", () => {
    testParse("{|x| x}", "{{|:x| {:x}}}")
    testParse("f={|x| x}", "{:f = {{|:x| {:x}}}}")
    testParse("f(x)=x", "{:f = {|:x| {:x}}}") // Function definitions are lambda assignments
    testParse("f(x)=x ? 1 : 0", "{:f = {|:x| {(::$$ternary :x 1 0)}}}") // Function definitions are lambda assignments
  })

  describe("Using lambda as value", () => {
    testParse("myadd(x,y)=x+y; z=myadd; z", "{:myadd = {|:x,:y| {(::add :x :y)}}; :z = {:myadd}; :z}")
    testParse("myadd(x,y)=x+y; z=[myadd]; z", "{:myadd = {|:x,:y| {(::add :x :y)}}; :z = {(::$constructArray (:myadd))}; :z}")
    testParse("myaddd(x,y)=x+y; z={x: myaddd}; z", "{:myaddd = {|:x,:y| {(::add :x :y)}}; :z = {(::$constructRecord ('x': :myaddd))}; :z}")
  })
})


