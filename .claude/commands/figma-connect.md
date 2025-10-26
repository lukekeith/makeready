# Connect Figma MCP Server

Run the Claude CLI command to add the Figma MCP server using SSE transport:

```bash
claude mcp add --transport sse figma-dev-mode-mcp-server http://127.0.0.1:3845/sse
```

This will enable Claude Code to access Figma tools like:

- `get_design_context` - Get current selection and context
- `get_file_nodes` - Get specific nodes from Figma files
- `export_images` - Export assets from Figma

After running this command, you may need to reload the window for the tools to become available.
