import { createServer, type RequestListener, type Server } from 'node:http'

export type InvitationHttpServer = Server

/**
 * Supertest constructs IPv4 URLs but its implicit listener binds IPv6-any. On this host an
 * IPv4-specific listener can own the same port and receive those requests instead. Match the
 * URL's address family explicitly, and retain one owned listener for the whole test file.
 */
export function startInvitationHttpServer(app: RequestListener): Promise<Server> {
  const server = createServer(app)
  return new Promise((resolve, reject) => {
    server.once('error', reject)
    server.listen(0, '127.0.0.1', () => {
      server.off('error', reject)
      resolve(server)
    })
  })
}

export async function stopInvitationHttpServer(server: Server | undefined): Promise<void> {
  if (!server?.listening) return
  await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()))
}
