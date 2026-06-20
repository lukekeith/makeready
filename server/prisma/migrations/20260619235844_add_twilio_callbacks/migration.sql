-- CreateTable
CREATE TABLE "twilio_callbacks" (
    "id" TEXT NOT NULL,
    "callbackType" TEXT,
    "accountSid" TEXT,
    "resourceSid" TEXT,
    "eventType" TEXT,
    "payload" JSONB NOT NULL,
    "receivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "twilio_callbacks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "twilio_callbacks_receivedAt_idx" ON "twilio_callbacks"("receivedAt");

-- CreateIndex
CREATE INDEX "twilio_callbacks_accountSid_idx" ON "twilio_callbacks"("accountSid");

-- CreateIndex
CREATE INDEX "twilio_callbacks_resourceSid_idx" ON "twilio_callbacks"("resourceSid");

-- CreateIndex
CREATE INDEX "twilio_callbacks_eventType_idx" ON "twilio_callbacks"("eventType");
