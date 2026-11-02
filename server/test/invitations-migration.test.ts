import { readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { withInvitationMigrationDb } from './helpers/invitations-migration-db.js'

const migrations = fileURLToPath(new URL('../atlas/migrations/', import.meta.url))
function migrationSql() {
  const files = readdirSync(migrations).filter(name => name.endsWith('_invitations.sql'))
  expect(files).toHaveLength(1)
  return readFileSync(migrations + files[0], 'utf8')
}
const id = (n: number) => `a2200000-0000-4000-8000-${String(n).padStart(12, '0')}`
async function seed(client: import('pg').Client, collision = false) {
  await client.query(`INSERT INTO users (id,email,name,"createdAt","updatedAt") VALUES ($1,'migration-owner@example.invalid','Owner','2025-01-01','2025-01-01'),($2,'migration-other@example.invalid','Other','2025-01-01','2025-01-01')`, [id(1), id(2)])
  await client.query(`INSERT INTO organizations (id,name,"ownerId","createdAt","updatedAt") VALUES ($1,'Migration org',$2,'2025-01-01','2025-01-01')`, [id(3),id(1)])
  await client.query(`INSERT INTO groups (id,name,"creatorId","organizationId","createdAt","updatedAt") VALUES ($1,'Migration group',$2,$3,'2025-01-01','2025-01-01')`, [id(4),id(1),id(3)])
  await client.query(`INSERT INTO members (id,"phoneNumber","createdAt","updatedAt") VALUES ($1,'+12025550400','2025-01-01','2025-01-01')`, [id(5)])
  await client.query(`INSERT INTO invites (id,token,"groupId","inviterId","recipientPhone",status,"createdAt","acceptedAt","expiresAt") VALUES ($1,'MIG_ACCEPTED',$2,$3,'+12025550400','accepted','2025-01-02','2025-02-01','2025-02-02'),($4,'MIG_GENERIC',NULL,$5,NULL,'pending','2025-01-03',NULL,NULL),($6,'MIG_EXPIRED',$2,$3,NULL,'pending','2025-01-04',NULL,'2025-01-05')`, [id(10),id(4),id(1),id(11),id(2),id(12)])
  await client.query(`INSERT INTO group_join_requests (id,"groupId","memberId",status,message,"reviewedById","reviewedAt","createdAt","updatedAt") VALUES ($1,$2,$3,'approved','Keep message',$4,'2025-02-03','2025-01-06','2025-03-07')`, [collision ? id(10) : id(13),id(4),id(5),id(1)])
  await client.query(`INSERT INTO activity_logs (id,category,"activityType",status,route,method,"inviteId",message,"createdAt") VALUES ($1,'JOIN','INVITE_ACCEPTED','SUCCESS','/join','GET',$2,'keep reference','2025-01-01'),($3,'JOIN','INVITE_ACCEPTED','SUCCESS','/join','GET','orphan-history','keep orphan','2025-01-01')`, [id(20),id(10),id(21)])
}

describe('invitation table merge migration', () => {
  it('preserves source identity, timestamps and log references and backfills only dated history', async () => {
    const sql = migrationSql()
    await withInvitationMigrationDb(async url => {
      const { Client } = await import('pg'); const client = new Client({ connectionString: url }); await client.connect()
      try {
        await seed(client)
        const oldInvites = (await client.query('SELECT * FROM invites ORDER BY id')).rows
        const oldRequest = (await client.query('SELECT * FROM group_join_requests')).rows[0]
        const oldLogs = (await client.query('SELECT "inviteId" FROM activity_logs ORDER BY id')).rows
        await client.query('BEGIN'); await client.query(sql); await client.query('COMMIT')
        const rows = (await client.query('SELECT * FROM invitations ORDER BY id')).rows
        expect(rows.map(r => r.id)).toEqual([id(10),id(11),id(12),id(13)])
        for (const old of oldInvites) {
          const actual = rows.find(r => r.id === old.id)
          for (const key of Object.keys(old)) expect(actual[key], key).toEqual(old[key])
          expect(actual.updatedAt).toEqual(old.createdAt)
          expect(actual.initiatedBy).toBe('leader')
        }
        expect(rows[1].organizationId).toBeNull()
        expect(rows[3]).toMatchObject({ id: oldRequest.id, status: 'accepted', updatedAt: oldRequest.updatedAt, createdAt: oldRequest.createdAt, respondedAt: oldRequest.reviewedAt, respondedById: oldRequest.reviewedById, recipientPhone: '+12025550400', organizationId: id(3), message: 'Keep message' })
        expect((await client.query('SELECT "inviteId" FROM activity_logs ORDER BY id')).rows).toEqual(oldLogs)
        expect((await client.query("SELECT to_regclass('invites') AS invites, to_regclass('group_join_requests') AS requests")).rows).toEqual([{invites:null,requests:null}])
        const events = (await client.query(`SELECT "invitationId", type, at AT TIME ZONE 'UTC' AS at FROM invite_events ORDER BY "invitationId", at`)).rows
        expect(events.map(e => [e.invitationId,e.type,e.at.toISOString()])).toEqual([
          [id(10),'sent','2025-01-02T00:00:00.000Z'],[id(10),'accepted','2025-02-01T00:00:00.000Z'],
          [id(11),'sent','2025-01-03T00:00:00.000Z'],[id(12),'sent','2025-01-04T00:00:00.000Z'],[id(12),'expired','2025-01-05T00:00:00.000Z'],
          [id(13),'requested','2025-01-06T00:00:00.000Z'],[id(13),'approved','2025-02-03T00:00:00.000Z'],
        ])
      } finally { await client.end() }
    })
  },120000)
  it('uses group, historical, then unambiguous org associations and preserves missing review dates', async () => {
    const sql = migrationSql()
    await withInvitationMigrationDb(async url => {
      const { Client } = await import('pg'); const client = new Client({ connectionString: url }); await client.connect()
      try {
        await seed(client)
        await client.query(`INSERT INTO organizations (id,name,"ownerId","createdAt","updatedAt") VALUES ($1,'Second org',$2,now(),now())`, [id(30),id(2)])
        await client.query(`INSERT INTO roles (id,name,"organizationId","createdAt","updatedAt") VALUES ($1,'Migration role',$2,now(),now())`, [id(31),id(30)])
        await client.query(`INSERT INTO user_roles (id,"userId","roleId","organizationId") VALUES ($1,$2,$3,$4)`, [id(32),id(1),id(31),id(30)])
        // Owner 1 now has two orgs; the explicit historical association wins for generic rows.
        await client.query(`UPDATE users SET "organizationId"=$1 WHERE id=$2`, [id(30),id(1)])
        await client.query(`INSERT INTO invites (id,token,"inviterId",status,"createdAt") VALUES ($1,'HISTORICAL',$2,'pending',now())`, [id(33),id(1)])
        // A third user has multiple role assignments in just one org: count distinct orgs.
        await client.query(`INSERT INTO users (id,email,name,"createdAt","updatedAt","organizationId") VALUES ($1,'role-only@example.invalid','Role user',now(),now(),'obsolete-not-a-uuid'),($2,'ambiguous@example.invalid','Ambiguous user',now(),now(),NULL)`, [id(40),id(41)])
        await client.query(`INSERT INTO roles (id,name,"organizationId","createdAt","updatedAt") VALUES ($1,'Second role',$2,now(),now()),($3,'First org role',$4,now(),now())`, [id(42),id(30),id(43),id(3)])
        await client.query(`INSERT INTO user_roles (id,"userId","roleId","organizationId") VALUES ($1,$2,$3,$4),($5,$2,$6,$4),($7,$8,$3,$4),($9,$8,$10,$11)`, [id(44),id(40),id(31),id(30),id(45),id(42),id(46),id(41),id(47),id(43),id(3)])
        await client.query(`INSERT INTO invites (id,token,"inviterId",status,"createdAt") VALUES ($1,'SOLE_ROLE',$2,'pending',now()),($3,'AMBIGUOUS',$4,'pending',now())`, [id(48),id(40),id(49),id(41)])
        await client.query(`UPDATE group_join_requests SET status='rejected',"reviewedAt"=NULL,"reviewedById"=NULL`)
        await client.query('BEGIN'); await client.query(sql); await client.query('COMMIT')
        const orgs = (await client.query(`SELECT id,"organizationId" FROM invitations`)).rows
        const organizationFor = (n: number) => orgs.find(r => r.id === id(n)).organizationId
        expect(organizationFor(10)).toBe(id(3)) // group takes precedence over historical org
        expect(organizationFor(11)).toBe(id(30)) // sole owned org
        expect(organizationFor(33)).toBe(id(30)) // explicit historical org despite multiple associations
        expect(organizationFor(48)).toBe(id(30)) // invalid historical string; one distinct role org
        expect(organizationFor(49)).toBeNull() // ambiguity never chooses an arbitrary org
        expect((await client.query(`SELECT status,"respondedAt","respondedById" FROM invitations WHERE id=$1`, [id(13)])).rows[0]).toEqual({ status:'rejected',respondedAt:null,respondedById:null })
        expect((await client.query(`SELECT type FROM invite_events WHERE "invitationId"=$1`, [id(13)])).rows).toEqual([{ type:'requested' }])
      } finally { await client.end() }
    })
  },120000)
  it('aborts a cross-source ID collision without losing either old table', async () => {
    const sql = migrationSql()
    await withInvitationMigrationDb(async url => {
      const { Client } = await import('pg'); const client = new Client({ connectionString: url }); await client.connect()
      try {
        await seed(client,true)
        await client.query('BEGIN')
        await expect(client.query(sql)).rejects.toThrow(/collision/i)
        await client.query('ROLLBACK')
        expect((await client.query('SELECT count(*)::int AS n FROM invites')).rows[0].n).toBe(3)
        expect((await client.query('SELECT count(*)::int AS n FROM group_join_requests')).rows[0].n).toBe(1)
        expect((await client.query("SELECT to_regclass('invitations') AS merged")).rows[0].merged).toBeNull()
      } finally { await client.end() }
    })
  },120000)
})
