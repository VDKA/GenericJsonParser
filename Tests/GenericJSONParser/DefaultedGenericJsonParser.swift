//
//  DefaultedGenericJsonParser.swift
//  GenericJsonParser
//
//  Created by Ethan Jackwitz on 7/4/16.
//
//

import GenericJsonParser

// Used for testing only.
enum JSON {

  case null
  case bool(Bool)
  case string(String)
  case array([JSON])
  case object([(String, JSON)])
  case number(GenericJsonParser.Number)
}

func onObject(_ input: [(String, JSON)]) -> JSON { return .object(input) }
func onArray(_ input: [JSON]) -> JSON { return .array(input) }
func onNull() -> JSON { return .null }
func onBool(_ input: Bool) -> JSON { return .bool(input) }
func onString(_ input: String) -> JSON { return .string(input) }
func onNumber(_ input: JSON.Number) -> JSON { return .number(input) }

extension JSON: Equatable {}

func == (lhs: JSON, rhs: JSON) -> Bool {

  switch (lhs, rhs) {
  case (.null, .null): return true
  case let (.bool(l), .bool(r)): return l == r
  case let (.string(l), .string(r)): return l == r
  case let (.number(l), .number(r)): return l == r

  case let (.array(l), .array(r)): return l == r
  case let (.object(l), .object(r)):
    for pair in zip(l, r) {
      guard pair.0 == pair.1 else { return false }
    }
    return true
  default: return false
  }
}

extension JSON {

  typealias Error = GenericJsonParser.Error
  typealias Number = GenericJsonParser.Number
  typealias Option = GenericJsonParser.Option

  static func parse(_ data: inout [UInt8], options: Option = []) throws -> JSON  {

    return try GenericJsonParser.parse(data: &data, options: options, onObject: onObject, onArray: onArray, onNull: onNull, onBool: onBool, onString: onString, onNumber: onNumber)
  }
}
