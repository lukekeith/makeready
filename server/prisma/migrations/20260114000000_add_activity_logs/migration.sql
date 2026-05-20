-- CreateEnum
CREATE TYPE "LogCategory" AS ENUM ('AUTH', 'JOIN', 'ACCESS');

-- CreateEnum
CREATE TYPE "LogStatus" AS ENUM ('SUCCESS', 'FAILURE', 'WARNING');

-- CreateTable
CREATE TABLE "activity_logs" (
    "id" TEXT NOT NULL,
    "category" "LogCategory" NOT NULL,
    "activityType" TEXT NOT NULL,
    "status" "LogStatus" NOT NULL,
    "userId" TEXT,
    "memberId" TEXT,
    "actorIp" TEXT,
    "userAgent" TEXT,
    "route" TEXT NOT NULL,
    "method" TEXT NOT NULL,
    "groupId" TEXT,
    "eventId" TEXT,
    "enrollmentId" TEXT,
    "lessonId" TEXT,
    "organizationId" TEXT,
    "inviteId" TEXT,
    "message" TEXT NOT NULL,
    "errorCode" TEXT,
    "errorMessage" TEXT,
    "warningMessage" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "activity_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "activity_logs_category_idx" ON "activity_logs"("category");

-- CreateIndex
CREATE INDEX "activity_logs_activityType_idx" ON "activity_logs"("activityType");

-- CreateIndex
CREATE INDEX "activity_logs_status_idx" ON "activity_logs"("status");

-- CreateIndex
CREATE INDEX "activity_logs_userId_idx" ON "activity_logs"("userId");

-- CreateIndex
CREATE INDEX "activity_logs_memberId_idx" ON "activity_logs"("memberId");

-- CreateIndex
CREATE INDEX "activity_logs_groupId_idx" ON "activity_logs"("groupId");

-- CreateIndex
CREATE INDEX "activity_logs_createdAt_idx" ON "activity_logs"("createdAt");

-- CreateIndex
CREATE INDEX "activity_logs_category_createdAt_idx" ON "activity_logs"("category", "createdAt");

-- CreateIndex
CREATE INDEX "activity_logs_activityType_status_idx" ON "activity_logs"("activityType", "status");
