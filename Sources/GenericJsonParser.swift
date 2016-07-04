
public struct GenericJsonParser {

  public struct Option: OptionSet {

    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public let rawValue: UInt8

    public static let skipNull = Option(rawValue: 0b0001)
  }

  public enum Error: ErrorProtocol {

    case endOfStream
    case trailingComma
    case expectedComma
    case expectedColon
    case invalidEscape
    case invalidSyntax
    case invalidNumber
    case numberOverflow
    case invalidLiteral
    case invalidUnicode
  }

  public enum Number {

    case double(Double)
    case integer(Int64)
  }
}

extension UTF8.CodeUnit {

  var isWhitespace: Bool {
    if self == space || self == tab || self == cr || self == newline || self == formfeed {
      return true
    } else {
      return false
    }
  }
}

extension UnsafeMutableBufferPointer {

  var endAddress: UnsafeMutablePointer<Element>? {

    return baseAddress?.advanced(by: endIndex)
  }
}

extension GenericJsonParser.Number: Equatable {}

public func == (lhs: GenericJsonParser.Number, rhs: GenericJsonParser.Number) -> Bool {
  switch (lhs, rhs) {
  case let (.integer(l), .integer(r)): return l == r
  case let (.double(l), .double(r)): return l == r
  default: return false
  }
}

extension GenericJsonParser {

  public static func parse<T>(
    data: inout [UInt8], options: Option = [],
    onObject: ([(String, T)]) -> T,
    onArray: ([T]) -> T,
    onNull: () -> T,
    onBool: (Bool) -> T,
    onString: (String) -> T,
    onNumber: (Number) -> T
  ) throws -> T  {

    return try data.withUnsafeMutableBufferPointer {

      var parser = Core(buffer: $0, options: options, onObject, onArray, onNull, onBool, onString, onNumber)
      parser.skipWhitespace()
      
      let rootValue = try parser.parseValue()

      parser.skipWhitespace()

      guard parser.pointer == parser.bufferPointer.endAddress else {
        throw Error.invalidSyntax
      }

      return rootValue
    }
  }
}


// MARK: - Internals

internal struct Core<T> {

  typealias Error = GenericJsonParser.Error
  typealias Option = GenericJsonParser.Option
  typealias Number = GenericJsonParser.Number

  let skipNull: Bool

  var pointer: UnsafeMutablePointer<UTF8.CodeUnit>
  var bufferPointer: UnsafeMutableBufferPointer<UTF8.CodeUnit>

  var stringBuffer: [UTF8.CodeUnit] = []

  let onObject: ([(String, T)]) -> T
  let onArray: ([T]) -> T
  let onNull: () -> T
  let onBool: (Bool) -> T
  let onString: (String) -> T
  let onNumber: (Number) -> T

  init(
      buffer: UnsafeMutableBufferPointer<UTF8.CodeUnit>,
      options: Option,
    _ onObject: ([(String, T)]) -> T,
    _ onArray: ([T]) -> T,
    _ onNull: () -> T,
    _ onBool: (Bool) -> T,
    _ onString: (String) -> T,
    _ onNumber: (Number) -> T
  ) {

    self.bufferPointer = buffer
    self.pointer = buffer.baseAddress!

    self.skipNull = options.contains(.skipNull)

    self.onObject = onObject
    self.onArray = onArray
    self.onNull = onNull
    self.onBool = onBool
    self.onString = onString
    self.onNumber = onNumber
  }
}

extension Core {

  /**
   - precondition: `pointer` is at the beginning of a literal
   - postcondition: `pointer` will be in the next non-`whiteSpace` position
   */
  mutating func parseValue() throws -> T {

    assert(!pointer.pointee.isWhitespace && pointer.pointee != 0)

    defer { skipWhitespace() }
    switch peek() {
    case objectOpen:

      let object = try parseObject()
      return onObject(object)

    case arrayOpen:

      let a = try parseArray()
      return onArray(a)

    case quote:

      let string = try parseString()
      return onString(string)

    case minus, numbers:

      let number = try parseNumber()
      return onNumber(number)

    case f:

      unsafePop()
      try assertFollowedBy(alse)
      return onBool(false)

    case t:

      unsafePop()
      try assertFollowedBy(rue)
      return onBool(true)

    case n:

      unsafePop()
      try assertFollowedBy(ull)
      return onNull()

    default:
      throw Error.invalidSyntax
    }
  }

  mutating func assertFollowedBy(_ chars: [UTF8.CodeUnit]) throws {

    for scalar in chars {
      guard try scalar == pop() else { throw Error.invalidLiteral }
    }
  }

  mutating func parseObject() throws -> [(String, T)] {

    assert(peek() == objectOpen)
    unsafePop()

    skipWhitespace()

    guard peek() != objectClose else {
      unsafePop()
      return []
    }


    // FIXME (vdka): Currently skips comma's regardless. ie: "{'harry': 'potter', , null}" & "{'harry': 'potter' null}" would incorrectly parse
    var tempDict: [(String, T)] = []
    tempDict.reserveCapacity(6)

    var wasNull = false

    repeat {
      switch peek() {
      case quote:

        let key = try parseString()
        try skipColon()
        let value = try parseValue()
        
        switch skipNull {
        case true where wasNull:
          wasNull = false

        default:
          tempDict.append( (key, value) )
        }

      case comma:

        unsafePop()
        skipWhitespace()

      case objectClose:

        unsafePop()
        return tempDict

      default:
        throw Error.invalidSyntax
      }
    } while true
  }

  mutating func parseArray() throws -> [T] {

    assert(peek() == arrayOpen)
    unsafePop()

    skipWhitespace()

    var tempArray: [T] = []
    tempArray.reserveCapacity(6)

    var wasNull = false
    var wasComma = false

    repeat {

      // [1, 2, [1]]
      // TODO (vdka): no trailing comma's expect next value or throw .trailingComma
      switch peek() {
      case comma:

        guard !wasComma else { throw Error.invalidSyntax }
        guard tempArray.count > 0 else { throw Error.invalidSyntax }

        wasComma = true
        unsafePop()
        skipWhitespace()

      case arrayClose:

        guard !wasComma else { throw Error.trailingComma }

        _ = try pop()
        return tempArray

      default:

        if tempArray.count > 0 && !wasComma {
          throw Error.expectedComma
        }

        let value = try parseValue()
        skipWhitespace()
        wasComma = false

        switch skipNull {
        case true where wasNull:
          wasNull = false

        default:
          tempArray.append(value)
        }
      }
    } while true
  }

  mutating func parseNumber() throws -> Number {

    assert(numbers ~= peek() || minus == peek())

    var seenExponent = false
    var seenDecimal = false

    let negative: Bool = {
      guard minus == peek() else { return false }
      unsafePop()
      return true
    }()

    var significand: UInt64 = 0
    var mantisa: UInt64 = 0
    var divisor: Double = 10
    var exponent: UInt64 = 0
    var negativeExponent = false
    var didOverflow: Bool

    repeat {

      switch peek() {
      case numbers where !seenDecimal && !seenExponent:

        (significand, didOverflow) = UInt64.multiplyWithOverflow(significand, 10)
        guard !didOverflow else { throw Error.numberOverflow }

        (significand, didOverflow) = UInt64.addWithOverflow(significand, UInt64(unsafePop() - zero))
        guard !didOverflow else { throw Error.numberOverflow }

      case numbers where seenDecimal && !seenExponent:

        divisor *= 10

        (mantisa, didOverflow) = UInt64.multiplyWithOverflow(mantisa, 10)
        guard !didOverflow else { throw Error.numberOverflow }

        (mantisa, didOverflow) = UInt64.addWithOverflow(mantisa, UInt64(unsafePop() - zero))
        guard !didOverflow else { throw Error.numberOverflow }

      case numbers where seenExponent:

        (exponent, didOverflow) = UInt64.multiplyWithOverflow(exponent, 10)
        guard !didOverflow else { throw Error.numberOverflow }

        (exponent, didOverflow) = UInt64.addWithOverflow(exponent, UInt64(unsafePop() - zero))
        guard !didOverflow else { throw Error.numberOverflow }

      case decimal where !seenExponent && !seenDecimal:

        unsafePop()
        seenDecimal = true
        guard numbers ~= peek() else { throw Error.invalidNumber }

      case E where !seenExponent,
           e where !seenExponent:

        unsafePop()
        seenExponent = true

        if peek() == minus {

          negativeExponent = true
          unsafePop()
        } else if peek() == plus {

          unsafePop()
        }
        
        guard numbers ~= peek() else { throw Error.invalidNumber }

      default:

        guard
          pointer.pointee == comma ||
          pointer.pointee == objectClose ||
          pointer.pointee == arrayClose ||
          pointer.pointee == space ||
          pointer.pointee == newline ||
          pointer.pointee == formfeed ||
          pointer.pointee == tab ||
          pointer.pointee == cr ||
          pointer == bufferPointer.endAddress
        else { throw Error.invalidNumber }

        return try constructNumber(
          significand: significand,
          mantisa: seenDecimal ? mantisa : nil,
          exponent: seenExponent ? exponent : nil,
          divisor: divisor,
          negative: negative,
          negativeExponent: negativeExponent
        )
      }
    } while true
  }

  func constructNumber(significand: UInt64, mantisa: UInt64?, exponent: UInt64?, divisor: Double, negative: Bool, negativeExponent: Bool) throws -> Number {

    if mantisa != nil || exponent != nil {
      var divisor = divisor

      divisor /= 10

      let number = Double(negative ? -1 : 1) * (Double(significand) + Double(mantisa ?? 0) / divisor)

      if let exponent = exponent {
        return .double(number.power(10, exponent: exponent, isNegative: negativeExponent))
      } else {
        return .double(number)
      }


    } else {

      switch significand {
      case validUnsigned64BitInteger where !negative:
        return .integer(Int64(significand))

      case UInt64(Int64.max) + 1 where negative:
        return .integer(Int64.min)

      case validUnsigned64BitInteger where negative:
        return .integer(-Int64(significand))

      default:
        throw Error.invalidNumber
      }
    }
  }

//  func parseNumber() throws -> Number {
//    repeat {
//      switch peek() {
//      case numbers where !seenExponent && !seenDecimal:
//
//        (significand, didOverflow) = UInt64.multiplyWithOverflow(significand, 10)
//        guard !didOverflow else { throw Error.numberOverflow }
//
//        (significand, didOverflow) = UInt64.addWithOverflow(significand, UInt64(unsafePop() - zero))
//        guard !didOverflow else { throw Error.numberOverflow }
//
//      case numbers where seenDecimal && !seenExponent: // decimals must come before exponents
//
//        divisor *= 10
//
//        (mantisa, didOverflow) = UInt64.multiplyWithOverflow(mantisa, 10)
//        guard !didOverflow else { throw Error.numberOverflow }
//
//        (mantisa, didOverflow) = UInt64.addWithOverflow(mantisa, UInt64(unsafePop() - zero))
//        guard !didOverflow else { throw Error.numberOverflow }
//
//      case numbers where seenExponent:
//
//        (exponent, didOverflow) = UInt64.multiplyWithOverflow(exponent, 10)
//        guard !didOverflow else { throw Error.numberOverflow }
//
//        (exponent, didOverflow) = UInt64.addWithOverflow(exponent, UInt64(unsafePop() - zero))
//        guard !didOverflow else { throw Error.numberOverflow }
//
//      case decimal where !seenExponent && !seenDecimal:
//
//        unsafePop() // remove the decimal
//        seenDecimal = true
//
//      case E where !seenExponent,
//           e where !seenExponent:
//
//        unsafePop() // remove the 'e' || 'E'
//        seenExponent = true
//
//        if peek() == minus {
//          negativeExponent = true
//          unsafePop() // remove the '-'
//        } else if peek() == plus {
//          unsafePop()
//        }
//
//      // is end of number
//
//      // TODO (vdka): ends are only valid when numbers follow . | e | E otherwise throw .invalidNumber
//      case arrayClose, objectClose, comma, space, tab, cr, newline, 0:
//
//        switch (seenDecimal, seenExponent) {
//        case (false, false):
//
//          if negative && significand == UInt64(Int64.max) + 1 {
//            return .integer(Int64.min)
//          } else if significand > UInt64(Int64.max) {
//            throw Error.numberOverflow
//          }
//
//          return .integer(negative ? -Int64(significand) : Int64(significand))
//
//        case (true, false):
//
//          let n = Double(significand) + Double(mantisa) / (divisor / 10)
//          return .double(negative ? -n : n)
//
//        case (false, true):
//
//          let n = Double(significand)
//            .power(10, exponent: exponent, isNegative: negativeExponent)
//
//          return .double(negative ? -n : n)
//
//        case (true, true):
//
//          let n = (Double(significand) + Double(mantisa) / (divisor / 10))
//            .power(10, exponent: exponent, isNegative: negativeExponent)
//
//          return .double(negative ? -n : n)
//
//        }
//
//      default: throw Error.invalidNumber
//      }
//    } while true
//  }

  // TODO (vdka): refactor
  // TODO (vdka): option to _repair_ Unicode
  mutating func parseString() throws -> String {

    assert(peek() == quote)
    unsafePop()

    var escaped = false
    defer { stringBuffer.removeAll(keepingCapacity: true) }

    repeat {

      let codeUnit = try pop()
      if codeUnit == backslash && !escaped {

        escaped = true
      } else if codeUnit == quote && !escaped {

        // TODO (vdka): Swift.String is slow. I wish it wasn't. It is the current barrier to NSJSON speeds
        stringBuffer.append(0)
        let string = stringBuffer.withUnsafeBufferPointer { bufferPointer in
          return String(cString: unsafeBitCast(bufferPointer.baseAddress, to: UnsafePointer<CChar>.self))
        }

        return string
      } else if escaped {

        switch codeUnit {
        case r:
          stringBuffer.append(cr)

        case t:
          stringBuffer.append(tab)

        case n:
          stringBuffer.append(newline)

        case b:
          stringBuffer.append(backspace)

        case quote:
          stringBuffer.append(quote)

        case slash:
          stringBuffer.append(slash)

        case backslash:
          stringBuffer.append(backslash)

        case u:
          let scalar = try parseUnicodeScalar()
          var bytes: [UTF8.CodeUnit] = []
          UTF8.encode(scalar, sendingOutputTo: { bytes.append($0) })
          stringBuffer.append(contentsOf: bytes)

        default:
          throw Error.invalidEscape
        }

        escaped = false

      } else {

        stringBuffer.append(codeUnit)
      }
    } while true
  }
}

extension Core {

  mutating func parseUnicodeEscape() throws -> UTF16.CodeUnit {

    var codeUnit: UInt16 = 0
    for _ in 0..<4 {
      let c = try pop()
      codeUnit <<= 4
      switch c {
      case numbers:
        codeUnit += UInt16(c - 48)
      case alphaNumericLower:
        codeUnit += UInt16(c - 87)
      case alphaNumericUpper:
        codeUnit += UInt16(c - 55)
      default:
        throw Error.invalidEscape
      }
    }

    return codeUnit
  }

  mutating func parseUnicodeScalar() throws -> UnicodeScalar {

    // For multi scalar Unicodes eg. flags
    var buffer: [UInt16] = []

    let codeUnit = try parseUnicodeEscape()
    buffer.append(codeUnit)

    if UTF16.isLeadSurrogate(codeUnit) {

      guard try pop() == backslash && pop() == u else { throw Error.invalidUnicode }
      let trailingSurrogate = try parseUnicodeEscape()
      buffer.append(trailingSurrogate)
    }

    var gen = buffer.makeIterator()

    var utf = UTF16()

    switch utf.decode(&gen) {
    case .scalarValue(let scalar):
      return scalar

    case .emptyInput, .error:
      throw Error.invalidUnicode
    }
  }

  mutating func skipColon() throws {
    skipWhitespace()
    guard case colon = try pop() else {
      throw Error.expectedColon
    }
    skipWhitespace()
  }
}

extension Core {

  func peek() -> UTF8.CodeUnit {

    return pointer.pointee
  }

  mutating func pop() throws -> UTF8.CodeUnit {

    guard pointer != bufferPointer.endAddress else { throw Error.endOfStream }
    defer { pointer = pointer.advanced(by: 1) }
    return pointer.pointee
  }

  /// Skips null pointer check. Use should occur only after checking the result of peek()
  @discardableResult
  mutating func unsafePop() -> UTF8.CodeUnit {

    defer { pointer = pointer.advanced(by: 1) }
    return pointer.pointee
  }

  mutating func skipWhitespace() {

    while pointer.pointee.isWhitespace && pointer != bufferPointer.endAddress {

      unsafePop()
    }
  }
}

extension Double {

  func power(_ base: Double, exponent: UInt64, isNegative: Bool) -> Double {
    var a: Double = self
    if isNegative {
      for _ in 0..<exponent { a /= base }
    } else {
      for _ in 0..<exponent { a *= base }
    }
    return a
  }
}
