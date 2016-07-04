//
//  PerformanceTests.swift
//  Jay
//
//  Created by Honza Dvorsky on 2/18/16.
//  Copyright © 2016 Honza Dvorsky. All rights reserved.
//

import XCTest
import Foundation
import GenericJsonParser

#if os(Linux)
  extension PerformanceTests: XCTestCaseProvider {
    var allTests : [(String, () throws -> Void)] {
      return [
        ("testParseLargeJson", testParseLargeJson),
        ("testParseLargeJson_Foundation", testParseLargeJson_Foundation),
        ("testParseLargeMinJson", testParseLargeMinJson),
        ("testParseLargeMinJson_Foundation", testParseLargeMinJson_Foundation),
      ]
    }
  }
#endif

class PerformanceTests: XCTestCase {

  func testParseLargeJson() {

    var data = self.loadFixture("large")

    measure {
      _ = try! JSON.parse(&data)
    }
  }

  func testParseLargeJson_Foundation() {

    let data = self.loadFixtureData("large")

    measure {
      _ = try! JSONSerialization.jsonObject(with: data, options: [])
    }
  }

  func testParseLargeMinJson() {

    var data = self.loadFixture("large_min")

    measure {
      _ = try! JSON.parse(&data)
    }
  }

  func testParseLargeMinJson_Foundation() {

    let data = self.loadFixtureData("large_min")
    
    measure {
      _ = try! JSONSerialization.jsonObject(with: data, options: [])
    }
  }
}

extension PerformanceTests {

  func urlForFixture(_ name: String) -> URL {

    let parent = (#file).components(separatedBy: "/").dropLast().joined(separator: "/")
    let url = URL(string: "file://\(parent)/Fixtures/\(name).json")!
    print("Loading fixture from url \(url)")
    return url
  }

  func loadFixture(_ name: String) -> [UInt8] {

    let url = self.urlForFixture(name)
    let data = Array(try! String(contentsOf: url).utf8)
    return data
  }

  func loadFixtureData(_ name: String) -> Foundation.Data {

    let url = self.urlForFixture(name)
    let data = try! Foundation.Data(contentsOf: url)
    return data
  }
}


