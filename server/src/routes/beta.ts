import { Router } from 'express'
import { createPublicKey, createVerify, type JsonWebKey } from 'crypto'
import { z } from 'zod'
import { prisma } from '../lib/prisma.js'

const router = Router()

const betaApplicationSchema = z.object({
  idToken: z.string().min(1),
  phoneNumber: z.string().max(40).optional().or(z.literal('')),
  organizationName: z.string().trim().min(2).max(200),
  organizationWebsite: z.string().trim().url().max(500).optional().or(z.literal('')),
  groupMemberAgeRange: z.string().trim().min(2).max(120),
  numberOfGroups: z.coerce.number().int().min(1).max(500),
  estimatedGroupMembers: z.coerce.number().int().min(1).max(100000),
  groupDescription: z.string().trim().min(20).max(5000),
})

interface MicrosoftJwk {
  kid: string
  kty: string
  n: string
  e: string
  alg?: string
  use?: string
}

interface MicrosoftJwtHeader {
  alg?: string
  kid?: string
  typ?: string
}

interface MicrosoftJwtPayload {
  aud?: string
  email?: string
  exp?: number
  iss?: string
  name?: string
  nbf?: number
  oid?: string
  preferred_username?: string
  sub?: string
  tid?: string
  upn?: string
}

interface MicrosoftApplicant {
  microsoftId: string
  email: string
  name: string
}

let jwksCache: { keys: MicrosoftJwk[]; expiresAt: number } | null = null

function optionalString(value: string | undefined): string | undefined {
  const trimmed = value?.trim()
  return trimmed ? trimmed : undefined
}

function base64UrlDecode(value: string): Buffer {
  return Buffer.from(value, 'base64url')
}

function parseJwt(idToken: string): { header: MicrosoftJwtHeader; payload: MicrosoftJwtPayload; signingInput: string; signature: Buffer } {
  const parts = idToken.split('.')
  if (parts.length !== 3) {
    throw new Error('Invalid Microsoft token format')
  }

  return {
    header: JSON.parse(base64UrlDecode(parts[0]).toString('utf8')),
    payload: JSON.parse(base64UrlDecode(parts[1]).toString('utf8')),
    signingInput: `${parts[0]}.${parts[1]}`,
    signature: base64UrlDecode(parts[2]),
  }
}

function microsoftTenant(): string {
  return process.env.MICROSOFT_TENANT_ID || process.env.AZURE_TENANT_ID || 'organizations'
}

function microsoftClientId(): string | undefined {
  return process.env.MICROSOFT_CLIENT_ID || process.env.AZURE_CLIENT_ID
}

async function microsoftJwks(): Promise<MicrosoftJwk[]> {
  if (jwksCache && jwksCache.expiresAt > Date.now()) {
    return jwksCache.keys
  }

  const tenant = encodeURIComponent(microsoftTenant())
  const response = await fetch(`https://login.microsoftonline.com/${tenant}/discovery/v2.0/keys`)
  if (!response.ok) {
    throw new Error('Failed to fetch Microsoft signing keys')
  }

  const body = await response.json() as { keys?: MicrosoftJwk[] }
  const keys = body.keys || []
  jwksCache = { keys, expiresAt: Date.now() + 60 * 60 * 1000 }
  return keys
}

function verifyJwtSignature(signingInput: string, signature: Buffer, jwk: MicrosoftJwk): boolean {
  const publicKey = createPublicKey({ key: jwk as unknown as JsonWebKey, format: 'jwk' })
  const verifier = createVerify('RSA-SHA256')
  verifier.update(signingInput)
  verifier.end()
  return verifier.verify(publicKey, signature)
}

function validateMicrosoftPayload(payload: MicrosoftJwtPayload): MicrosoftApplicant {
  const clientId = microsoftClientId()
  if (!clientId) {
    throw new Error('Microsoft sign-in is not configured')
  }

  if (payload.aud !== clientId) {
    throw new Error('Microsoft token audience mismatch')
  }

  const now = Math.floor(Date.now() / 1000)
  if (payload.exp && payload.exp < now) {
    throw new Error('Microsoft token expired')
  }
  if (payload.nbf && payload.nbf > now) {
    throw new Error('Microsoft token not yet valid')
  }

  const issuer = payload.iss || ''
  if (!issuer.startsWith('https://login.microsoftonline.com/')) {
    throw new Error('Microsoft token issuer mismatch')
  }

  const tenant = microsoftTenant()
  if (!['common', 'organizations', 'consumers'].includes(tenant) && payload.tid !== tenant) {
    throw new Error('Microsoft token tenant mismatch')
  }

  const email = payload.email || payload.preferred_username || payload.upn
  const microsoftId = payload.oid || payload.sub
  if (!email || !microsoftId) {
    throw new Error('Microsoft token missing identity claims')
  }

  return {
    microsoftId,
    email,
    name: payload.name || email,
  }
}

async function verifyMicrosoftApplicant(idToken: string): Promise<MicrosoftApplicant> {
  const parsed = parseJwt(idToken)
  if (parsed.header.alg !== 'RS256' || !parsed.header.kid) {
    throw new Error('Unsupported Microsoft token header')
  }

  const keys = await microsoftJwks()
  const key = keys.find((candidate) => candidate.kid === parsed.header.kid)
  if (!key || !verifyJwtSignature(parsed.signingInput, parsed.signature, key)) {
    throw new Error('Microsoft token signature mismatch')
  }

  return validateMicrosoftPayload(parsed.payload)
}

/**
 * Submit a Microsoft-authenticated beta application.
 *
 * This endpoint intentionally creates inactive leader/org records. Approved
 * leader access is a separate later workflow; inactive users are rejected by
 * normal auth/session middleware.
 */
router.post('/applications', async (req, res) => {
  try {
    const body = betaApplicationSchema.parse(req.body)

    let applicant: MicrosoftApplicant
    try {
      applicant = await verifyMicrosoftApplicant(body.idToken)
    } catch (error) {
      console.error('[beta] Microsoft token verification failed:', error)
      return res.status(401).json({
        success: false,
        error: 'Invalid or expired Microsoft token',
      })
    }

    const existingActiveUser = await prisma.user.findFirst({
      where: {
        OR: [
          { microsoftId: applicant.microsoftId },
          { email: applicant.email },
        ],
        isActive: true,
      },
      select: { id: true },
    })

    if (existingActiveUser) {
      return res.status(409).json({
        success: false,
        error: 'This Microsoft account already has MakeReady access. Please contact support if you need beta review help.',
      })
    }

    const result = await prisma.$transaction(async (tx) => {
      let user = await tx.user.findFirst({
        where: {
          OR: [
            { microsoftId: applicant.microsoftId },
            { email: applicant.email },
          ],
        },
      })

      if (user) {
        user = await tx.user.update({
          where: { id: user.id },
          data: {
            microsoftId: applicant.microsoftId,
            email: applicant.email,
            name: applicant.name,
            isActive: false,
          },
        })
      } else {
        user = await tx.user.create({
          data: {
            microsoftId: applicant.microsoftId,
            email: applicant.email,
            name: applicant.name,
            isActive: false,
          },
        })
      }

      let organization = await tx.organization.findUnique({
        where: { ownerId: user.id },
      })

      if (organization) {
        organization = await tx.organization.update({
          where: { id: organization.id },
          data: {
            name: body.organizationName,
            isActive: false,
          },
        })
      } else {
        organization = await tx.organization.create({
          data: {
            name: body.organizationName,
            ownerId: user.id,
            isActive: false,
          },
        })
      }

      await tx.user.update({
        where: { id: user.id },
        data: { organizationId: organization.id },
      })

      const existingApplication = await tx.betaApplication.findFirst({
        where: {
          OR: [
            { microsoftId: applicant.microsoftId },
            { applicantEmail: applicant.email },
          ],
        },
      })

      const applicationData = {
        microsoftId: applicant.microsoftId,
        applicantEmail: applicant.email,
        applicantName: applicant.name,
        phoneNumber: optionalString(body.phoneNumber),
        organizationName: body.organizationName,
        organizationWebsite: optionalString(body.organizationWebsite),
        groupMemberAgeRange: body.groupMemberAgeRange,
        numberOfGroups: body.numberOfGroups,
        estimatedGroupMembers: body.estimatedGroupMembers,
        groupDescription: body.groupDescription,
        userId: user.id,
        organizationId: organization.id,
      }

      const application = existingApplication
        ? await tx.betaApplication.update({
            where: { id: existingApplication.id },
            data: applicationData,
          })
        : await tx.betaApplication.create({
            data: applicationData,
          })

      return { application }
    })

    return res.status(201).json({
      success: true,
      application: {
        id: result.application.id,
        status: result.application.status,
        applicantEmail: result.application.applicantEmail,
        organizationName: result.application.organizationName,
        createdAt: result.application.createdAt,
      },
    })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        success: false,
        error: 'Invalid beta application',
        issues: error.issues.map((issue) => ({
          path: issue.path.join('.'),
          message: issue.message,
        })),
      })
    }

    console.error('[beta] Failed to submit application:', error)
    return res.status(500).json({
      success: false,
      error: 'Failed to submit beta application',
    })
  }
})

export default router
