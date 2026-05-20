<script setup lang="ts">
import '../../css/app.scss'
import LessonIsland from '../components/domain/lesson-island/lesson-island.vue'

const lessonData = {
  success: true,
  lesson: {
    lessonScheduleId: 'lesson-1',
    code: 'ABC123',
    dayNumber: 1,
    scheduledDate: '2026-02-26T06:00:00.000Z',
    templateName: 'SOAP',
    status: 'not_started',
    completionPercentage: 0,
    studyProgram: {
      id: 'sp-1',
      name: 'Romans in 30 days',
      description: 'A deep dive on the book of Romans',
      coverImageUrl: 'https://picsum.photos/seed/study/440/200',
    },
    group: {
      id: 'group-1',
      name: 'Young Professionals',
    },
    activities: [
      {
        id: 'act-1',
        type: 'READ',
        orderNumber: 1,
        title: 'Scripture',
        readContent: '<p><sup>1</sup> In the beginning God created the heaven and the earth. <sup>2</sup> And the earth was without form, and void; and darkness was upon the face of the deep.</p>',
        sourceReferences: [
          {
            id: 'ref-1',
            sourceType: 'BIBLE_PASSAGE',
            passageReference: 'Genesis 1:1-5',
            bookNumber: 1,
            bookName: 'Genesis',
            chapterStart: 1,
            verseStart: 1,
            verseEnd: 5,
          },
        ],
      },
      {
        id: 'act-2',
        type: 'USER_INPUT',
        orderNumber: 2,
        title: 'Observation',
        helpTitle: 'What do you observe?',
        helpDescription: 'Write down what you see in the passage.',
      },
      {
        id: 'act-3',
        type: 'USER_INPUT',
        orderNumber: 3,
        title: 'Application',
        helpTitle: 'How does this apply?',
        helpDescription: 'How can you apply this to your life?',
      },
      {
        id: 'act-4',
        type: 'USER_INPUT',
        orderNumber: 4,
        title: 'Prayer',
        helpTitle: 'Your prayer',
        helpDescription: 'Write a prayer based on what you learned.',
      },
    ],
  },
}
</script>

<template>
  <Story title="Pages/Lesson" group="pages">
    <Variant title="Read Step">
      <LessonIsland
        :lessonData="lessonData"
        groupId="group-1"
        lessonScheduleId="lesson-1"
        :initialStep="1"
        :isPreview="false"
      />
    </Variant>

    <Variant title="Input Step">
      <LessonIsland
        :lessonData="lessonData"
        groupId="group-1"
        lessonScheduleId="lesson-1"
        :initialStep="2"
        :isPreview="false"
      />
    </Variant>

    <Variant title="Complete Step">
      <LessonIsland
        :lessonData="lessonData"
        groupId="group-1"
        lessonScheduleId="lesson-1"
        :initialStep="5"
        :isPreview="false"
      />
    </Variant>
  </Story>
</template>
