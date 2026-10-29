import SwiftUI

/// ui2-enrollments-browse R2: the `.enrollmentHome` destination of the shell's stacks. Task 11 of
/// the plan puts `EnrollmentHomeContainer` here; until then the route lands on the unwired page.
struct EnrollmentHomeHost: View {
    let id: String
    let name: String

    var body: some View {
        EmptyPage()
    }
}
