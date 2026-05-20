Build, commit, and push to deploy the capture UI to production via Railway.

Steps:
1. Run `npm run build` to rebuild the Vite frontend into dist/
2. Stage all changes (including dist/ rebuild)
3. Create a commit with a concise message describing the changes
4. Push to origin/main — Railway auto-deploys from this branch
5. Report the commit hash and confirm the push succeeded
