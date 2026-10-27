/**
 * image-framing-editor D8: the member avatar upload — the rendered avatar (re-encoded to the 512px
 * WebP every reader expects), its framing and the full original, written in ONE member update.
 * framing + original: a new pick, both stored. framing alone: a re-edit, the stored original kept
 * (400 when there is none). Neither: the web / 1.0-era path, original and framing cleared. Any R2
 * failure rejects before the write (orphans accepted); the old avatar and a replaced or cleared
 * original are deleted after it, best-effort.
 */
import sharp from 'sharp'
import { prisma } from '../lib/prisma.js'
import { Prisma } from '../generated/prisma/index.js'
import { coverFramingSchema, type CoverFraming } from './group-cover.js'
import { ImageUploadError, assertDecodable, deleteOriginalBestEffort, encodeOriginal } from './image-original.js'
import { deleteMemberAvatar, uploadMemberAvatar, uploadToR2 } from './storage.js'

/** The route answers 404 (the member vanished between the auth check and the upload). */
export class MemberAvatarNotFoundError extends Error {
  readonly status = 404 as const
}

export interface SaveMemberAvatarInput {
  memberId: string
  /** D8/D14: the rendered avatar — multipart `file`, else `avatar`. */
  rendered: Buffer
  /** D8: the raw multipart `framing` field, a JSON string. */
  framingJson?: string
  /** D8: the full original photo (multipart `original`); requires framing. */
  original?: Buffer
}

export interface SaveMemberAvatarResult {
  url: string
  originalUrl: string | null
  framing: CoverFraming | null
}

/** D8: `framing` is JSON.parse'd, then validated by the group cover's strict schema. */
export function parseFramingField(raw: string): CoverFraming {
  let value: unknown
  try {
    value = JSON.parse(raw)
  } catch {
    throw new ImageUploadError('framing must be a JSON object')
  }
  const parsed = coverFramingSchema.safeParse(value)
  if (!parsed.success) {
    throw new ImageUploadError(`Invalid framing: ${parsed.error.errors[0]?.message ?? 'unexpected shape'}`)
  }
  return parsed.data
}

export async function saveMemberAvatar(input: SaveMemberAvatarInput): Promise<SaveMemberAvatarResult> {
  const { memberId, rendered, original } = input
  if (original && input.framingJson === undefined) {
    throw new ImageUploadError('original requires framing')
  }
  const framing = input.framingJson !== undefined ? parseFramingField(input.framingJson) : null

  const member = await prisma.member.findUnique({
    where: { id: memberId },
    select: { profilePicture: true, profilePictureOriginalUrl: true },
  })
  if (!member) throw new MemberAvatarNotFoundError('Member not found')
  if (framing && !original && !member.profilePictureOriginalUrl) {
    throw new ImageUploadError('No stored original to re-frame; send the original with the framing')
  }

  await assertDecodable(rendered, 'avatar image')
  if (original) await assertDecodable(original, 'original image')

  const [avatarWebp, originalJpeg] = await Promise.all([
    sharp(rendered).resize(512, 512, { fit: 'cover', withoutEnlargement: true }).webp({ quality: 85 }).toBuffer(),
    original ? encodeOriginal(original) : Promise.resolve(null),
  ])

  const timestamp = Date.now()
  const [avatar, uploadedOriginalUrl] = await Promise.all([
    uploadMemberAvatar(memberId, avatarWebp, 'image/webp'),
    originalJpeg
      ? uploadToR2(`avatars/members/${memberId}/${timestamp}-original.jpeg`, originalJpeg, 'image/jpeg')
      : Promise.resolve(null),
  ])
  if (!avatar.success || !avatar.url) throw new Error(avatar.error ?? 'Failed to upload avatar')

  const reEdit = framing !== null && uploadedOriginalUrl === null
  const originalUrl = framing === null ? null : (uploadedOriginalUrl ?? member.profilePictureOriginalUrl)

  await prisma.member.update({
    where: { id: memberId },
    data: {
      profilePicture: avatar.url,
      // D8: a re-edit leaves profilePictureOriginalUrl out of the write.
      ...(reEdit ? {} : { profilePictureOriginalUrl: originalUrl }),
      profilePictureFraming: framing ?? Prisma.DbNull,
    },
  })

  if (member.profilePicture) await deleteMemberAvatar(member.profilePicture)
  const previous = member.profilePictureOriginalUrl
  if (previous && previous !== originalUrl) await deleteOriginalBestEffort(previous, 'saveMemberAvatar')

  return { url: avatar.url, originalUrl, framing }
}
