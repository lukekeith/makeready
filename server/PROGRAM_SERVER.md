# Study Program Server Implementation

## Overview

This document outlines the server-side changes needed to support study program creation and management for the MakeReady iOS app.

> **TODO:** Once these endpoints are implemented, add them to `iphone/.claude/API_REFERENCE.md` for iOS client documentation.

---

## Database Schema Changes

Add these models to `prisma/schema.prisma`:

```prisma
// ============================================================================
// Study Program Models
// ============================================================================

enum ActivityType {
  SOAP
  OIA
  DBS
  HEAR
}

enum ActivityStatus {
  PENDING
  COMPLETE
}

model StudyProgram {
  id              String       @id @default(uuid())
  name            String
  description     String?
  defaultActivity ActivityType @default(SOAP)
  days            Int          @default(30)
  coverImageUrl   String?

  creatorId       String
  creator         User         @relation("StudyProgramCreator", fields: [creatorId], references: [id], onDelete: Cascade)

  isActive        Boolean      @default(true)
  createdAt       DateTime     @default(now())
  updatedAt       DateTime     @updatedAt

  lessons         Lesson[]

  @@index([creatorId])
  @@index([isActive])
  @@map("study_programs")
}

model Lesson {
  id              String       @id @default(uuid())
  studyProgramId  String
  studyProgram    StudyProgram @relation(fields: [studyProgramId], references: [id], onDelete: Cascade)

  dayNumber       Int          // 1-based day number

  createdAt       DateTime     @default(now())
  updatedAt       DateTime     @updatedAt

  activities      LessonActivity[]

  @@unique([studyProgramId, dayNumber])
  @@index([studyProgramId])
  @@map("lessons")
}

model LessonActivity {
  id              String         @id @default(uuid())
  lessonId        String
  lesson          Lesson         @relation(fields: [lessonId], references: [id], onDelete: Cascade)

  type            ActivityType   @default(SOAP)
  status          ActivityStatus @default(PENDING)

  // Bible passage reference (for SOAP/reading activities)
  passageReference String?       // Human-readable: "Romans 1:1-5" or "Romans 1:28 - 2:4"
  bookNumber      Int?           // 1-66
  bookName        String?        // "Romans"
  chapterStart    Int?           // Starting chapter
  chapterEnd      Int?           // Ending chapter (for cross-chapter selections)
  verseStart      Int?
  verseEnd        Int?

  orderNumber     Int            @default(1) // For multiple activities per day

  createdAt       DateTime       @default(now())
  updatedAt       DateTime       @updatedAt

  @@unique([lessonId, orderNumber])
  @@index([lessonId])
  @@map("lesson_activities")
}
```

### Update User Model

Add relation to User model:

```prisma
model User {
  // ... existing fields ...
  studyPrograms   StudyProgram[] @relation("StudyProgramCreator")
}
```

---

## Migration

After updating schema:

```bash
cd server
npx prisma migrate dev --name add_study_programs
```

---

## API Endpoints

Create `server/src/routes/programs.ts`:

### Study Program CRUD

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/programs` | Create new study program |
| GET | `/api/programs` | List user's study programs |
| GET | `/api/programs/:id` | Get program with lessons |
| PATCH | `/api/programs/:id` | Update program details |
| DELETE | `/api/programs/:id` | Soft delete program |

### Lesson Operations

| Method | Endpoint | Description |
|--------|----------|-------------|
| DELETE | `/api/programs/:programId/lessons/:lessonId` | Delete lesson and reorder |
| POST | `/api/programs/:programId/lessons/reorder` | Reorder lessons after delete |

### Activity Operations

| Method | Endpoint | Description |
|--------|----------|-------------|
| PATCH | `/api/activities/:id` | Update activity (set passage) |

---

## Implementation Details

### POST /api/programs

Creates a new study program with empty lessons for each day.

**Request Body:**
```typescript
{
  name: string           // Required
  description?: string
  defaultActivity?: "SOAP" | "OIA" | "DBS" | "HEAR"  // Default: "SOAP"
  days?: number          // Default: 30, Range: 1-360
  coverImageUrl?: string
}
```

**Response:**
```typescript
{
  success: true,
  program: {
    id: string
    name: string
    description: string | null
    defaultActivity: "SOAP" | "OIA" | "DBS" | "HEAR"
    days: number
    coverImageUrl: string | null
    creatorId: string
    createdAt: string
    updatedAt: string
    lessons: Lesson[]  // Array of created lessons with activities
  }
}
```

**Implementation:**
```typescript
router.post('/programs', requireAuth, async (req, res) => {
  try {
    const schema = z.object({
      name: z.string().min(1).max(200),
      description: z.string().max(2000).optional(),
      defaultActivity: z.enum(['SOAP', 'OIA', 'DBS', 'HEAR']).default('SOAP'),
      days: z.number().int().min(1).max(360).default(30),
      coverImageUrl: z.string().url().optional(),
    })

    const body = schema.parse(req.body)
    const userId = req.user.id

    // Create program with lessons in a transaction
    const program = await prisma.$transaction(async (tx) => {
      // Create the program
      const newProgram = await tx.studyProgram.create({
        data: {
          name: body.name,
          description: body.description,
          defaultActivity: body.defaultActivity,
          days: body.days,
          coverImageUrl: body.coverImageUrl,
          creatorId: userId,
        },
      })

      // Create lessons for each day with default activity
      const lessonsData = Array.from({ length: body.days }, (_, i) => ({
        studyProgramId: newProgram.id,
        dayNumber: i + 1,
      }))

      await tx.lesson.createMany({ data: lessonsData })

      // Create default activity for each lesson
      const lessons = await tx.lesson.findMany({
        where: { studyProgramId: newProgram.id },
        orderBy: { dayNumber: 'asc' },
      })

      await tx.lessonActivity.createMany({
        data: lessons.map((lesson) => ({
          lessonId: lesson.id,
          type: body.defaultActivity,
          status: 'PENDING',
          orderNumber: 1,
        })),
      })

      // Return full program with lessons and activities
      return tx.studyProgram.findUnique({
        where: { id: newProgram.id },
        include: {
          lessons: {
            orderBy: { dayNumber: 'asc' },
            include: {
              activities: {
                orderBy: { orderNumber: 'asc' },
              },
            },
          },
        },
      })
    })

    res.json({ success: true, program })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    console.error('Error creating program:', error)
    res.status(500).json({ success: false, error: 'Failed to create program' })
  }
})
```

### GET /api/programs

Lists all study programs for the authenticated user.

**Response:**
```typescript
{
  success: true,
  programs: StudyProgram[]  // Without lessons for list view
}
```

### GET /api/programs/:id

Gets a single program with all lessons and activities.

**Response:**
```typescript
{
  success: true,
  program: StudyProgram  // With lessons and activities
}
```

### PATCH /api/programs/:id

Updates program metadata.

**Request Body:**
```typescript
{
  name?: string
  description?: string
  days?: number  // If increased, creates new lessons. If decreased, deletes from end.
  coverImageUrl?: string
}
```

### DELETE /api/programs/:programId/lessons/:lessonId

Deletes a lesson and reorders remaining lessons.

**Implementation:**
```typescript
router.delete('/programs/:programId/lessons/:lessonId', requireAuth, async (req, res) => {
  const { programId, lessonId } = req.params
  const userId = req.user.id

  // Verify ownership
  const program = await prisma.studyProgram.findFirst({
    where: { id: programId, creatorId: userId },
  })

  if (!program) {
    return res.status(404).json({ success: false, error: 'Program not found' })
  }

  await prisma.$transaction(async (tx) => {
    // Get the lesson to delete
    const lessonToDelete = await tx.lesson.findUnique({
      where: { id: lessonId },
    })

    if (!lessonToDelete) {
      throw new Error('Lesson not found')
    }

    // Delete the lesson (cascades to activities)
    await tx.lesson.delete({ where: { id: lessonId } })

    // Reorder remaining lessons
    await tx.lesson.updateMany({
      where: {
        studyProgramId: programId,
        dayNumber: { gt: lessonToDelete.dayNumber },
      },
      data: {
        dayNumber: { decrement: 1 },
      },
    })

    // Update program day count
    await tx.studyProgram.update({
      where: { id: programId },
      data: { days: { decrement: 1 } },
    })
  })

  res.json({ success: true })
})
```

### PATCH /api/activities/:id

Updates an activity with passage information.

**Request Body:**
```typescript
{
  passageReference?: string   // "Romans 1:1-5" or "Romans 1:28 - 2:4"
  bookNumber?: number         // 45 (Romans)
  bookName?: string           // "Romans"
  chapterStart?: number       // 1
  chapterEnd?: number         // For cross-chapter: 2, otherwise same as chapterStart
  verseStart?: number         // 1
  verseEnd?: number           // 5
  status?: "PENDING" | "COMPLETE"
}
```

**Implementation:**
```typescript
router.patch('/activities/:id', requireAuth, async (req, res) => {
  const { id } = req.params
  const userId = req.user.id

  const schema = z.object({
    passageReference: z.string().optional(),
    bookNumber: z.number().int().min(1).max(66).optional(),
    bookName: z.string().optional(),
    chapter: z.number().int().min(1).optional(),
    verseStart: z.number().int().min(1).optional(),
    verseEnd: z.number().int().min(1).optional(),
    status: z.enum(['PENDING', 'COMPLETE']).optional(),
  })

  const body = schema.parse(req.body)

  // Verify ownership through lesson -> program -> creator
  const activity = await prisma.lessonActivity.findUnique({
    where: { id },
    include: {
      lesson: {
        include: {
          studyProgram: true,
        },
      },
    },
  })

  if (!activity || activity.lesson.studyProgram.creatorId !== userId) {
    return res.status(404).json({ success: false, error: 'Activity not found' })
  }

  // If passage data is provided, auto-set status to COMPLETE
  const updateData = { ...body }
  if (body.passageReference && body.status === undefined) {
    updateData.status = 'COMPLETE'
  }

  const updated = await prisma.lessonActivity.update({
    where: { id },
    data: updateData,
  })

  res.json({ success: true, activity: updated })
})
```

---

## Route Registration

In `server/src/index.ts`:

```typescript
import programsRouter from './routes/programs'

// ... after other routes
app.use('/api', programsRouter)
```

---

## Response Types (for iOS)

```typescript
// Full program response (for GET /api/programs/:id)
interface ProgramResponse {
  success: boolean
  program: {
    id: string
    name: string
    description: string | null
    defaultActivity: 'SOAP' | 'OIA' | 'DBS' | 'HEAR'
    days: number
    coverImageUrl: string | null
    creatorId: string
    isActive: boolean
    createdAt: string  // ISO date
    updatedAt: string
    lessons: {
      id: string
      studyProgramId: string
      dayNumber: number
      createdAt: string
      updatedAt: string
      activities: {
        id: string
        lessonId: string
        type: 'SOAP' | 'OIA' | 'DBS' | 'HEAR'
        status: 'PENDING' | 'COMPLETE'
        passageReference: string | null
        bookNumber: number | null
        bookName: string | null
        chapter: number | null
        verseStart: number | null
        verseEnd: number | null
        orderNumber: number
        createdAt: string
        updatedAt: string
      }[]
    }[]
  }
}
```

---

## Testing

After implementation, test these scenarios:

1. Create program with 5 days → Verify 5 lessons created with SOAP activities
2. Delete lesson 3 → Verify lessons renumber to 1,2,3,4
3. Update activity with passage → Verify status changes to COMPLETE
4. Get program → Verify all nested data returns correctly

---

## Future Enhancements

- Cover image upload via Media API
- Group enrollment (link program to groups)
- Progress tracking for enrolled members
- Analytics for completion rates
