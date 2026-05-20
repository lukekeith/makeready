import swaggerJsdoc from 'swagger-jsdoc'
import { Express } from 'express'
import { definition } from './openapi-definition.js'

const options: swaggerJsdoc.Options = {
  definition,
  // Include both src (dev with tsx) and dist (production compiled JS)
  apis: [
    './src/routes/*.ts',
    './src/routes/*.js',
    './dist/routes/*.js',
  ],
}

const swaggerSpec = swaggerJsdoc(options)

export function setupSwagger(app: Express) {
  // Serve OpenAPI spec as JSON
  app.get('/docs/openapi.json', (_req, res) => {
    res.setHeader('Content-Type', 'application/json')
    res.send(swaggerSpec)
  })

  // Serve Redoc documentation with custom HTML for favicon
  app.get('/docs', (_req, res) => {
    const redocOptions = {
      theme: {
        colors: {
          primary: {
            main: '#6366f1', // Indigo
          },
        },
        typography: {
          fontSize: '15px',
          fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
          headings: {
            fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
            fontWeight: '600',
          },
          code: {
            fontSize: '13px',
            fontFamily: '"JetBrains Mono", "Fira Code", Menlo, Monaco, monospace',
          },
        },
        sidebar: {
          width: '280px',
          backgroundColor: '#fafafa',
        },
        rightPanel: {
          backgroundColor: '#1e293b', // Slate-800 for code panel
        },
      },
      expandResponses: '200,201',
      hideDownloadButton: false,
      hideHostname: false,
      pathInMiddlePanel: true,
      sortPropsAlphabetically: true,
      jsonSampleExpandLevel: 2,
    }

    const html = `
<!DOCTYPE html>
<html>
  <head>
    <title>MakeReady API Documentation</title>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="icon" type="image/svg+xml" href="/logo-mark.svg" />
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
      body { margin: 0; padding: 0; }
    </style>
  </head>
  <body>
    <redoc spec-url='/docs/openapi.json' options='${JSON.stringify(redocOptions)}'></redoc>
    <script src="https://cdn.redoc.ly/redoc/latest/bundles/redoc.standalone.js"></script>
  </body>
</html>
    `
    res.setHeader('Content-Type', 'text/html')
    res.send(html)
  })
}

export { swaggerSpec }
