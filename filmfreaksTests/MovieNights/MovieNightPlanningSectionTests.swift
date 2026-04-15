import Testing
@testable import filmfreaks

struct MovieNightPlanningSectionTests {

    @Test func defaultSectionStartsInCalendar() {
        #expect(MovieNightPlanningSection.defaultSection == .calendar)
    }

    @Test func sectionsExposeStableOrderAndTitles() {
        #expect(MovieNightPlanningSection.allCases == [.calendar, .roulette])
        #expect(MovieNightPlanningSection.calendar.title == "Kalender")
        #expect(MovieNightPlanningSection.roulette.title == "Roulette")
    }

    @Test func sectionsExposeExpectedNavigationTitles() {
        #expect(MovieNightPlanningSection.calendar.navigationTitle == "Kalender")
        #expect(MovieNightPlanningSection.roulette.navigationTitle == "Filmroulette")
    }
}
