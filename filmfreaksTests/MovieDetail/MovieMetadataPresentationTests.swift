import Testing
@testable import filmfreaks
import Foundation

struct MovieMetadataPresentationTests {

    @Test func formattedReleaseDateFormatsTMDbDateStrings() {
        #expect(MovieMetadataPresentation.formattedReleaseDate("2016-11-10") == "10.11.2016")
    }

    @Test func formattedReleaseDateFallsBackToTrimmedSourceValue() {
        #expect(MovieMetadataPresentation.formattedReleaseDate("  Frühjahr 2016  ") == "Frühjahr 2016")
    }

    @Test func posterURLBuildsRequestedWidthURL() {
        let url = MovieMetadataPresentation.posterURL(path: "/poster.jpg", width: .w342)
        #expect(url?.absoluteString == "https://image.tmdb.org/t/p/w342/poster.jpg")
    }

    @Test func backdropURLBuildsRequestedWidthURL() {
        let url = MovieMetadataPresentation.backdropURL(path: "/backdrop.jpg", width: .w780)
        #expect(url?.absoluteString == "https://image.tmdb.org/t/p/w780/backdrop.jpg")
    }

    @Test func genericImageURLBuildsRequestedWidthURL() {
        let url = MovieMetadataPresentation.imageURL(path: "/image.jpg", width: .w1280)
        #expect(url?.absoluteString == "https://image.tmdb.org/t/p/w1280/image.jpg")
    }
}
