import Testing
@testable import filmfreaks
import Foundation

struct MovieMetadataPresentationTests {

    @Test func formattedReleaseDateFormatsTMDbDateStrings() {
        #expect(MovieMetadataPresentation.formattedReleaseDate("2016-11-10") == "10.11.2016")
    }

    @Test func formattedReleaseDateFormatsTMDbTimestampStrings() {
        #expect(MovieMetadataPresentation.formattedReleaseDate("2016-11-24T00:00:00.000Z") == "24.11.2016")
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


    @Test func bestBackdropURLPrefersExplicitBackdropPath() {
        let images = TMDbMovieImagesResponse(
            backdrops: [
                TMDbImage(
                    aspect_ratio: nil,
                    height: 720,
                    iso_639_1: nil,
                    file_path: "/image-backdrop.jpg",
                    vote_average: 8.0,
                    vote_count: 10,
                    width: 1280
                )
            ],
            logos: [],
            posters: []
        )

        let url = MovieMetadataPresentation.bestBackdropURL(
            backdropPath: "/explicit-backdrop.jpg",
            images: images,
            width: .w1280
        )

        #expect(url?.absoluteString == "https://image.tmdb.org/t/p/w1280/explicit-backdrop.jpg")
    }

    @Test func bestBackdropURLFallsBackToBestImageBackdrop() {
        let images = TMDbMovieImagesResponse(
            backdrops: [
                TMDbImage(
                    aspect_ratio: nil,
                    height: 720,
                    iso_639_1: nil,
                    file_path: "/low-votes.jpg",
                    vote_average: 9.0,
                    vote_count: 2,
                    width: 1280
                ),
                TMDbImage(
                    aspect_ratio: nil,
                    height: 1080,
                    iso_639_1: nil,
                    file_path: "/high-votes.jpg",
                    vote_average: 7.0,
                    vote_count: 20,
                    width: 1920
                )
            ],
            logos: [],
            posters: []
        )

        let url = MovieMetadataPresentation.bestBackdropURL(
            backdropPath: nil,
            images: images,
            width: .w780
        )

        #expect(url?.absoluteString == "https://image.tmdb.org/t/p/w780/high-votes.jpg")
    }

    @Test func trailerPreviewURLFallsBackToPosterWhenBackdropIsMissing() {
        let url = MovieMetadataPresentation.trailerPreviewURL(
            backdropPath: nil,
            images: nil,
            posterPath: "/poster.jpg"
        )

        #expect(url?.absoluteString == "https://image.tmdb.org/t/p/w500/poster.jpg")
    }

}
