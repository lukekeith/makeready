import { PrismaClient } from '../src/generated/prisma/index.js';
import { randomUUID } from 'crypto';

const prisma = new PrismaClient();

async function main() {
  const groupId = "ece51e8e-0e5d-49e7-97be-cfeefd54b3ab"; // Young Professionals
  const studyProgramId = "8fa491c1-ccc2-4f62-8b30-c472edd55593"; // Genesis
  const userId = "57ed656d-acc0-4dcf-a9dd-c655f01e7b06";
  const enabledDays = ["Mon", "Tue", "Wed", "Thu", "Fri"];
  const startDate = new Date("2026-01-12");

  console.log("Testing enrollment creation...");
  
  // Get program with lessons
  const program = await prisma.studyProgram.findFirst({
    where: { id: studyProgramId, isActive: true },
    include: { lessons: { orderBy: { dayNumber: 'asc' } } }
  });
  
  if (!program) {
    console.log("Program not found!");
    return;
  }
  
  console.log(`Program: ${program.name}, Lessons: ${program.lessons.length}`);
  
  // Get group
  const group = await prisma.group.findFirst({
    where: { id: groupId, isActive: true }
  });
  
  if (!group) {
    console.log("Group not found!");
    return;
  }
  
  console.log(`Group: ${group.name}`);
  
  // Calculate schedule dates
  const dayMap = { 'Sun': 0, 'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6 };
  const enabledDayNumbers = enabledDays.map(day => dayMap[day]);
  
  const scheduleDates = [];
  let currentDate = new Date(startDate);
  let lessonsNeeded = program.lessons.length;
  
  while (scheduleDates.length < lessonsNeeded) {
    const dayOfWeek = currentDate.getDay();
    if (enabledDayNumbers.includes(dayOfWeek)) {
      scheduleDates.push(new Date(currentDate));
    }
    currentDate.setDate(currentDate.getDate() + 1);
  }
  
  console.log(`Schedule dates generated: ${scheduleDates.length}`);
  const endDate = scheduleDates[scheduleDates.length - 1];
  
  // Pre-generate IDs
  const enrollmentId = randomUUID();
  const scheduleData = program.lessons.map((lesson, i) => ({
    id: randomUUID(),
    enrollmentId,
    lessonId: lesson.id,
    scheduledDate: scheduleDates[i],
    lesson,
  }));
  
  console.log(`Schedule data prepared: ${scheduleData.length} items`);
  
  // Try creating enrollment
  try {
    const enrollment = await prisma.$transaction(async (tx) => {
      console.log("Step 1: Creating enrollment...");
      await tx.enrollment.create({
        data: {
          id: enrollmentId,
          groupId,
          studyProgramId,
          startDate,
          endDate,
          enabledDays: JSON.stringify(enabledDays),
          smsTime: "08:00",
          timezone: "America/Chicago",
          createdById: userId,
        },
      });
      console.log("Step 1: Complete");
      
      console.log("Step 2: Creating lesson schedules...");
      await tx.lessonSchedule.createMany({
        data: scheduleData.map(({ id, enrollmentId, lessonId, scheduledDate }) => ({
          id,
          enrollmentId,
          lessonId,
          scheduledDate,
        })),
      });
      console.log("Step 2: Complete");
      
      console.log("Step 3: Creating events...");
      await tx.event.createMany({
        data: scheduleData.map(({ id: lessonScheduleId, lesson, scheduledDate }) => ({
          groupId,
          type: 'LESSON',
          title: `Day ${lesson.dayNumber}: ${program.name}`,
          description: program.description,
          date: scheduledDate,
          startTime: "08:00",
          lessonScheduleId,
          enrollmentId,
          dayNumber: lesson.dayNumber,
        })),
      });
      console.log("Step 3: Complete");
      
      console.log("Step 4: Creating welcome post...");
      const firstLessonDate = scheduleDates[0];
      await tx.post.create({
        data: {
          groupId,
          type: 'WELCOME',
          title: `${program.name} starts ${firstLessonDate.toDateString()}!`,
          content: `${group.name} is beginning the ${program.name} study program!`,
          imageUrl: program.coverImageUrl,
          enrollmentId,
        },
      });
      console.log("Step 4: Complete");
      
      return tx.enrollment.findUnique({ where: { id: enrollmentId } });
    });
    
    console.log("SUCCESS! Enrollment created:", enrollment?.id);
  } catch (error) {
    console.error("FAILED:", error.message);
    console.error("Full error:", error);
  }
}

main().then(() => process.exit(0)).catch(e => { console.error("Script error:", e); process.exit(1); });
