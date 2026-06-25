/*
  Warnings:

  - You are about to drop the column `rating` on the `Comparison` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "Comparison" DROP COLUMN "rating";

-- AlterTable
ALTER TABLE "Version" ADD COLUMN     "rating" INTEGER;
