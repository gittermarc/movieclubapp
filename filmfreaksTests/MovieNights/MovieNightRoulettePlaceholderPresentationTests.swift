import Testing
@testable import filmfreaks

struct MovieNightRoulettePlaceholderPresentationTests {

    @Test func groupNameFallsBackToGenericCopyWhenMissing() {
        #expect(MovieNightRoulettePlaceholderPresentation.groupName(from: nil) == "deiner Gruppe")
        #expect(MovieNightRoulettePlaceholderPresentation.groupName(from: "   ") == "deiner Gruppe")
    }

    @Test func groupNameTrimsWhitespace() {
        #expect(MovieNightRoulettePlaceholderPresentation.groupName(from: "  Cine Club  ") == "Cine Club")
    }

    @Test func introTextMentionsBacklogAndResolvedGroupName() {
        let intro = MovieNightRoulettePlaceholderPresentation.introText(for: "  Friday Crew ")

        #expect(intro.contains("Friday Crew"))
        #expect(intro.contains("Backlog"))
        #expect(intro.contains("kuratierten Auswahl"))
    }
}
