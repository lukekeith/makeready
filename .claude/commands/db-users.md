# Show Database Users

Query the PostgreSQL database to show all users in the `users` table.

Use the `psql` command to connect to the makeready database and display all users with their information.

Run this command:

```bash
psql makeready -c "SELECT id, email, name, \"googleId\", \"createdAt\", \"updatedAt\" FROM users ORDER BY \"createdAt\" DESC;"
```

Format the output in a readable table showing:
- User ID
- Email
- Name
- Google ID
- Created At
- Updated At

If there are no users, inform the user that the database is empty.
