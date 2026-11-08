//
//  ProgramFixtures.swift
//  MakeReady
//
//  Program fixture data for demo/testing
//

import Foundation
import UIKit

struct ProgramFixtures {
    // Sample program metadata
    static let sampleProgramName = "30 Days of Romans"
    static let sampleProgramDescription = "A journey through Paul's letter to the Romans"
    
    // Sample cover image - loaded from Unsplash
    static let sampleCoverImage: UIImage? = {
        // Using Unsplash photo of an open Bible
        // This will download synchronously for preview purposes
        guard let url = URL(string: "https://images.unsplash.com/photo-1519791883288-dc8bd696e667?w=800&h=480&fit=crop") else {
            return nil
        }
        
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
        
        return nil
    }()

    // Sample lesson data (5 days with no activities) - CardLessonData for backward compatibility
    static let sampleProgramLessons: [CardLessonData] = [
        CardLessonData(
            id: "program-lesson-1",
            day: 1,
            activities: [],
            onTap: nil
        ),
        CardLessonData(
            id: "program-lesson-2",
            day: 2,
            activities: [],
            onTap: nil
        ),
        CardLessonData(
            id: "program-lesson-3",
            day: 3,
            activities: [],
            onTap: nil
        ),
        CardLessonData(
            id: "program-lesson-4",
            day: 4,
            activities: [],
            onTap: nil
        ),
        CardLessonData(
            id: "program-lesson-5",
            day: 5,
            activities: [],
            onTap: nil
        )
    ]

    // Sample Lesson models (5 days, no activities)
    static let sampleLessons: [Lesson] = {
        let now = Date()
        let programId = "sample-program"

        return (1...5).map { position in
            Lesson(
                id: "sample-lesson-\(position)",
                studyProgramId: programId,
                position: position,
                createdAt: now,
                updatedAt: now
            )
        }
    }()
}
