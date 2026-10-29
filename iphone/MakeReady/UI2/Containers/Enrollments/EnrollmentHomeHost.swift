import SwiftUI

/// ui2-enrollments-browse R2: the `.enrollmentHome` destination — the enrollment page.
struct EnrollmentHomeHost: View {
    let id: String
    let name: String

    var body: some View {
        EnrollmentHomeContainer(enrollmentId: id, name: name)
    }
}
