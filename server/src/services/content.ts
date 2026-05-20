import { prisma } from '../lib/prisma.js'
import { ContentVisibility } from './permission.js'

/**
 * Content Service - Media management
 *
 * Handles CRUD operations for Media
 */

// ============================================================================
// Type Definitions
// ============================================================================

export interface CreateMediaData {
  title: string
  description?: string
  url: string
  type: string
  mimeType?: string
  fileSize?: number
  organizationId: string
  groupId?: string
  uploadedBy: string
  visibility?: ContentVisibility
}

export interface UpdateMediaData {
  title?: string
  description?: string
  visibility?: ContentVisibility
  isActive?: boolean
}

export interface ContentFilters {
  organizationId?: string
  groupId?: string
  visibility?: ContentVisibility
  isActive?: boolean
  createdBy?: string
}

// ============================================================================
// Media Management
// ============================================================================

export async function createMedia(data: CreateMediaData) {
  try {
    const media = await prisma.media.create({
      data: {
        title: data.title,
        description: data.description,
        url: data.url,
        type: data.type,
        mimeType: data.mimeType,
        fileSize: data.fileSize,
        organizationId: data.organizationId,
        groupId: data.groupId,
        uploadedBy: data.uploadedBy,
        visibility: data.visibility || 'members',
      },
      include: {
        organization: {
          select: { id: true, name: true },
        },
        group: {
          select: { id: true, name: true },
        },
        uploader: {
          select: { id: true, name: true, email: true },
        },
      },
    })

    return { success: true, data: media }
  } catch (error) {
    console.error('Error creating media:', error)
    return { success: false, error: 'Failed to create media' }
  }
}

export async function getMedia(mediaId: string) {
  try {
    const media = await prisma.media.findUnique({
      where: { id: mediaId },
      include: {
        organization: {
          select: { id: true, name: true },
        },
        group: {
          select: { id: true, name: true },
        },
        uploader: {
          select: { id: true, name: true, email: true },
        },
      },
    })

    if (!media) {
      return { success: false, error: 'Media not found' }
    }

    return { success: true, data: media }
  } catch (error) {
    console.error('Error fetching media:', error)
    return { success: false, error: 'Failed to fetch media' }
  }
}

export async function listMedia(filters: ContentFilters = {}) {
  try {
    const media = await prisma.media.findMany({
      where: {
        ...(filters.organizationId && { organizationId: filters.organizationId }),
        ...(filters.groupId !== undefined && { groupId: filters.groupId }),
        ...(filters.visibility && { visibility: filters.visibility }),
        ...(filters.isActive !== undefined && { isActive: filters.isActive }),
        ...(filters.createdBy && { uploadedBy: filters.createdBy }),
      },
      include: {
        organization: {
          select: { id: true, name: true },
        },
        group: {
          select: { id: true, name: true },
        },
        uploader: {
          select: { id: true, name: true, email: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    })

    return { success: true, data: media }
  } catch (error) {
    console.error('Error listing media:', error)
    return { success: false, error: 'Failed to list media' }
  }
}

export async function updateMedia(mediaId: string, data: UpdateMediaData) {
  try {
    const media = await prisma.media.update({
      where: { id: mediaId },
      data: {
        ...(data.title && { title: data.title }),
        ...(data.description !== undefined && { description: data.description }),
        ...(data.visibility && { visibility: data.visibility }),
        ...(data.isActive !== undefined && { isActive: data.isActive }),
      },
      include: {
        organization: {
          select: { id: true, name: true },
        },
        group: {
          select: { id: true, name: true },
        },
        uploader: {
          select: { id: true, name: true, email: true },
        },
      },
    })

    return { success: true, data: media }
  } catch (error) {
    console.error('Error updating media:', error)
    return { success: false, error: 'Failed to update media' }
  }
}

export async function deleteMedia(mediaId: string) {
  try {
    await prisma.media.delete({
      where: { id: mediaId },
    })

    return { success: true, data: { message: 'Media deleted successfully' } }
  } catch (error) {
    console.error('Error deleting media:', error)
    return { success: false, error: 'Failed to delete media' }
  }
}
