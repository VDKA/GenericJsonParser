//
//  XCTestCaseExtensions.swift
//  GenericJsonParser
//
//  Created by Ethan Jackwitz on 7/3/16.
//
//

import XCTest

extension XCTestCase {

  func expect(_ input: String, toThrowWithReason expectedError: JSON.Error.Reason, file: StaticString = #file, line: UInt = #line) {

    let input = input.replacingOccurrences(of: "'", with: "\"")

    var data = Array(input.utf8)

    do {

      let val = try JSON.parse(&data, options: .allowFragments)

      XCTFail("expected to throw \(expectedError) but got \(val)", file: file, line: line)
    } catch let error as JSON.Error {

      XCTAssertEqual(error.reason, expectedError, file: file, line: line)
    } catch {

      XCTFail("expected to throw \(expectedError) but got a different error type!.")
    }
  }

  func expect(_ input: String, toThrow expectedError: JSON.Error, file: StaticString = #file, line: UInt = #line) {

    let input = input.replacingOccurrences(of: "'", with: "\"")

    var data = Array(input.utf8)

    do {

      let val = try JSON.parse(&data, options: .allowFragments)

      XCTFail("expected to throw \(expectedError) but got \(val)", file: file, line: line)
    } catch let error as JSON.Error {

      XCTAssertEqual(error, expectedError, file: file, line: line)
    } catch {

      XCTFail("expected to throw \(expectedError) but got a different error type!.")
    }
  }

  func expect(_ input: String, toParseTo expected: JSON, file: StaticString = #file, line: UInt = #line) {

    let input = input.replacingOccurrences(of: "'", with: "\"")

    var data = Array(input.utf8)

    do {
      let output = try JSON.parse(&data, options: .allowFragments)

      XCTAssertEqual(output, expected, file: file, line: line)
    } catch {
      XCTFail("\(error)", file: file, line: line)
    }
  }
}

