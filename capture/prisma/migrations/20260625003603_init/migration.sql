-- CreateTable
CREATE TABLE "Comparison" (
    "id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "groupName" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "adapter" TEXT NOT NULL,
    "rating" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Comparison_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Version" (
    "id" TEXT NOT NULL,
    "comparisonId" TEXT NOT NULL,
    "viewport" TEXT NOT NULL,
    "capturedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "gitSha" TEXT,
    "gitDirty" BOOLEAN NOT NULL DEFAULT false,
    "sourceHash" TEXT,
    "sharedData" JSONB,
    "componentName" TEXT,
    "iphoneView" TEXT,
    "clientView" TEXT,
    "width" INTEGER,
    "height" INTEGER,

    CONSTRAINT "Version_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Screenshot" (
    "id" TEXT NOT NULL,
    "versionId" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "device" TEXT,
    "path" TEXT NOT NULL,
    "width" INTEGER,
    "height" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Screenshot_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Comment" (
    "id" TEXT NOT NULL,
    "comparisonId" TEXT NOT NULL,
    "versionId" TEXT NOT NULL,
    "screenshotId" TEXT,
    "platform" TEXT NOT NULL,
    "viewport" TEXT NOT NULL,
    "x" DOUBLE PRECISION NOT NULL,
    "y" DOUBLE PRECISION NOT NULL,
    "resolved" BOOLEAN NOT NULL DEFAULT false,
    "resolvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Comment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Message" (
    "id" TEXT NOT NULL,
    "commentId" TEXT NOT NULL,
    "source" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Message_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Version_comparisonId_viewport_capturedAt_idx" ON "Version"("comparisonId", "viewport", "capturedAt");

-- CreateIndex
CREATE INDEX "Screenshot_versionId_platform_idx" ON "Screenshot"("versionId", "platform");

-- CreateIndex
CREATE INDEX "Comment_comparisonId_resolved_idx" ON "Comment"("comparisonId", "resolved");

-- CreateIndex
CREATE INDEX "Message_commentId_idx" ON "Message"("commentId");

-- AddForeignKey
ALTER TABLE "Version" ADD CONSTRAINT "Version_comparisonId_fkey" FOREIGN KEY ("comparisonId") REFERENCES "Comparison"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Screenshot" ADD CONSTRAINT "Screenshot_versionId_fkey" FOREIGN KEY ("versionId") REFERENCES "Version"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Comment" ADD CONSTRAINT "Comment_comparisonId_fkey" FOREIGN KEY ("comparisonId") REFERENCES "Comparison"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Comment" ADD CONSTRAINT "Comment_versionId_fkey" FOREIGN KEY ("versionId") REFERENCES "Version"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Comment" ADD CONSTRAINT "Comment_screenshotId_fkey" FOREIGN KEY ("screenshotId") REFERENCES "Screenshot"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Message" ADD CONSTRAINT "Message_commentId_fkey" FOREIGN KEY ("commentId") REFERENCES "Comment"("id") ON DELETE CASCADE ON UPDATE CASCADE;
