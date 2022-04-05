open Jest
open Reducer_TestHelpers

let testParseToBe = (expr, answer) =>
  test(expr, () => expectParseToBe(expr, answer))

let testEvalToBe = (expr, answer) =>
    test(expr, () => expectEvalToBe(expr, answer))

describe("reducer using mathjs parse", () => {
  // Test the MathJs parser compatibility
  // Those tests toString that there is a semantic mapping from MathJs to Expression
  // Reducer.parse is called by Reducer.eval
  // See https://mathjs.org/docs/expressions/syntax.html
  // See https://mathjs.org/docs/reference/functions.html
  // Those tests toString that we are converting mathjs parse tree to what we need

  describe("expressions", () => {
    testParseToBe("1", "Ok(1)")
    testParseToBe("(1)", "Ok(1)")
    testParseToBe("1+2", "Ok((:add 1 2))")
    testParseToBe("1+2", "Ok((:add 1 2))")
    testParseToBe("1+2", "Ok((:add 1 2))")
    testParseToBe("1+2*3", "Ok((:add 1 (:multiply 2 3)))")
  })
  describe("arrays", () => {
    //Note. () is a empty list in Lisp
    //  The only builtin structure in Lisp is list. There are no arrays
    //  [1,2,3] becomes (1 2 3)
    test("empty", () => expectParseToBe("[]", "Ok(())"))
    testParseToBe("[1, 2, 3]", "Ok((1 2 3))")
    testParseToBe("['hello', 'world']", "Ok(('hello' 'world'))")
    test("index", () => expectParseToBe("([0,1,2])[1]", "Ok((:$atIndex (0 1 2) (1)))"))
  })
  describe("records", () => {
    test("define", () =>
      expectParseToBe("{a: 1, b: 2}", "Ok((:$constructRecord (('a' 1) ('b' 2))))")
    )
    test("use", () =>
      expectParseToBe(
        "{a: 1, b: 2}.a",
        "Ok((:$atIndex (:$constructRecord (('a' 1) ('b' 2))) ('a')))",
      )
    )
  })
})

describe("eval", () => {
  // All MathJs operators and functions are builtin for string, float and boolean
  // .e.g + - / * > >= < <= == /= not and or
  // See https://mathjs.org/docs/expressions/syntax.html
  // See https://mathjs.org/docs/reference/functions.html
  describe("expressions", () => {
    testEvalToBe("1", "Ok(1)")
    testEvalToBe("1+2", "Ok(3)")
    testEvalToBe("(1+2)*3", "Ok(9)")
    testEvalToBe("2>1", "Ok(true)")
    testEvalToBe("concat('a ', 'b')", "Ok('a b')")
    testEvalToBe("log(10)", "Ok(2.302585092994046)")
    testEvalToBe("cos(10)", "Ok(-0.8390715290764524)")
    // TODO more built ins
  })
  describe("arrays", () => {
    test("empty array", () => expectEvalToBe("[]", "Ok([])"))
    testEvalToBe("[1, 2, 3]", "Ok([1, 2, 3])")
    testEvalToBe("['hello', 'world']", "Ok(['hello', 'world'])")
    testEvalToBe("([0,1,2])[1]", "Ok(1)")
    test("index not found", () =>
      expectEvalToBe("([0,1,2])[10]", "Error(Array index not found: 10)")
    )
  })
  describe("records", () => {
    test("define", () => expectEvalToBe("{a: 1, b: 2}", "Ok({a: 1, b: 2})"))
    test("index", () => expectEvalToBe("{a: 1}.a", "Ok(1)"))
    test("index not found", () => expectEvalToBe("{a: 1}.b", "Error(Record property not found: b)"))
  })
})

describe("test exceptions", () => {
  test("javascript exception", () =>
    expectEvalToBe("jsraise('div by 0')", "Error(JS Exception: Error: 'div by 0')")
  )

  test("rescript exception", () =>
    expectEvalToBe("resraise()", "Error(TODO: unhandled rescript exception)")
  )
})
