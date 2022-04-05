module Parse = Reducer.MathJs.Parse
module Result = Belt.Result

open Jest
open Expect

let expectParseToBe = (expr, answer) =>
  Parse.parse(expr)->Result.flatMap(Parse.castNodeType)->Parse.toStringResult->expect->toBe(answer)

let testParse = (expr, answer) =>
  test(expr, () => expectParseToBe(expr, answer))

let testDescParse = (desc, expr, answer) =>
  test(desc, () => expectParseToBe(expr, answer))

let skipTestParse = (expr, answer) =>
    Skip.test(expr, () => expectParseToBe(expr, answer))

let skipDescTestParse = (desc, expr, answer) =>
    Skip.test(desc, () => expectParseToBe(expr, answer))

describe("MathJs parse", () => {
  describe("literals operators paranthesis", () => {
    testParse("1", "1")
    testParse("'hello'", "'hello'")
    testParse("true", "true")
    testParse("1+2", "add(1, 2)")
    testParse("add(1,2)", "add(1, 2)")
    testParse("(1)", "(1)")
    testParse("(1+2)", "(add(1, 2))")
  })

  describe("variables", () => {
    skipTestParse("x = 1", "???")
    skipTestParse("x", "???")
  })

  describe("functions", () => {
    skipTestParse("identity(x) = x", "???")
    skipTestParse("identity(x)", "???")
  })

  describe("arrays", () => {
    test("empty", () => expectParseToBe("[]", "[]"))
    test("define", () => expectParseToBe("[0, 1, 2]", "[0, 1, 2]"))
    test("define with strings", () => expectParseToBe("['hello', 'world']", "['hello', 'world']"))
    skipTestParse("range(0, 4)", "range(0, 4)")
    test("index", () => expectParseToBe("([0,1,2])[1]", "([0, 1, 2])[1]"))
  })

  describe("records", () => {
    testDescParse("define", "{a: 1, b: 2}", "{a: 1, b: 2}")
    testDescParse("use", "record.property", "record['property']")
  })

  describe("comments", () => {
    skipDescTestParse("define", "# This is a comment", "???")
  })

  describe("if statement", () => {
    skipDescTestParse("define", "if (true) { 1 } else { 0 }", "???")
  })
})
