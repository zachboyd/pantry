@testable import JeevesKit
import XCTest

final class StringTrimmingTests: XCTestCase {
    // MARK: - String Extension Tests

    func testBasicStringTrimming() {
        // Test basic whitespace trimming
        XCTAssertEqual("  hello  ".trimmed(), "hello")
        XCTAssertEqual("hello  ".trimmed(), "hello")
        XCTAssertEqual("  hello".trimmed(), "hello")

        // Test newline trimming
        XCTAssertEqual("hello\n".trimmed(), "hello")
        XCTAssertEqual("\nhello".trimmed(), "hello")
        XCTAssertEqual("\nhello\n".trimmed(), "hello")

        // Test tab trimming
        XCTAssertEqual("\thello\t".trimmed(), "hello")
        XCTAssertEqual("hello\t".trimmed(), "hello")

        // Test mixed whitespace
        XCTAssertEqual("  \n\thello\t\n  ".trimmed(), "hello")
    }

    func testNoTrimmingNeeded() {
        // Test performance optimization - should return self
        let original = "hello"
        XCTAssertTrue(original.trimmed() === original) // Same instance

        // Test empty string
        XCTAssertEqual("".trimmed(), "")
    }

    func testInternalWhitespacePreserved() {
        // Internal spaces should be preserved
        XCTAssertEqual("  hello world  ".trimmed(), "hello world")
        XCTAssertEqual("  hello   world  ".trimmed(), "hello   world")

        // Internal newlines should be preserved
        XCTAssertEqual("  hello\nworld  ".trimmed(), "hello\nworld")
    }

    func testNeedsTrimmingCheck() {
        // Test needsTrimming property
        XCTAssertTrue("  hello".needsTrimming)
        XCTAssertTrue("hello  ".needsTrimming)
        XCTAssertTrue("hello\n".needsTrimming)
        XCTAssertTrue("\thello".needsTrimming)

        XCTAssertFalse("hello".needsTrimming)
        XCTAssertFalse("hello world".needsTrimming)
        XCTAssertFalse("".needsTrimming)
    }

    // MARK: - Optional String Extension Tests

    func testOptionalStringTrimming() {
        // Test nil handling
        let nilString: String? = nil
        XCTAssertNil(nilString.trimmed())

        // Test trimming to empty
        let emptyAfterTrim: String? = "   "
        XCTAssertNil(emptyAfterTrim.trimmed())

        // Test normal trimming
        let normal: String? = "  hello  "
        XCTAssertEqual(normal.trimmed(), "hello")
    }

    func testOptionalStringTrimmingPreservingEmpty() {
        // Test nil handling
        let nilString: String? = nil
        XCTAssertNil(nilString.trimmedPreservingEmpty())

        // Test trimming to empty - should preserve
        let emptyAfterTrim: String? = "   "
        XCTAssertEqual(emptyAfterTrim.trimmedPreservingEmpty(), "")

        // Test normal trimming
        let normal: String? = "  hello  "
        XCTAssertEqual(normal.trimmedPreservingEmpty(), "hello")
    }

    // MARK: - TrimmingConfiguration Tests

    func testTrimmingConfigurationDefaults() {
        let config = TrimmingConfiguration.default

        XCTAssertTrue(config.enabledForMutations)
        XCTAssertFalse(config.enabledForQueries)
        XCTAssertEqual(config.maxStringLength, 10000)
        XCTAssertFalse(config.enableLogging)

        // Check default excluded fields
        XCTAssertTrue(config.excludedFields.contains("code_snippet"))
        XCTAssertTrue(config.excludedFields.contains("formatted_text"))
        XCTAssertTrue(config.excludedFields.contains("raw_content"))
        XCTAssertTrue(config.excludedFields.contains("markdown"))
        XCTAssertTrue(config.excludedFields.contains("html"))
    }

    func testTrimmingConfigurationCustom() {
        let config = TrimmingConfiguration(
            enabledForMutations: false,
            enabledForQueries: true,
            excludedFields: ["custom_field"],
            maxStringLength: 5000,
            enableLogging: true,
        )

        XCTAssertFalse(config.enabledForMutations)
        XCTAssertTrue(config.enabledForQueries)
        XCTAssertEqual(config.maxStringLength, 5000)
        XCTAssertTrue(config.enableLogging)
        XCTAssertEqual(config.excludedFields, ["custom_field"])
    }
}

// MARK: - StringTrimmingInterceptor Tests

final class StringTrimmingInterceptorTests: XCTestCase {
    private var interceptor: StringTrimmingInterceptor!

    override func setUp() {
        super.setUp()
        interceptor = StringTrimmingInterceptor()
    }

    override func tearDown() {
        interceptor = nil
        super.tearDown()
    }

    // Note: Full interceptor testing would require mocking Apollo's RequestChain
    // and HTTPRequest objects. These tests focus on the trimming logic.

    func testInterceptorConfiguration() {
        // Test with default configuration
        let defaultInterceptor = StringTrimmingInterceptor()
        XCTAssertNotNil(defaultInterceptor.id)

        // Test with custom configuration
        let customConfig = TrimmingConfiguration(
            enabledForMutations: false,
            excludedFields: ["test_field"],
        )
        let customInterceptor = StringTrimmingInterceptor(configuration: customConfig)
        XCTAssertNotNil(customInterceptor.id)
    }

    // MARK: - Integration Test Helpers

    func testRealWorldScenarios() {
        // Test common user input scenarios

        // Email with spaces
        XCTAssertEqual("  user@example.com  ".trimmed(), "user@example.com")

        // Name with accidental spaces
        XCTAssertEqual("  John Doe  ".trimmed(), "John Doe")

        // Multi-line description
        let description = """
          This is a household
          with multiple lines  
        """
        let trimmedDescription = """
        This is a household
          with multiple lines
        """
        XCTAssertEqual(description.trimmed(), trimmedDescription)

        // Empty input that becomes nil
        let emptyInput: String? = "   \n\t   "
        XCTAssertNil(emptyInput.trimmed())
    }
}
