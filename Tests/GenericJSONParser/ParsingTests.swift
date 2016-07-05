
import XCTest
@testable import GenericJsonParser

class ParsingTests: XCTestCase {

  func testPrepareForReading_FailOnEmpty() {

    expect("", toThrow: .emptyStream)
  }

  func testExtraTokensThrow() {

    expect("{'hello':'world'} blah", toThrow: .invalidSyntax)
  }

  func testNullParses() {

    expect("null", toParseTo: .null)
  }

  func testNullThrowsOnMismatch() {

    expect("nall", toThrow: .invalidLiteral)
  }

  func testTrueParses() {

    expect("true", toParseTo: .bool(true))
  }

  func testTrueThrowsOnMismatch() {

    expect("tRue", toThrow: .invalidLiteral)
  }

  func testFalseParses() {

    expect("false", toParseTo: .bool(false))
  }

  func testBoolean_False_Mismatch() {

    expect("fals ", toThrow: .invalidLiteral)
  }

  func testArray_NullsBoolsNums_Normal_Minimal_RootParser() {

    expect("[null,true,false,12,-10,-24.3,18.2e9]", toParseTo: .array([
      JSON.null,
      JSON.bool(true),
      JSON.bool(false),
      JSON.number(.integer(12)),
      JSON.number(.integer(-10)),
      JSON.number(.double(-24.3)),
      JSON.number(.double(18200000000))
    ]))
  }

  func testArray_NullsBoolsNums_Normal_MuchWhitespace() {

    expect(" \t[\n  null ,true, \n-12.3 , false\r\n]\n  ", toParseTo: .array([
      JSON.null,
      JSON.bool(true),
      JSON.number(.double(-12.3)),
      JSON.bool(false)
    ]))
  }

  func testArray_NullsAndBooleans_Bad_MissingEnd() {

    expect("[\n  null ,true, \nfalse\r\n\n  ", toThrow: .expectedComma)
  }

  func testArray_NullsAndBooleans_Bad_MissingComma() {

    expect("[\n  null true, \nfalse\r\n]\n  ", toThrow: .expectedComma)
  }

  func testArray_NullsAndBooleans_Bad_ExtraComma() {

    expect("[\n  null , , true, \nfalse\r\n]\n  ", toThrow: .invalidSyntax)
  }

  func testArray_NullsAndBooleans_Bad_TrailingComma() {

    expect("[\n  null ,true, \nfalse\r\n, ]\n  ", toThrow: .trailingComma)
  }

  func testNumber_Int_Zero() {

    expect("0 ", toParseTo: .number(.integer(0)))
  }

  func testNumber_Int_One() {

    expect("1", toParseTo: .number(.integer(1)))
  }

  func testNumber_Int_Basic() {

    expect("24", toParseTo: .number(.integer(24)))
  }

  func testNumber_IntMin() {

    expect(Int.min.description, toParseTo: .number(.integer(Int64.min)))
  }

  func testNumber_IntMax() {

    expect(Int.max.description, toParseTo: .number(.integer(Int64.max)))
  }

  func testNumber_Int_Negative() {

    expect("-32", toParseTo: .number(.integer(-32)))
  }

  func testNumber_Dbl_Basic() {

    expect("46.57", toParseTo: .number(.double(46.57)))
  }

  func testNumber_Dbl_ZeroSomething() {

    expect("0.98", toParseTo: .number(.double(0.98)))
  }

  func testNumber_Dbl_MinusZeroSomething() {

    expect("-0.98", toParseTo: .number(.double(-0.98)))
  }

  func testNumber_Dbl_ThrowsOnMinus() {

    expect("-", toThrow: .invalidNumber)
  }

  func testNumber_Dbl_Incomplete() {

    expect("24.", toThrow: .invalidNumber)
  }

  func testNumber_Dbl_Negative() {

    expect("-24.34", toParseTo: .number(.double(-24.34)))
  }

  func testNumber_Dbl_Negative_WrongChar() {

    expect("-24.3a4", toThrow: .invalidNumber)
  }

  func testNumber_Dbl_Negative_TwoDecimalPoints() {

    expect("-24.3.4", toThrow: .invalidNumber)
  }

  func testNumber_Dbl_Negative_TwoMinuses() {

    expect("--24.34", toThrow: .invalidNumber)
  }

  func testNumber_Double_Exp_Normal() {

    expect("-24.3245e2", toParseTo: .number(.double(-2432.45)))
  }

  func testNumber_Double_Exp_Positive() {

    expect("-24.3245e+2", toParseTo: .number(.double(-2432.45)))
  }

  // TODO (vdka): floating point accuracy
  func testNumber_Double_Exp_Negative() {

    expect("-24.3245e-2", toParseTo: .number(.double(-0.243245)))
  }

  func testNumber_Double_Exp_NoFrac() {

    expect("24E2", toParseTo: .number(.double(2400)))
  }

  func testNumber_Double_Exp_TwoEs() {

    expect("-24.3245eE2", toThrow: .invalidNumber)
  }

  func testEscape_Unicode_Normal() {

    expect("'\\u0048'", toParseTo: .string("H"))
  }

  func testEscape_Unicode_InvalidUnicode_MissingDigit() {

    expect("'\\u048'", toThrow: .invalidEscape)
  }

  func testEscape_Unicode_InvalidUnicode_MissingAllDigits() {

    expect("'\\u'", toThrow: .invalidEscape)
  }

  func testString_Empty() {

    expect("''", toParseTo: .string(""))
  }

  func testString_Normal() {

    expect("'hello world'", toParseTo: .string("hello world"))
  }

  func testString_Normal_WhitespaceInside() {

    expect("'he \\r\\n l \\t l \\n o wo\\rrld ' ", toParseTo: .string("he \r\n l \t l \n o wo\rrld "))
  }

  func testString_StartEndWithSpaces() {

    expect("'  hello world  '", toParseTo: .string("  hello world  "))
  }

  func testString_Unicode_RegularChar() {

    expect("'hel\\u006co world'", toParseTo: .string("hello world"))
  }

  func testString_Unicode_SpecialCharacter_CoolA() {

    expect("'h\\u01cdw'", toParseTo: .string("hǍw"))
  }

  func testString_Unicode_SpecialCharacter_HebrewShin() {

    expect("'h\\u05e9w'", toParseTo: .string("hשw"))
  }

  func testString_Unicode_SpecialCharacter_QuarterTo() {

    expect("'h\\u25d5w'", toParseTo: .string("h◕w"))
  }

  func testString_Unicode_SpecialCharacter_EmojiSimple() {

    expect("'h\\ud83d\\ude3bw'", toParseTo: .string("h😻w"))
  }

  func testString_Unicode_SpecialCharacter_EmojiComplex() {

    expect("'h\\ud83c\\udde8\\ud83c\\uddffw'", toParseTo: .string("h🇨🇿w"))
  }

  func testString_SpecialCharacter_QuarterTo() {

    expect("'h◕w'", toParseTo: .string("h◕w"))
  }

  func testString_SpecialCharacter_EmojiSimple() {

    expect("'h😻w'", toParseTo: .string("h😻w"))
  }

  func testString_SpecialCharacter_EmojiComplex() {

    expect("'h🇨🇿w'", toParseTo: .string("h🇨🇿w"))
  }

  func testObject_Empty() {

    expect("{}", toParseTo: .object([]))
  }

  func testObject_Example1() {
    expect("{\t'hello': 'wor🇨🇿ld', \n\t 'val': 1234, 'many': [\n-12.32, null, 'yo'\r], 'emptyDict': {}, 'dict': {'arr':[]}, 'name': true}", toParseTo:
      .object([
        ("hello", .string("wor🇨🇿ld")),
        ("val", .number(.integer(1234))),
        ("many", .array([.number(.double(-12.32)), .null, .string("yo")])),
        ("emptyDict", .object([])),
        ("dict", .object([("arr", .array([]))])),
        ("name", .bool(true))
      ])
    )
  }
}

#if os(Linux)
  extension ParsingTests {
    static var allTests : [(String, (ParsingTests) -> () throws -> Void)] {
      return [
        ("testPrepareForReading_FailOnEmpty", testPrepareForReading_FailOnEmpty),
        ("testExtraTokensThrow", testExtraTokensThrow),
        ("testNullParses", testNullParses),
        ("testNullThrowsOnMismatch", testNullThrowsOnMismatch),
        ("testTrueParses", testTrueParses),
        ("testTrueThrowsOnMismatch", testTrueThrowsOnMismatch),
        ("testFalseParses", testFalseParses),
        ("testBoolean_False_Mismatch", testBoolean_False_Mismatch),
        ("testArray_NullsBoolsNums_Normal_Minimal_RootParser", testArray_NullsBoolsNums_Normal_Minimal_RootParser),
        ("testArray_NullsBoolsNums_Normal_MuchWhitespace", testArray_NullsBoolsNums_Normal_MuchWhitespace),
        ("testArray_NullsAndBooleans_Bad_MissingEnd", testArray_NullsAndBooleans_Bad_MissingEnd),
        ("testArray_NullsAndBooleans_Bad_MissingComma", testArray_NullsAndBooleans_Bad_MissingComma),
        ("testArray_NullsAndBooleans_Bad_ExtraComma", testArray_NullsAndBooleans_Bad_ExtraComma),
        ("testArray_NullsAndBooleans_Bad_TrailingComma", testArray_NullsAndBooleans_Bad_TrailingComma),
        ("testNumber_Int_Zero", testNumber_Int_Zero),
        ("testNumber_Int_One", testNumber_Int_One),
        ("testNumber_Int_Basic", testNumber_Int_Basic),
        ("testNumber_Int_Negative", testNumber_Int_Negative),
        ("testNumber_Dbl_Basic", testNumber_Dbl_Basic),
        ("testNumber_Dbl_ZeroSomething", testNumber_Dbl_ZeroSomething),
        ("testNumber_Dbl_MinusZeroSomething", testNumber_Dbl_MinusZeroSomething),
        ("testNumber_Dbl_Incomplete", testNumber_Dbl_Incomplete),
        ("testNumber_Dbl_Negative", testNumber_Dbl_Negative),
        ("testNumber_Dbl_Negative_WrongChar", testNumber_Dbl_Negative_WrongChar),
        ("testNumber_Dbl_Negative_TwoDecimalPoints", testNumber_Dbl_Negative_TwoDecimalPoints),
        ("testNumber_Dbl_Negative_TwoMinuses", testNumber_Dbl_Negative_TwoMinuses),
        ("testNumber_Double_Exp_Normal", testNumber_Double_Exp_Normal),
        ("testNumber_Double_Exp_Positive", testNumber_Double_Exp_Positive),
        ("testNumber_Double_Exp_Negative", testNumber_Double_Exp_Negative),
        ("testNumber_Double_Exp_NoFrac", testNumber_Double_Exp_NoFrac),
        ("testNumber_Double_Exp_TwoEs", testNumber_Double_Exp_TwoEs),
        ("testEscape_Unicode_Normal", testEscape_Unicode_Normal),
        ("testEscape_Unicode_InvalidUnicode_MissingDigit", testEscape_Unicode_InvalidUnicode_MissingDigit),
        ("testEscape_Unicode_InvalidUnicode_MissingAllDigits", testEscape_Unicode_InvalidUnicode_MissingAllDigits),
        ("testString_Empty", testString_Empty),
        ("testString_Normal", testString_Normal),
        ("testString_Normal_WhitespaceInside", testString_Normal_WhitespaceInside),
        ("testString_StartEndWithSpaces", testString_StartEndWithSpaces),
        ("testString_Unicode_RegularChar", testString_Unicode_RegularChar),
        ("testString_Unicode_SpecialCharacter_CoolA", testString_Unicode_SpecialCharacter_CoolA),
        ("testString_Unicode_SpecialCharacter_HebrewShin", testString_Unicode_SpecialCharacter_HebrewShin),
        ("testString_Unicode_SpecialCharacter_QuarterTo", testString_Unicode_SpecialCharacter_QuarterTo),
        ("testString_Unicode_SpecialCharacter_EmojiSimple", testString_Unicode_SpecialCharacter_EmojiSimple),
        ("testString_Unicode_SpecialCharacter_EmojiComplex", testString_Unicode_SpecialCharacter_EmojiComplex),
        ("testString_SpecialCharacter_QuarterTo", testString_SpecialCharacter_QuarterTo),
        ("testString_SpecialCharacter_EmojiSimple", testString_SpecialCharacter_EmojiSimple),
        ("testString_SpecialCharacter_EmojiComplex", testString_SpecialCharacter_EmojiComplex),
        ("testObject_Empty", testObject_Empty),
        ("testObject_Example1", testObject_Example1),
      ]
    }
  }
#endif

